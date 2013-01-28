//
//  AudioGlue.m
//  Nu
//
//  Created by arthur on 3/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioToolbox.h>

#include <fftw3.h>

@interface AudioGlue : NSObject
@end

@implementation AudioGlue

#define AUDIO_BUFFERS 3

typedef struct AQCallbackStruct {
AudioQueueRef queue;
UInt32 frameCount;
AudioQueueBufferRef mBuffers[AUDIO_BUFFERS];
AudioStreamBasicDescription mDataFormat;
} AQCallbackStruct;

AQCallbackStruct in;

int audio_record_is_initialized = 0;
int audio_record_do_not_initialize = 0;

NSMutableData *audioRecordData = nil;

static void audio_record_queue_callback(void *userdata,
                                 AudioQueueRef inQ,
                                 AudioQueueBufferRef inQB,
                                 const AudioTimeStamp *inStartTime,
                                 UInt32 inNumPackets,
                                 const AudioStreamPacketDescription *inPacketDescs)
{
    [audioRecordData appendBytes:inQB->mAudioData length:inQB->mAudioDataByteSize];
    AudioQueueEnqueueBuffer(inQ, inQB, 0, NULL);
}


void audio_record_close()
{
    if(audio_record_is_initialized) {
        AudioQueueDispose(in.queue, true);
        audio_record_is_initialized = 0;
        NSLog(@"stopped audio");
    }
}


void audio_record_open()
{
    if (audio_record_do_not_initialize)
        return;
    
    if (audio_record_is_initialized)
        return;
    
    memset (&in.mDataFormat, 0, sizeof (in.mDataFormat));
    in.mDataFormat.mSampleRate = 44100.0;
    in.mDataFormat.mChannelsPerFrame = 1;
    in.mDataFormat.mFormatID = kAudioFormatLinearPCM;
    in.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger|kLinearPCMFormatFlagIsPacked;
    in.mDataFormat.mBytesPerPacket = 2;
    in.mDataFormat.mFramesPerPacket = 1;
    in.mDataFormat.mBytesPerFrame = 2;
    in.mDataFormat.mBitsPerChannel = 16;
    in.frameCount = 735; // 44100.0 / 60.0;
    OSStatus err;
    err = AudioQueueNewInput(&in.mDataFormat,
                             audio_record_queue_callback,
                             NULL,
                             CFRunLoopGetMain(),
                             kCFRunLoopDefaultMode,
                             0,
                             &in.queue);
    
    unsigned long bufsize;
    bufsize = in.frameCount * in.mDataFormat.mBytesPerFrame;
    
    for (int i=0; i<AUDIO_BUFFERS; i++) {
        err = AudioQueueAllocateBuffer(in.queue, bufsize, &in.mBuffers[i]);
        AudioQueueEnqueueBuffer(in.queue, in.mBuffers[i], 0, NULL);
    }
    
    audio_record_is_initialized = 1;
    err = AudioQueueStart(in.queue, NULL);
    NSLog(@"started audio %ld", err);
}

+ (void)startRecord
{
    [audioRecordData release];
    audioRecordData = [[NSMutableData alloc] init];
    audio_record_open();
}

+ (void)stopRecord
{
    audio_record_close();
}

+ (NSMutableData *)recordData
{
    return audioRecordData;
}

+ (NSMutableData *)dft
{
    double *in;
    fftw_complex *out;
    fftw_plan p;
    
    int nsamples = audioRecordData.length / 2;
    in = (double *) fftw_malloc(sizeof(double) * nsamples);
    int16_t *bytes = (int16_t *) audioRecordData.mutableBytes;
    for(int i=0; i<nsamples; i++) {
        in[i] = (double)bytes[i] / 32768.0;
    }
    out = (fftw_complex *) fftw_malloc(sizeof(fftw_complex) * (nsamples/2 + 1));
    p = fftw_plan_dft_r2c_1d(nsamples, in, out, FFTW_ESTIMATE);
    fftw_execute(p);
    for(int i=1; i<=nsamples/2; i++) {
        in[i-1] = sqrt(out[i][0]*out[i][0] + out[i][1]*out[i][1]);
        /* (20 * log10(magnitude)) */
        in[i-1] *= in[i-1];
    }
    NSMutableData *data = [[[NSMutableData alloc] init] autorelease];
    [data appendBytes:in length:sizeof(double)*(nsamples/2)];
    fftw_destroy_plan(p);
    fftw_free(in);
    fftw_free(out);
    return data;
}

@end

@interface AudioGraphView : UIView
{
    NSData *_data;
}
@end

@implementation AudioGraphView

- (NSData *)data { return _data; }
- (void)setData:(NSData *)data
{
    [_data release];
    _data = [data retain];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextFillRect(context, self.bounds);
    if (!_data)
        return;
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    [[UIColor whiteColor] set];
    int16_t *bytes = (int16_t *)_data.bytes;
    CGFloat centery = self.frame.size.height / 2.0;
    CGContextSetLineWidth(context, 1.0);
    CGContextSetLineCap(context, kCGLineCapSquare);
    int nsamples = _data.length/2;
    for(int i=0; i<nsamples; i++) {
        CGFloat x = ((double)i / (double)nsamples) * self.frame.size.width;
        CGFloat y = ((double)bytes[i] / 32768.0) * centery + centery;
        CGContextMoveToPoint(context, x, y);
        CGContextAddLineToPoint(context, x, centery);
        CGContextStrokePath(context);
    }
}

@end

@interface GraphView : UIView
{
    NSData *_data;
}
@end

@implementation GraphView

- (NSData *)data { return _data; }
- (void)setData:(NSData *)data
{
    [_data release];
    _data = [data retain];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextFillRect(context, self.bounds);
    if (!_data)
        return;
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    [[UIColor whiteColor] set];
    double *bytes = (double *)_data.bytes;
    CGFloat minval=0.0, maxval=0.0;
    int nsamples = _data.length/sizeof(double);
    for(int i=0; i<nsamples; i++) {
        if (bytes[i] < minval)
            minval = bytes[i];
        if (bytes[i] > maxval)
            maxval = bytes[i];
    }
    NSLog(@"minval %f maxval %f", minval, maxval);
    CGContextSetLineWidth(context, 1.0);
    CGContextSetLineCap(context, kCGLineCapSquare);
    for(int i=0; i<nsamples; i++) {
        CGFloat x = ((double)i / (double)nsamples) * self.frame.size.width;
        CGFloat y = (bytes[i]-minval)/(maxval-minval) * self.frame.size.height;
        CGContextMoveToPoint(context, x, self.frame.size.height);
        CGContextAddLineToPoint(context, x, self.frame.size.height-y);
        CGContextStrokePath(context);
    }
}

@end