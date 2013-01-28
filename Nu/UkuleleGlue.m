//
//  UkuleleGlue.m
//  Nu
//
//  Created by arthur on 9/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioToolbox.h>

static NSMutableArray *playbackArray = nil;

NSString *getPathInBundle(NSString *name)
{
    return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:name];
}

@interface Playback : NSObject
{
    NSData *data;
    float_t *bytes;
    NSUInteger delay;
    NSUInteger length;
    NSUInteger position;
    float releaseCurve;
    float amplitude;
}
- (id)initWithSample:(NSData *)sample delay:(NSUInteger)a;
- (void)getNextFrame:(void *)dst size:(NSUInteger)size;
- (void)setReleaseCurve:(float)val;
- (void)setAmplitude:(float)val;
- (void)setPosition:(NSUInteger)val;
@end

@implementation Playback

- (void)dealloc
{
    [data release];
    data = nil;
    [super dealloc];
}

- (id)initWithSample:(NSData *)sample delay:(NSUInteger)a
{
    self = [super init];
    if (self) {
        data = [sample retain];
        bytes = data.bytes;
        length = data.length / 4;
        delay = a;
        position = 0;
        releaseCurve = 1.0;
        amplitude = 1.0;
    }
    return self;
}

- (BOOL)done
{
    return (position >= length) ? YES : NO;
}

- (void)getNextFrame:(float *)dst size:(NSUInteger)size
{
    if (delay >= size) {
        delay -= size;
        memset(dst, 0, size*sizeof(float));
        return;
    }
    NSUInteger index = 0;
    if (delay > 0) {
        index = delay;
        memset(dst, 0, delay*sizeof(float));
        delay = 0;
    }
    for(int i=index; i<size; i++) {
        if (position < length) {
            dst[i] = bytes[position++] * amplitude * releaseCurve;
        } else {
            dst[i] = 0;
        }
        if (releaseCurve < 1.0) {
            releaseCurve -= 0.0001;
            if (releaseCurve < 0.0)
                releaseCurve = 0.0;
        }
    }
}

- (void)setReleaseCurve:(float)val
{
    releaseCurve = val;
}

- (void)setAmplitude:(float)val
{
    amplitude = val;
}

- (void)setPosition:(NSUInteger)val
{
    position = val;
}

@end


@interface SampleStore : NSObject
{
    NSMutableDictionary *sampleDict;
}
+ (SampleStore *)defaultStore;
- (void)loadSample:(NSString *)name;
@end

static SampleStore *defaultStore = nil;

@implementation SampleStore

+ (SampleStore *)defaultStore
{
    if (!defaultStore) {
        defaultStore = [[super allocWithZone:NULL] init];
    }
    return defaultStore;
}

+ (id)allocWithZone:(NSZone *)zone
{
    return [self defaultStore];
}

- (id)init
{
    if (defaultStore) {
        return defaultStore;
    }
    self = [super init];
    if (self) {
        //        app = (AppDelegate *) [[UIApplication sharedApplication] delegate];
        sampleDict = [[NSMutableDictionary alloc] init];
        for(int i=0; i<4; i++) {
            for(int j=0; j<=14; j++) {
                [self loadSample:[NSString stringWithFormat:@"%d%.2d", i, j]];
            }
        }
        for(int i=0; i<4; i++) {
            for(int j=1; j<=14; j++) {
                [self loadSample:[NSString stringWithFormat:@"mute%d%.2d", i, j]];
            }
        }
        [self loadSample:@"muteup"];
        [self loadSample:@"mutedown"];
        [self loadSample:@"thump"];
    }
    return self;
}

- (id)retain
{
    return self;
}

- (oneway void)release
{
}

- (NSUInteger)retainCount
{
    return NSUIntegerMax;
}

- (void)loadSample:(NSString *)name
{
    NSString *file = [NSString stringWithFormat:@"kamaka%@.raw", name];
    NSData *data = [NSData dataWithContentsOfFile:getPathInBundle(file)];
    if (!data) {
        NSLog(@"unable to load file '%@'", file);
    }
    [sampleDict setValue:data forKey:name];
}

- (void)playString:(int)string fret:(int)fret
{
    void (^func)(NSData *, NSUInteger delay, NSUInteger offset) = ^(NSData *data, NSUInteger delay, NSUInteger offset) {
        if (data) {
            Playback *elt = [[[Playback alloc] initWithSample:data delay:delay] autorelease];
            [elt setAmplitude:1.0];
            [elt setPosition:0];
            @synchronized (playbackArray) {
                [playbackArray addObject:elt];
            }
        } else {
            NSLog(@"no data");
        }
    };
    NSString *key = nil;
    if (string >= 0) {
        if (fret >= 0) {
            key = [NSString stringWithFormat:@"%d%.2d", string, fret];
        }
    } else if (string == -1) {
        key = @"mute101";
    } else if (string == -2) {
        key = @"thump";
    }
    func([sampleDict valueForKey:key], 0, 0);
}

@end




@interface ChordView : UIView
{
    NSString *_title;
    int titleAtTop;
    int _string[4];
    int numberOfFrets;
    int fretOffset;
}
@end

@implementation ChordView

- (void)dealloc
{
    [_title release];
    _title = nil;
    [super dealloc];
}

- (id)initWithFrame:(CGRect)r
{
    self = [super initWithFrame:r];
    if (self) {
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        numberOfFrets = 4;
        _string[0] = -1;
        _string[1] = -1;
        _string[2] = -1;
        _string[3] = -1;
    }
    return self;
}

- (void)setTitle:(NSString *)str
{
    [_title release];
    _title = [str retain];
    [self setNeedsDisplay];
}

- (void)setString:(int)index fret:(int)fret
{
    if ((index >= 0) && (index < 4)) {
        _string[index] = fret;
        [self setNeedsDisplay];
    }
}

- (int)string:(int)index
{
    return _string[index];
}

- (NSString *)title
{
    return _title;
}

- (void)setFretOffset:(int)fret
{
    fretOffset = fret;
    [self setNeedsDisplay];
}

- (void)setNumberOfFrets:(int)n
{
    numberOfFrets = n;
    [self setNeedsDisplay];
}

- (void)setTitleAtTop:(int)val
{
    titleAtTop = val;
    [self setNeedsDisplay];
}

- (CGFloat)cellw { return self.frame.size.width / 4.0; }
- (CGFloat)cellh { return self.frame.size.height / (2.0 + numberOfFrets); }
- (CGFloat)headerh { return (titleAtTop) ? [self cellh] : 0.0; }

void draw_text(CGContextRef context, NSString *str, CGRect r, UIFont *font)
{
    [[UIColor blackColor] set];
    [str drawInRect:CGRectMake(r.origin.x+2.0, r.origin.y+2.0, r.size.width, r.size.height) withFont:font];
    [[UIColor whiteColor] set];
    [str drawInRect:r withFont:font];
}

void draw_line(CGContextRef context, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2)
{
    [[UIColor blackColor] set];
    CGContextMoveToPoint(context, x1+1.0, y1+1.0);
    CGContextAddLineToPoint(context, x2+1.0, y2+1.0);
    CGContextStrokePath(context);
    [[UIColor whiteColor] set];
    CGContextMoveToPoint(context, x1, y1);
    CGContextAddLineToPoint(context, x2, y2);
    CGContextStrokePath(context);
}

void fill_ellipse(CGContextRef context, CGRect r)
{
    [[UIColor blackColor] set];
    CGContextFillEllipseInRect(context, CGRectMake(r.origin.x+2.0, r.origin.y+2.0, r.size.width, r.size.height));
    [[UIColor whiteColor] set];
    CGContextFillEllipseInRect(context, r);
}

void draw_ellipse(CGContextRef context, CGRect r)
{
    [[UIColor blackColor] set];
    CGContextStrokeEllipseInRect(context, CGRectMake(r.origin.x+1.0, r.origin.y+1.0, r.size.width, r.size.height));
    [[UIColor whiteColor] set];
    CGContextStrokeEllipseInRect(context, r);
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    [[UIColor clearColor] set];
    CGContextFillRect(context, self.bounds);
    CGContextSetLineWidth(context, 1.0);
    CGContextSetLineCap(context, kCGLineCapSquare);
    CGFloat x = 0.0;
    CGFloat w = [self cellw];
    CGFloat h = [self cellh];
    CGFloat xspace = w*0.20;
    CGFloat yspace = h*0.20;
    CGFloat txspace = w*0.40;
    CGFloat tyspace = h*0.40;
    for(int i=0; i<4; i++) {
        draw_line(context, x + w/2.0, h+[self headerh], x + w/2.0, self.frame.size.height-h+[self headerh]-1.0);
        if (_string[i] > 0) {
            fill_ellipse(context, CGRectMake(x+xspace, [self headerh]+h*_string[i]+yspace, w-xspace*2.0, h-yspace*2.0));
        } else if (_string[i] == 0) {
            draw_ellipse(context, CGRectMake(x+xspace, [self headerh]+yspace, w-xspace*2.0, h-yspace*2.0));
        }
        CGFloat lx = x+txspace;
        CGFloat uy = tyspace+tyspace;
        CGFloat rx = x+w-txspace;
        CGFloat ly = h;
        if (_string[i] < 0) {
            lx = x + xspace;
            uy = [self headerh]+yspace;
            rx = x+w-xspace;
            ly = [self headerh]+h-yspace;
        }
        if (titleAtTop || (_string[i] < 0)) {
            draw_line(context, lx, uy, rx, ly);
            draw_line(context, lx, ly, rx, uy);
        }
        x += w;
    }
    for(int i=titleAtTop; i<1+numberOfFrets+titleAtTop; i++) {
        draw_line(context, w/2.0, h*i+h-1.0, self.frame.size.width-w/2.0, h*i+h-1.0);
    }
    if (_title.length) {
        UIFont *font = [UIFont systemFontOfSize:h*0.8];
        CGSize s = [_title sizeWithFont:font];
        CGFloat y;
        if (titleAtTop) {
            y = h-s.height-5.0;
        } else {
            y = h*numberOfFrets+h;
        }
        draw_text(context, _title, CGRectMake((self.frame.size.width-s.width)/2.0, y, s.width, s.height), font);
    }
}

- (void)play
{
    int n = 0;
    for(int i=0; i<4; i++) {
        if (_string[i] >= 0) {
            [[SampleStore defaultStore] playString:i fret:_string[i]];
            n++;
        }
    }
    if (!titleAtTop) {
        if (n == 0) {
            if (_string[0] == -2) {
                [[SampleStore defaultStore] playString:-2 fret:-2];
            } else {
                [[SampleStore defaultStore] playString:-1 fret:-1];
            }
        }
    }
}

- (void)action { [self play]; }

- (void)handleTouchesStatic:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *t in touches) {
        if (t.phase == UITouchPhaseBegan) {
            [self action];
            return;
        }
    }
}

- (void)handleTouchesEditable:(NSSet *)touches withEvent:(UIEvent *)event
{
    int display = 0;
    int play = 0;
    for (UITouch *t in touches) {
        switch (t.phase) {
            case UITouchPhaseBegan:
            case UITouchPhaseMoved:
            {
                CGPoint p = [t locationInView:self];
                int x = p.x / [self cellw];
                int y = p.y / [self cellh];
                if ((x >= 0) && (x < 4)) {
                    if ((y >= 0) && (y < 14)) {
                        if (_string[x] != y-1) {
                            _string[x] = y-1;
                            display++;
                            play++;
                        } else if (t.phase == UITouchPhaseBegan) {
                            play++;
                        }
                    }
                }
            }
        }
    }
    if (play) {
        [self action];
    }
    if (display) {
        [self setTitle:nil];
        [self setNeedsDisplay];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (titleAtTop) {
        [self handleTouchesEditable:touches withEvent:event];
    } else {
        [self handleTouchesStatic:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (titleAtTop) {
        [self handleTouchesEditable:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
}

@end

@interface KeysView : UIView
{
    int lastAction;
}
@property (nonatomic, retain) NSArray *keys;
@end


@implementation KeysView
@synthesize keys = _keys;

- (id)initWithFrame:(CGRect)r
{
    self = [super initWithFrame:r];
    if (self) {
        self.keys = [NSArray arrayWithObjects:@"C", @"Db", @"D", @"Eb", @"E", @"F", @"F#", @"G", @"Ab", @"A", @"Bb", @"B", nil];
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (CGFloat)cellh { return self.frame.size.height / self.keys.count; }
- (CGFloat)starty { return 0.0; }

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIColor clearColor] set];
    CGContextFillRect(context, self.bounds);
    [[UIColor whiteColor] set];
    CGContextSetLineWidth(context, 1.0);
    CGContextSetLineCap(context, kCGLineCapSquare);
    CGFloat x = 0.0;
    CGFloat w = self.frame.size.width;
    CGFloat h = [self cellh];
    CGFloat xspace = w*0.20;
    CGFloat yspace = h*0.20;
    CGFloat y = [self starty];
    UIFont *font = [UIFont systemFontOfSize:h/2.0];
    for(NSString *key in self.keys) {
        CGSize s = [key sizeWithFont:font];
        draw_text(context, key, CGRectMake(w-s.width-5.0, y+(h-s.height)/2.0, s.width, s.height), font);
        y += h;
    }
}

- (void)action:(int)i
{
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *t in touches) {
        switch (t.phase) {
            case UITouchPhaseBegan:
            case UITouchPhaseMoved:
            {
                CGPoint p = [t locationInView:self];
                if (p.y >= [self starty]) {
                    int i = (p.y-[self starty]) / [self cellh];
                    if (i < self.keys.count) {
                        if (lastAction != i+1) {
                            lastAction = i+1;
                            [self action:i];
                            return;
                        }
                    }
                }
            }
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesBegan:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    lastAction = 0;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    lastAction = 0;
}

@end


#define AUDIO_BUFFERS 3

typedef struct AQCallbackStruct {
AudioQueueRef queue;
UInt32 frameCount;
AudioQueueBufferRef mBuffers[AUDIO_BUFFERS];
AudioStreamBasicDescription mDataFormat;
} AQCallbackStruct;

static AQCallbackStruct in;

static void audio_queue_callback(void *userdata,
                                          AudioQueueRef outQ,
                                          AudioQueueBufferRef outQB)
{
    @autoreleasepool {
        outQB->mAudioDataByteSize = in.mDataFormat.mBytesPerFrame * in.frameCount;
        float buf[735];
        float *dst;
        dst = outQB->mAudioData;
        if (sizeof(float) != 4) {
            NSLog(@"sizeof(float) != 4");
        }
        memset(dst, 0, sizeof(float)*in.frameCount);
        @synchronized (playbackArray) {
            for (Playback *elt in playbackArray) {
                if ([elt done])
                    continue;
                [elt getNextFrame:buf size:in.frameCount];
                for (int i=0; i<in.frameCount; i++) {
                    float tmp = dst[i] + buf[i];// * 0.5;
                    if (tmp > 1.0) {
                        tmp = 1.0;
                    } else if (tmp < -1.0) {
                        tmp = -1.0;
                    }
                    dst[i] = tmp;
                }
            }
            NSPredicate *pred = [NSPredicate predicateWithBlock:^(Playback *obj, NSDictionary *bindings) {
                if ([obj done])
                    return NO;
                else
                    return YES;
            }];
            [playbackArray filterUsingPredicate:pred];
        }
        AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
    }
}

static int audio_is_initialized = 0;
static int audio_do_not_initialize = 0;

static void audio_close()
{
    if (audio_is_initialized) {
        AudioQueueDispose(in.queue, true);
        audio_is_initialized = 0;
    }
}

static void audio_open()
{
    if (audio_do_not_initialize)
        return;
    
    if (audio_is_initialized)
        return;
    
    memset (&in.mDataFormat, 0, sizeof (in.mDataFormat));
    in.mDataFormat.mSampleRate = 44100;
    in.mDataFormat.mFormatID = kAudioFormatLinearPCM;
    in.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsFloat;
    in.mDataFormat.mBytesPerPacket = 4;
    in.mDataFormat.mFramesPerPacket = 1;
    in.mDataFormat.mBytesPerFrame = 4;
    in.mDataFormat.mChannelsPerFrame = 1;
    in.mDataFormat.mBitsPerChannel = 32;
    in.frameCount = 735; // 44100.0 / 60.0;
    UInt32 err;
    err = AudioQueueNewOutput(&in.mDataFormat,
                              audio_queue_callback,
                              NULL,
                              NULL,//CFRunLoopGetMain(),
                              NULL,//kCFRunLoopDefaultMode,
                              0,
                              &in.queue);
    
    unsigned long bufsize;
    bufsize = in.frameCount * in.mDataFormat.mBytesPerFrame;
    
    for (int i=0; i<AUDIO_BUFFERS; i++) {
        err = AudioQueueAllocateBuffer(in.queue, bufsize, &in.mBuffers[i]);
        in.mBuffers[i]->mAudioDataByteSize = bufsize;
        AudioQueueEnqueueBuffer(in.queue, in.mBuffers[i], 0, NULL);
    }
    
    if (!playbackArray) {
        playbackArray = [[NSMutableArray alloc] init];
    }
    
    audio_is_initialized = 1;
    err = AudioQueueStart(in.queue, NULL);
}

@interface UkuleleGlue : NSObject
@end

@implementation UkuleleGlue
+ (void)startAudio
{
    audio_open();
}
+ (void)stopAudio
{
    audio_close();
}
@end
