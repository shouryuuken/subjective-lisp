//
//  glue.cpp
//  Artsnes9x
//
//  Created by arthur on 25/01/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include <iostream>

#import "SnesView.h"

#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioToolbox.h>
#include <pthread.h>

#include "snes9x.h"
#include "memmap.h"
#include "debug.h"
#include "cpuexec.h"
#include "ppu.h"
#include "snapshot.h"
#include "apu.h"
#include "display.h"
#include "gfx.h"
#include "controls.h"
#include "movie.h"
#include "controls.h"

#include "resampler.h"

extern Resampler *S9xGetResampler();

#ifdef __cplusplus
extern "C" {
    void snes_reset();
    void snes_save();
    void snes_unload();
    int snes_load(char *romfile, int frameskip, id view);
    void snes_audio_close();
    void snes_audio_open();
}
#endif

UIView *snes_view = nil;
unsigned char *snes_videobuf;

int snes_screen_enabled = 0;
int snes_screen_width = 256;
int snes_screen_height = 224;

int snes_loaded = 0;
pthread_t snes_thread;
pthread_mutex_t snes_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t snes_cond = PTHREAD_COND_INITIALIZER;

uint8 snes_gfxbuf[512*478*2];
int s9x_deinit_update_w;
int s9x_deinit_update_h;

int snes_audio_is_initialized = 0;
int snes_audio_do_not_initialize = 0;

#define DEFAULT_AUDIO_BYTES_PER_CYCLE 2132
#define DEFAULT_AUDIO_FRAMES_PER_CYCLE 533.0
int snes_video_skip_frames = 0;
int snes_audio_bytes_per_cycle = DEFAULT_AUDIO_BYTES_PER_CYCLE;
float snes_audio_frames_per_cycle = DEFAULT_AUDIO_FRAMES_PER_CYCLE;

static const char *getPathWithExtensionCString(const char *path, const char *extension)
{
    static char buf[1024];
    NSString *str = [NSString stringWithCString:path encoding:NSASCIIStringEncoding];
    [[str stringByAppendingString:[NSString stringWithCString:extension encoding:NSASCIIStringEncoding]] getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}

static const char *getPathBaseNameCString(const char *path)
{
    static char buf[1024];
    NSString *str = [NSString stringWithCString:path encoding:NSASCIIStringEncoding];
    [[[str lastPathComponent] stringByDeletingPathExtension] getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}

static const char *getDocsPathCString()
{
    static char buf[1024];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    [[paths objectAtIndex:0] getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}

static const char *getPathInDocsCString(const char *path)
{
    static char buf[1024];
    NSString *str = [NSString stringWithCString:path encoding:NSASCIIStringEncoding];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    str = [[paths objectAtIndex:0] stringByAppendingPathComponent:str];
    [str getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}
    
void snes_reset()
{
    S9xReset();
}

void snes_save()
{
    if (snes_loaded) {
        S9xFreezeGame(S9xGetFilename(".frz", SNAPSHOT_DIR));
    }
}

void snes_unload()
{
    snes_view = nil;
    snes_audio_close();
    snes_loaded = 0; 
    if (snes_video_skip_frames) {
        pthread_mutex_lock(&snes_mutex);
        pthread_cond_signal(&snes_cond);
        pthread_mutex_unlock(&snes_mutex);
        if (pthread_join(snes_thread, NULL)) {
            NSLog(@"error while waiting for pthread");
        }
    }
    snes_loaded = 1;
    snes_save();
    snes_loaded = 0;
    Memory.SaveSRAM(S9xGetFilename(".srm", SRAM_DIR));
    S9xDeinitAPU();
    S9xGraphicsDeinit();
    Memory.Deinit();
}

void snes_execute_next_frame();
void snes_execute_next_frame()
{
    if (snes_loaded) {
        uint32 frame_count;
        for(int i=0; i<=snes_video_skip_frames; i++) {
            frame_count = IPPU.FrameCount;
            IPPU.RenderThisFrame = (i == snes_video_skip_frames) ? true : false;
            for(;;) {
                S9xSetJoypadButtons(0, [snes_view joypadButtons]);
                S9xMainLoop();
                if (IPPU.FrameCount != frame_count)
                    break;
            }
        }
        if ((s9x_deinit_update_w != 256) || (s9x_deinit_update_h != 224)) {
            fprintf(stderr, "S9xDeinitUpdate w %d h %d\n", s9x_deinit_update_w, s9x_deinit_update_h);
        }
        memcpy(snes_videobuf, GFX.Screen, snes_screen_width*snes_screen_height*2);
    }
}

void *snes_thread_main(void *ptr);
void *snes_thread_main(void *ptr)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    pthread_mutex_lock(&snes_mutex);
    while (snes_loaded) {
        snes_execute_next_frame();
        pthread_cond_wait(&snes_cond, &snes_mutex);
    }
    pthread_mutex_unlock(&snes_mutex);
    [pool drain];
    return NULL;
}

void set_frameskip(int frameskip);
void set_frameskip(int frameskip)
{
    snes_video_skip_frames = frameskip;
    snes_audio_bytes_per_cycle = DEFAULT_AUDIO_BYTES_PER_CYCLE * (frameskip+1);
    snes_audio_frames_per_cycle = DEFAULT_AUDIO_FRAMES_PER_CYCLE * (frameskip+1);
}

int snes_load(char *romfile, int frameskip, id view)
{
    snes_audio_close();
    
    memset(&Settings, 0, sizeof(Settings));
    Settings.MouseMaster = false;
    Settings.SuperScopeMaster = false;
    Settings.JustifierMaster = false;
    Settings.MultiPlayer5Master = false;
    Settings.FrameTimePAL = 16667;
    Settings.FrameTimeNTSC = 16667;
    Settings.SixteenBitSound = true;
    Settings.Stereo = true;
    Settings.SupportHiRes = false;
    Settings.Transparency = true;
    Settings.AutoDisplayMessages = true;
    Settings.InitialInfoStringTimeout = 120;
    Settings.HDMATimingHack = 100;
    Settings.BlockInvalidVRAMAccessMaster = true;
    Settings.AutoSaveDelay = 1;
    Settings.DontSaveOopsSnapshot = true;
    
	if (!Memory.Init()) {
		fprintf(stderr, "Unable to init memory\n");
        return 0;
    }
    
    GFX.Screen = (uint16 *) snes_gfxbuf;
    GFX.Pitch = 256*2;    
	if (!S9xGraphicsInit()) {
		fprintf(stderr, "Unable to init graphics\n");
        return 0;
    }
    
	if (!S9xInitAPU()) {
		fprintf(stderr, "Unable to init apu\n");
        return 0;
    }
    
	S9xInitSound(10000, 0);
    
    S9xUnmapAllControls();
    S9xSetController(0, CTL_JOYPAD, 0, 0, 0, 0);
	
    if (!Memory.LoadROM(romfile)) {
        fprintf(stderr, "Unable to open rom file '%s'\n", romfile);
        return 0;
	}

    Memory.LoadSRAM(S9xGetFilename(".srm", SRAM_DIR));
 
    if (!S9xUnfreezeGame(S9xGetFilename(".frz", SNAPSHOT_DIR))) {
        S9xReset();
    }
    
    if (snes_video_skip_frames != frameskip) {
        set_frameskip(frameskip);
    }
        
    NSLog(@"snes_video_skip_frames %d", snes_video_skip_frames);
    NSLog(@"snes_audio_bytes_per_cycle %d", snes_audio_bytes_per_cycle);
    NSLog(@"snes_audio_frames_per_cycle %f", snes_audio_frames_per_cycle);

    snes_view = view;
    snes_loaded = 1;
    
    if (snes_video_skip_frames) {
        pthread_create(&snes_thread, NULL, snes_thread_main, NULL);
        struct sched_param param;
        param.sched_priority = 46;//46; //63; //100;
        if(pthread_setschedparam(snes_thread, /*SCHED_RR*/ SCHED_OTHER, &param) != 0)    
            NSLog(@"Unable to set priority for pthread");
    }
    
    snes_audio_open();
    
	return 1;
}

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
    outQB->mAudioDataByteSize = in.mDataFormat.mBytesPerFrame * in.frameCount;
    if (snes_loaded) {
        static unsigned char last_audio_sample[4];
        static int extra_sample = 0;
        if (snes_video_skip_frames) {
            pthread_mutex_lock(&snes_mutex);
        } else {
            snes_execute_next_frame();
        }
        Resampler *resampler = S9xGetResampler();
        int nbytes = resampler->space_filled();
        resampler->pull((unsigned char *)outQB->mAudioData, (nbytes > snes_audio_bytes_per_cycle) ? snes_audio_bytes_per_cycle : nbytes);
        if (nbytes > snes_audio_bytes_per_cycle) {
            resampler->clear();
        }
        if (snes_video_skip_frames) {
            pthread_cond_signal(&snes_cond);
            pthread_mutex_unlock(&snes_mutex); 
        }
        [snes_view.layer setNeedsDisplay];
        if (nbytes < snes_audio_bytes_per_cycle) {
            fprintf(stderr, "resampler nbytes is %d, should be 2132 (or 2136)\n", nbytes);
            unsigned char *p = (unsigned char *)outQB->mAudioData;
            for(int i=0; i<snes_audio_bytes_per_cycle; i+=4) {
                memcpy(p, last_audio_sample, 4);
                p += 4;
            }
        } else if (nbytes == snes_audio_bytes_per_cycle) {
            memcpy(last_audio_sample, ((unsigned char *)outQB->mAudioData)+snes_audio_bytes_per_cycle-4, 4);
        } else if (nbytes > snes_audio_bytes_per_cycle) {
            memcpy(last_audio_sample, ((unsigned char *)outQB->mAudioData)+snes_audio_bytes_per_cycle-4, 4);
            extra_sample++;
            fprintf(stderr, "extra sample %d, nbytes %d, total emulated frames %u\n", extra_sample, nbytes, IPPU.TotalEmulatedFrames);
        }
    } else {
        memset(outQB->mAudioData, 0, outQB->mAudioDataByteSize);
    }
    AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
}


void snes_audio_close()
{
    if(snes_audio_is_initialized) {
        AudioQueueDispose(in.queue, true);
        snes_audio_is_initialized = 0;
    }
}

void snes_audio_open()
{
    if (snes_audio_do_not_initialize)
        return;
    
    if (snes_audio_is_initialized)
        return;
    
    memset (&in.mDataFormat, 0, sizeof (in.mDataFormat));
    in.mDataFormat.mSampleRate = 32000;
    in.mDataFormat.mFormatID = kAudioFormatLinearPCM;
    in.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked;
    in.mDataFormat.mBytesPerPacket = 4;
    in.mDataFormat.mFramesPerPacket = 1;
    in.mDataFormat.mBytesPerFrame = 4;
    in.mDataFormat.mChannelsPerFrame = 2;
    in.mDataFormat.mBitsPerChannel = 16;
    in.frameCount = snes_audio_frames_per_cycle;
    UInt32 err;
    err = AudioQueueNewOutput(&in.mDataFormat,
                              audio_queue_callback,
                              NULL,
                              CFRunLoopGetMain(),
                              kCFRunLoopDefaultMode,
                              0,
                              &in.queue);
    
    unsigned long bufsize;
    bufsize = in.frameCount * in.mDataFormat.mBytesPerFrame;
    
    for (int i=0; i<AUDIO_BUFFERS; i++) {
        err = AudioQueueAllocateBuffer(in.queue, bufsize, &in.mBuffers[i]);
        in.mBuffers[i]->mAudioDataByteSize = bufsize;
        AudioQueueEnqueueBuffer(in.queue, in.mBuffers[i], 0, NULL);
    }
    
    snes_audio_is_initialized = 1;
    err = AudioQueueStart(in.queue, NULL);
}

bool8 S9xInitUpdate ()
{
    return true;
}

bool8 S9xDeinitUpdate (int w, int h)
{
    s9x_deinit_update_w = w;
    s9x_deinit_update_h = h;
    return true;
}

bool8 S9xContinueUpdate (int width, int height)
{
    return true;
}

void S9xAutoSaveSRAM (void)
{
    fprintf(stderr, "S9xAutoSaveSRAM\n");
    Memory.SaveSRAM(S9xGetFilename(".srm", SRAM_DIR));
}

const char *S9xBasename (const char *path)
{
    fprintf(stderr, "S9xBasename path '%s'\n", path);
    return getPathBaseNameCString(path);
}

const char *S9xGetFilename (const char *extension, enum s9x_getdirtype dirtype)
{
    fprintf(stderr, "S9xGetFilename extension '%s' dirtype %d\n", extension, dirtype);
    return getPathWithExtensionCString(getPathInDocsCString(getPathBaseNameCString(Memory.ROMFilename)), extension);
}

const char *S9xGetFilenameInc (const char *extension, enum s9x_getdirtype dirtype)
{
    return (const char *) "S9xGetFilenameIncNotImplemented";
}

const char *S9xGetDirectory (enum s9x_getdirtype dirtype)
{
    fprintf(stderr, "S9xGetDirectory dirtype %d\n", dirtype);
    return getDocsPathCString();
}

bool8 S9xOpenSnapshotFile (const char *filepath, bool8 read_only, STREAM *file)
{
    if ((*file = OPEN_STREAM(filepath, read_only ? "rb" : "wb")))
        return true;
    return false;
}

void S9xCloseSnapshotFile (STREAM file)
{
    CLOSE_STREAM(file);
}

void S9xExit (void)
{
}

void S9xMessage (int type, int number, const char *message)
{
    fprintf (stderr, "%s\n", message);
}

bool8 S9xOpenSoundDevice()
{
	return true;
}

const char *S9xChooseFilename (bool8 read_only)
{
    return NULL;
}

const char *S9xChooseMovieFilename (bool8 read_only)
{
    return NULL;
}

void S9xToggleSoundChannel (int c)
{
}

void S9xSetPalette (void)
{
}

void S9xSyncSpeed (void)
{
}

bool S9xPollButton (uint32 id, bool *pressed)
{
    return false;
}

bool S9xPollAxis (uint32 id, int16 *value)
{
    return false;
}

bool S9xPollPointer (uint32 id, int16 *x, int16 *y)
{
    return false;
}

void S9xHandlePortCommand (s9xcommand_t cmd, int16 data1, int16 data2)
{
}

const char * S9xStringInput (const char *message)
{
    return NULL;
}

void _splitpath (const char *path, char *drive, char *dir, char *fname, char *ext)
{
    *drive = 0;
    
    const char      *slash = strrchr(path, SLASH_CHAR),
    *dot   = strrchr(path, '.');
    
    if (dot && slash && dot < slash)
        dot = NULL;
    
    if (!slash)
    {
        *dir = 0;
        
        strcpy(fname, path);
        
        if (dot)
        {
            fname[dot - path] = 0;
            strcpy(ext, dot + 1);
        }
        else
            *ext = 0;
    }
    else
    {
        strcpy(dir, path);
        dir[slash - path] = 0;
        
        strcpy(fname, slash + 1);
        
        if (dot)
        {
            fname[dot - slash - 1] = 0;
            strcpy(ext, dot + 1);
        }
        else
            *ext = 0;
    }
}

void _makepath (char *path, const char *, const char *dir, const char *fname, const char *ext)
{
    if (dir && *dir)
    {
        strcpy(path, dir);
        strcat(path, SLASH_STR);
    }
    else
        *path = 0;
    
    strcat(path, fname);
    
    if (ext && *ext)
    {
        strcat(path, ".");
        strcat(path, ext);
    }
}
