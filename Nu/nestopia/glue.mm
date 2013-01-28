//
//  glue.cpp
//  Artnestopia
//
//  Created by arthur on 20/01/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include <iostream>
#include <fstream>
#include <strstream>
#include <sstream>
#include <iomanip>
#include <string.h>
#include <cassert>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <vector>

#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioToolbox.h>

#include "core/NstBase.hpp"
#include "core/api/NstApi.hpp"
#include "core/api/NstApiEmulator.hpp"
#include "core/api/NstApiVideo.hpp"
#include "core/api/NstApiSound.hpp"
#include "core/api/NstApiInput.hpp"
#include "core/api/NstApiMachine.hpp"
#include "core/api/NstApiUser.hpp"
#include "core/api/NstApiNsf.hpp"
#include "core/api/NstApiMovie.hpp"
#include "core/api/NstApiFds.hpp"
#include "core/api/NstApiRewinder.hpp"
#include "core/api/NstApiCartridge.hpp"
#include "core/api/NstApiCheats.hpp"
#include "core/NstMachine.hpp"
#include "core/NstCrc32.hpp"
#include "core/NstChecksum.hpp"
#include "core/NstXml.hpp"

#import <UIKit/UIKit.h>
#import "NestopiaView.h"
#import "Helper.h"

void nes_audio_open(void);
void nes_audio_close(void);
void nst_reset(void);
int nst_load(const char *filename, int use_pad, int use_zapper, id view);
void nst_unload(void);
void nst_execute(void);
void set_zapper_buttons(unsigned int x, unsigned int y, unsigned int fire);
void nst_save_state(void);
void nst_load_state(void);

using namespace Nes::Api;

void NST_CALLBACK nst_fileio_callback(void *userData, User::File& file);

Nes::Core::Machine emulator;

void nes_video_init();
void nes_sound_init();

NesView *nes_view = nil;
unsigned char *nes_videobuf = nil;

int nes_screen_width=Video::Output::WIDTH, nes_screen_height=Video::Output::HEIGHT;
int nes_loaded = 0;
int nst_quit = 0;

Video::Output nstvideo;
Sound::Output nstsound;
Input::Controllers nstcontrollers;

#define AUDIO_BUFFERS 3

typedef struct AQCallbackStruct {
    AudioQueueRef queue;
    UInt32 frameCount;
    AudioQueueBufferRef mBuffers[AUDIO_BUFFERS];
    AudioStreamBasicDescription mDataFormat;
} AQCallbackStruct;

static AQCallbackStruct in;

int nes_audio_is_initialized = 0;
int nes_audio_do_not_initialize = 0;

static void nes_audio_queue_callback(void *userdata,
                                 AudioQueueRef outQ,
                                 AudioQueueBufferRef outQB)
{
    outQB->mAudioDataByteSize = in.mDataFormat.mBytesPerFrame * in.frameCount;
    if (nes_loaded) {
        static unsigned char pixels[Video::Output::WIDTH*Video::Output::HEIGHT*2];
        nstvideo.pixels = pixels;
        nstvideo.pitch = Video::Output::WIDTH*2;
        nstsound.samples[0] = outQB->mAudioData;
        nstsound.length[0] = 735;
        nstsound.samples[1] = NULL;
        nstsound.length[1] = 0;
        nstcontrollers.pad[0].buttons = nes_view.joypadButtons;
        emulator.Execute(&nstvideo, &nstsound, &nstcontrollers);
        memcpy(nes_videobuf, pixels, Video::Output::WIDTH*Video::Output::HEIGHT*2);
        [nes_view.layer setNeedsDisplay];
    } else {
        memset(outQB->mAudioData, 0, outQB->mAudioDataByteSize);
    }
    AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
}


void nes_audio_close()
{
    if(nes_audio_is_initialized) {
        AudioQueueDispose(in.queue, true);
        nes_audio_is_initialized = 0;
    }
}


void nes_audio_open()
{
    if (nes_audio_do_not_initialize)
        return;
    
    if (nes_audio_is_initialized)
        return;
    
    memset (&in.mDataFormat, 0, sizeof (in.mDataFormat));
    in.mDataFormat.mSampleRate = 44100.0;
    in.mDataFormat.mFormatID = kAudioFormatLinearPCM;
    in.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked;
    in.mDataFormat.mBytesPerPacket = 4;
    in.mDataFormat.mFramesPerPacket = 1;
    in.mDataFormat.mBytesPerFrame = 4;
    in.mDataFormat.mChannelsPerFrame = 2;
    in.mDataFormat.mBitsPerChannel = 16;
    in.frameCount = 735.0; // 44100.0 / 60.0;
    UInt32 err;
    err = AudioQueueNewOutput(&in.mDataFormat,
                              nes_audio_queue_callback,
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
    
    nes_audio_is_initialized = 1;
    err = AudioQueueStart(in.queue, NULL);
}

void nst_reset(void)
{
    Machine machine(emulator);
    machine.Reset(true);
}
    
void nst_unload(void)
{
    Machine machine(emulator);
    nes_audio_close();
    if (!nes_loaded)
        return;
    nst_save_state();
    nes_loaded = 0;
    std::cout << "Powering down the emulated machine\n";
    machine.Power(false);
    nes_view = nil;
    machine.Unload();
}

int nst_load(const char *filename, int use_pad, int use_zapper, id view)
{
    Machine machine( emulator );
    Nes::Result result;

    nst_unload();

    void *userData = (void *) 0xDEADC0DE;
    User::fileIoCallback.Set(nst_fileio_callback, userData);
    
    std::ifstream file(filename, std::ios::in|std::ios::binary);
    result = machine.Load( file, Machine::FAVORED_NES_NTSC );

    if (NES_FAILED(result))
    {
        switch (result)
        {
            case Nes::RESULT_ERR_INVALID_FILE:
                std::cout << "Invalid file\n";
                break;
                
            case Nes::RESULT_ERR_OUT_OF_MEMORY:
                std::cout << "Out of memory\n";
                break;
                
            case Nes::RESULT_ERR_CORRUPT_FILE:
                std::cout << "Corrupt or missing file\n";
                break;
                
            case Nes::RESULT_ERR_UNSUPPORTED_MAPPER:
                std::cout << "Unsupported mapper\n";
                break;
                
            case Nes::RESULT_ERR_MISSING_BIOS:
                std::cout << "Can't find disksys.rom for FDS game\n";
                break;
                
            default:
                std::cout << "Unknown error #" << result << "\n";
                break;
        }
                
        return 0;
    }

    nes_view = view;
    
    machine.Power( true );
    
    nes_video_init();
    nes_sound_init();
    
    Input(emulator).ConnectController( 0, (use_pad) ? Input::PAD1 : Input::UNCONNECTED);    
    Input(emulator).ConnectController( 1, (use_zapper) ? Input::ZAPPER : Input::UNCONNECTED);
    
    nst_load_state();
    
    nes_loaded = 1;
    
    nes_audio_open();
    
    return 1;
}

void nes_video_init()
{
    Video::RenderState renderState;
    Machine machine( emulator );
    
    machine.SetMode(Machine::NTSC);
    renderState.filter = Video::RenderState::FILTER_NONE;
    renderState.width = nes_screen_width;
    renderState.height = nes_screen_height;
    renderState.bits.count = 16;
    renderState.bits.mask.r = 0xf800;
    renderState.bits.mask.g = 0x07e0;
    renderState.bits.mask.b = 0x001f;
    Video video( emulator );
    
    video.EnableUnlimSprites(false);

    video.SetSharpness(Video::DEFAULT_SHARPNESS_COMP);
    video.SetColorResolution(Video::DEFAULT_COLOR_RESOLUTION_COMP);
    video.SetColorBleed(Video::DEFAULT_COLOR_BLEED_COMP);
    video.SetColorArtifacts(Video::DEFAULT_COLOR_ARTIFACTS_COMP);
    video.SetColorFringing(Video::DEFAULT_COLOR_FRINGING_COMP);
        
    if (NES_FAILED(video.SetRenderState( renderState )))
    {
        std::cout << "NEStopia core rejected render state\n";
        ::exit(0);
    }
}

void nes_sound_init()
{
    Sound sound(emulator);
    sound.SetSampleBits(16);
    sound.SetSampleRate(44100);
    sound.SetSpeaker(Sound::SPEAKER_STEREO);
}

void set_zapper_buttons(unsigned int x, unsigned int y, unsigned int fire)
{
    if (nes_loaded) {
        nstcontrollers.zapper.x = x;
        nstcontrollers.zapper.y = y;
        nstcontrollers.zapper.fire = fire;
    }
}

const char *get_filename(NSString *extension);
const char *get_filename(NSString *extension)
{
    return getCString(getPathInDocs([getDisplayNameForPath(nes_view.path) stringByAppendingPathExtension:extension]));
}

void nst_save_state()
{
    Nes::Api::Machine machine(emulator);
    std::ofstream stateFile(get_filename(@"sav"), std::ifstream::out|std::ifstream::binary);
    if (stateFile.is_open()) {
        machine.SaveState(stateFile);
        NSLog(@"saved state %s", get_filename(@"sav"));
    } else {
        NSLog(@"unable to save state %s", get_filename(@"sav"));
    }
}

void nst_load_state()
{
    Nes::Api::Machine machine(emulator);
    std::ifstream stateFile(get_filename(@"sav"), std::ifstream::in|std::ifstream::binary);
    if (stateFile.is_open()) {
        machine.LoadState(stateFile);
        NSLog(@"loaded state %s", get_filename(@"sav"));
    } else {
        NSLog(@"unable to load state %s", get_filename(@"sav"));
    }
}

void NST_CALLBACK nst_fileio_callback(void *userData, User::File& file)
{
    switch (file.GetAction())
    {
        case User::File::LOAD_BATTERY: // load in battery data from a file
        {
            int size;
            FILE *f;
            
            f = fopen(get_filename(@"bty"), "rb");
            if (!f)
            {
                NSLog(@"unable to load battery %s", get_filename(@"bty"));
                return;
            }
            fseek(f, 0, SEEK_END);
            size = ftell(f);
            fclose(f);
            
            std::ifstream batteryFile(get_filename(@"bty"), std::ifstream::in|std::ifstream::binary );
            
            if (batteryFile.is_open())
            {
                file.SetContent( batteryFile );
                NSLog(@"loaded battery %s", get_filename(@"bty"));
            } else {
                NSLog(@"unable to load battery %s", get_filename(@"bty"));
            }
            break;
        }
            
        case User::File::SAVE_BATTERY: // save battery data to a file
        {
            std::ofstream batteryFile(get_filename(@"bty"), std::ifstream::out|std::ifstream::binary );
            const void* savedata;
            unsigned long savedatasize;
            
            file.GetContent( savedata, savedatasize );
            
            if (batteryFile.is_open()) {
                NSLog(@"saved battery %s", get_filename(@"bty"));
                batteryFile.write( (const char*) savedata, savedatasize );
            } else {
                NSLog(@"unable to save battery %s", get_filename(@"bty"));
            }
            
            break;
        }
        default:
            NSLog(@"nst_fileio_callback: unhandled request type %d", file.GetAction());
    }
}
