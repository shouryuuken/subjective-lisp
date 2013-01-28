//
//  FFMpegGlue.m
//  Nu
//
//  Created by arthur on 30/06/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CALayer.h>
#import <QuartzCore/QuartzCore.h>
#import "Misc.h"

@interface FFMpegGlue : NSObject
@end

@implementation FFMpegGlue
@end

CGRect get_screen_rect(UIView *v, int screen_width, int screen_height)
{
    if (!v.superview)
        return CGRectMake(0.0, 0.0, screen_width, screen_height);
    
    CGRect r = v.superview.frame;
    int tmp_width = r.size.width;
    int tmp_height = ((((tmp_width * screen_height) / screen_width)+7)&~7);
    if(tmp_height > r.size.height)
    {
        tmp_height = r.size.height;
        tmp_width = ((((tmp_height * screen_width) / screen_height)+7)&~7);
    }   
    r.origin.x = ((int)r.size.width - tmp_width) / 2;             
    r.origin.y = ((int)r.size.height - tmp_height) / 2;
    r.size.width = tmp_width;
    r.size.height = tmp_height;    
    return r;
}

/* SDL audio buffer size, in samples. Should be small to have precise
 A/V sync as SDL does not have hardware buffer fullness info. */
#define SDL_AUDIO_BUFFER_SIZE 1024

#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioToolbox.h>

#define FFMPEG_AUDIO_BUFFERS 3

typedef struct AQCallbackStruct {
AudioQueueRef queue;
UInt32 frameCount;
AudioQueueBufferRef mBuffers[FFMPEG_AUDIO_BUFFERS];
AudioStreamBasicDescription mDataFormat;
} FFMpegAQCallbackStruct;

static FFMpegAQCallbackStruct in;

static void ffmpeg_audio_queue_callback(void *opaque,
                                        AudioQueueRef outQ,
                                        AudioQueueBufferRef outQB);

static int ffmpeg_audio_is_initialized = 0;
static int ffmpeg_audio_do_not_initialize = 0;

static void ffmpeg_audio_close()
{
    if (ffmpeg_audio_is_initialized) {
        AudioQueueDispose(in.queue, true);
        ffmpeg_audio_is_initialized = 0;
    }
}

static void ffmpeg_audio_open(int freq, int nchannels, void *userdata)
{
    if (ffmpeg_audio_do_not_initialize)
        return;
    
    if (ffmpeg_audio_is_initialized)
        return;
    NSLog(@"ffmpeg_audio_open freq %d nchannels %d", freq, nchannels);
    memset (&in.mDataFormat, 0, sizeof (in.mDataFormat));
    in.mDataFormat.mSampleRate = freq;
    in.mDataFormat.mFormatID = kAudioFormatLinearPCM;
    in.mDataFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger;
    in.mDataFormat.mBytesPerPacket = 2*nchannels;
    in.mDataFormat.mFramesPerPacket = 1;
    in.mDataFormat.mBytesPerFrame = 2*nchannels;
    in.mDataFormat.mChannelsPerFrame = nchannels;
    in.mDataFormat.mBitsPerChannel = 16;
    in.frameCount = SDL_AUDIO_BUFFER_SIZE;
    UInt32 err;
    err = AudioQueueNewOutput(&in.mDataFormat,
                              ffmpeg_audio_queue_callback,
                              userdata,
                              NULL,//CFRunLoopGetMain(),
                              NULL,//kCFRunLoopDefaultMode,
                              0,
                              &in.queue);
    
    unsigned long bufsize;
    bufsize = in.frameCount * in.mDataFormat.mBytesPerFrame;
    
    for (int i=0; i<FFMPEG_AUDIO_BUFFERS; i++) {
        err = AudioQueueAllocateBuffer(in.queue, bufsize, &in.mBuffers[i]);
        in.mBuffers[i]->mAudioDataByteSize = bufsize;
        AudioQueueEnqueueBuffer(in.queue, in.mBuffers[i], 0, NULL);
    }
    
    ffmpeg_audio_is_initialized = 1;
    err = AudioQueueStart(in.queue, NULL);
    
    return;
}

static void ffmpeg_delay(uint32_t ms)
{
    int was_error;
    struct timespec elapsed, tv;
    elapsed.tv_sec = ms/1000;
    elapsed.tv_nsec = (ms%1000)*1000000;
    do {
        errno = 0;
        tv.tv_sec = elapsed.tv_sec;
        tv.tv_nsec = elapsed.tv_nsec;
        was_error = nanosleep(&tv, &elapsed);
    } while ( was_error && (errno == EINTR) );
}

/*
 * Copyright (c) 2003 Fabrice Bellard
 *
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

/**
 * @file
 * simple media player based on the FFmpeg libraries
 */

#include <inttypes.h>
#include <math.h>
#include <limits.h>
#include <signal.h>
#include "libavutil/avstring.h"
#include "libavutil/colorspace.h"
#include "libavutil/mathematics.h"
#include "libavutil/pixdesc.h"
#include "libavutil/imgutils.h"
#include "libavutil/dict.h"
#include "libavutil/parseutils.h"
#include "libavutil/samplefmt.h"
#include "libavutil/avassert.h"
#include "libavformat/avformat.h"
#include "libavdevice/avdevice.h"
#include "libswscale/swscale.h"
#include "libavutil/opt.h"
#include "libavcodec/avfft.h"
#include "libswresample/swresample.h"

#include <unistd.h>
#include <assert.h>

const char program_name[] = "ffplay";
const int program_birth_year = 2003;

#define MAX_QUEUE_SIZE (15 * 1024 * 1024)
#define MIN_FRAMES 5


/* no AV sync correction is done if below the AV sync threshold */
#define AV_SYNC_THRESHOLD 0.01
/* no AV correction is done if too big error */
#define AV_NOSYNC_THRESHOLD 10.0

/* maximum audio speed change to get correct sync */
#define SAMPLE_CORRECTION_PERCENT_MAX 10

/* we use about AUDIO_DIFF_AVG_NB A-V differences to make the average */
#define AUDIO_DIFF_AVG_NB   20

/* NOTE: the size must be big enough to compensate the hardware audio buffersize size */
#define SAMPLE_ARRAY_SIZE (2 * 65536)

typedef struct PacketQueue {
AVPacketList *first_pkt, *last_pkt;
int nb_packets;
int size;
int abort_request;
pthread_mutex_t mutex;
pthread_cond_t cond;
} PacketQueue;

#define VIDEO_PICTURE_QUEUE_SIZE 2
#define SUBPICTURE_QUEUE_SIZE 4

typedef struct VideoPicture {
double pts;                                  ///< presentation time stamp for this picture
double duration;                             ///< expected duration of the frame
int64_t pos;                                 ///< byte position in file
int skip;
CGContextRef bmp;
int width, height; /* source height & width */
AVRational sample_aspect_ratio;
int allocated;
int reallocate;
enum PixelFormat pix_fmt;

pthread_mutex_t bmp_mutex;
} VideoPicture;

typedef struct SubPicture {
double pts; /* presentation time stamp for this picture */
AVSubtitle sub;
} SubPicture;

enum {
    AV_SYNC_AUDIO_MASTER, /* default choice */
    AV_SYNC_VIDEO_MASTER,
    AV_SYNC_EXTERNAL_CLOCK, /* synchronize to an external clock */
};

typedef struct VideoState {
pthread_t read_tid;
pthread_t video_tid;
AVInputFormat *iformat;
int no_background;
int abort_request;
int force_refresh;
int paused;
int last_paused;
int seek_req;
int seek_flags;
int64_t seek_pos;
int64_t seek_rel;
int read_pause_return;
AVFormatContext *ic;

int audio_stream;

int av_sync_type;
double external_clock; /* external clock base */
int64_t external_clock_time;

double audio_clock;
double audio_diff_cum; /* used for AV difference average computation */
double audio_diff_avg_coef;
double audio_diff_threshold;
int audio_diff_avg_count;
AVStream *audio_st;
PacketQueue audioq;
int audio_hw_buf_size;
DECLARE_ALIGNED(16,uint8_t,audio_buf2)[AVCODEC_MAX_AUDIO_FRAME_SIZE * 4];
uint8_t silence_buf[SDL_AUDIO_BUFFER_SIZE];
uint8_t *audio_buf;
uint8_t *audio_buf1;
unsigned int audio_buf_size; /* in bytes */
int audio_buf_index; /* in bytes */
int audio_write_buf_size;
AVPacket audio_pkt_temp;
AVPacket audio_pkt;
enum AVSampleFormat audio_src_fmt;
enum AVSampleFormat audio_tgt_fmt;
int audio_src_channels;
int audio_tgt_channels;
int64_t audio_src_channel_layout;
int64_t audio_tgt_channel_layout;
int audio_src_freq;
int audio_tgt_freq;
struct SwrContext *swr_ctx;
double audio_current_pts;
double audio_current_pts_drift;
int frame_drops_early;
int frame_drops_late;
AVFrame *frame;

enum ShowMode {
    SHOW_MODE_NONE = -1, SHOW_MODE_VIDEO = 0, SHOW_MODE_WAVES, SHOW_MODE_RDFT, SHOW_MODE_NB
} show_mode;
int16_t sample_array[SAMPLE_ARRAY_SIZE];
int sample_array_index;
int last_i_start;
RDFTContext *rdft;
int rdft_bits;
FFTSample *rdft_data;
int xpos;

pthread_t subtitle_tid;
int subtitle_stream;
int subtitle_stream_changed;
AVStream *subtitle_st;
PacketQueue subtitleq;
SubPicture subpq[SUBPICTURE_QUEUE_SIZE];
int subpq_size, subpq_rindex, subpq_windex;
pthread_mutex_t subpq_mutex;
pthread_cond_t subpq_cond;

double frame_timer;
double frame_last_pts;
double frame_last_duration;
double frame_last_dropped_pts;
double frame_last_returned_time;
double frame_last_filter_delay;
int64_t frame_last_dropped_pos;
double video_clock;                          ///< pts of last decoded frame / predicted pts of next decoded frame
int video_stream;
AVStream *video_st;
PacketQueue videoq;
double video_current_pts;                    ///< current displayed pts (different from video_clock if frame fifos are used)
double video_current_pts_drift;              ///< video_current_pts - time (av_gettime) at which we updated video_current_pts - used to have running video pts
int64_t video_current_pos;                   ///< current displayed file pos
VideoPicture pictq[VIDEO_PICTURE_QUEUE_SIZE];
int pictq_size, pictq_rindex, pictq_windex;
pthread_mutex_t pictq_mutex;
pthread_cond_t pictq_cond;
#if !CONFIG_AVFILTER
struct SwsContext *img_convert_ctx;
#endif

char filename[1024];
int width, height, xleft, ytop;
int step;


int refresh;
int last_video_stream, last_audio_stream, last_subtitle_stream;

UIView *view;
} VideoState;

/* options specified by the user */
static int wanted_stream[AVMEDIA_TYPE_NB] = {
    [AVMEDIA_TYPE_AUDIO]    = -1,
    [AVMEDIA_TYPE_VIDEO]    = -1,
    [AVMEDIA_TYPE_SUBTITLE] = -1,
};
static int seek_by_bytes = -1;
static int show_status = 1;
static int64_t start_time = AV_NOPTS_VALUE;
static int64_t duration = AV_NOPTS_VALUE;
static int workaround_bugs = 1;
static int fast = 0;
static int genpts = 0;
static int lowres = 0;
static int idct = FF_IDCT_AUTO;
static enum AVDiscard skip_frame       = AVDISCARD_DEFAULT;
static enum AVDiscard skip_idct        = AVDISCARD_DEFAULT;
static enum AVDiscard skip_loop_filter = AVDISCARD_DEFAULT;
static int error_concealment = 3;
static int decoder_reorder_pts = -1;
static int autoexit;
static int loop = 1;
static int framedrop = -1;
static enum ShowMode show_mode = SHOW_MODE_NONE;
static const char *audio_codec_name;
static const char *subtitle_codec_name;
static const char *video_codec_name;
static int rdftspeed = 20;

/* current context */
static int64_t audio_callback_time;

static AVPacket flush_pkt;

void av_noreturn exit_program(int ret)
{
    exit(ret);
}

static int packet_queue_put_private(PacketQueue *q, AVPacket *pkt)
{
    AVPacketList *pkt1;
    
    if (q->abort_request)
        return -1;
    
    pkt1 = av_malloc(sizeof(AVPacketList));
    if (!pkt1)
        return -1;
    pkt1->pkt = *pkt;
    pkt1->next = NULL;
    
    if (!q->last_pkt)
        q->first_pkt = pkt1;
    else
        q->last_pkt->next = pkt1;
    q->last_pkt = pkt1;
    q->nb_packets++;
    q->size += pkt1->pkt.size + sizeof(*pkt1);
    /* XXX: should duplicate packet data in DV case */
    pthread_cond_signal(&q->cond);
    return 0;
}

static int packet_queue_put(PacketQueue *q, AVPacket *pkt)
{
    int ret;
    
    /* duplicate the packet */
    if (pkt != &flush_pkt && av_dup_packet(pkt) < 0)
        return -1;
    
    pthread_mutex_lock(&q->mutex);
    ret = packet_queue_put_private(q, pkt);
    pthread_mutex_unlock(&q->mutex);
    
    if (pkt != &flush_pkt && ret < 0)
        av_free_packet(pkt);
    
    return ret;
}

/* packet queue handling */
static void packet_queue_init(PacketQueue *q)
{
    memset(q, 0, sizeof(PacketQueue));
    pthread_mutex_init(&q->mutex, NULL);
    pthread_cond_init(&q->cond, NULL);
    q->abort_request = 1;
}

static void packet_queue_flush(PacketQueue *q)
{
    AVPacketList *pkt, *pkt1;
    
    pthread_mutex_lock(&q->mutex);
    for (pkt = q->first_pkt; pkt != NULL; pkt = pkt1) {
        pkt1 = pkt->next;
        av_free_packet(&pkt->pkt);
        av_freep(&pkt);
    }
    q->last_pkt = NULL;
    q->first_pkt = NULL;
    q->nb_packets = 0;
    q->size = 0;
    pthread_mutex_unlock(&q->mutex);
}

static void packet_queue_destroy(PacketQueue *q)
{
    packet_queue_flush(q);
    pthread_mutex_destroy(&q->mutex);
    pthread_cond_destroy(&q->cond);
}

static void packet_queue_abort(PacketQueue *q)
{
    pthread_mutex_lock(&q->mutex);
    
    q->abort_request = 1;
    
    pthread_cond_signal(&q->cond);
    
    pthread_mutex_unlock(&q->mutex);
}

static void packet_queue_start(PacketQueue *q)
{
    pthread_mutex_lock(&q->mutex);
    q->abort_request = 0;
    packet_queue_put_private(q, &flush_pkt);
    pthread_mutex_unlock(&q->mutex);
}

/* return < 0 if aborted, 0 if no packet and > 0 if packet.  */
static int packet_queue_get(PacketQueue *q, AVPacket *pkt, int block)
{
    AVPacketList *pkt1;
    int ret;
    
    pthread_mutex_lock(&q->mutex);
    
    for (;;) {
        if (q->abort_request) {
            ret = -1;
            break;
        }
        
        pkt1 = q->first_pkt;
        if (pkt1) {
            q->first_pkt = pkt1->next;
            if (!q->first_pkt)
                q->last_pkt = NULL;
            q->nb_packets--;
            q->size -= pkt1->pkt.size + sizeof(*pkt1);
            *pkt = pkt1->pkt;
            av_free(pkt1);
            ret = 1;
            break;
        } else if (!block) {
            ret = 0;
            break;
        } else {
            pthread_cond_wait(&q->cond, &q->mutex);
        }
    }
    pthread_mutex_unlock(&q->mutex);
    return ret;
}

#if 0
static inline void fill_rectangle(SDL_Surface *screen,
                                  int x, int y, int w, int h, int color)
{
    SDL_Rect rect;
    rect.x = x;
    rect.y = y;
    rect.w = w;
    rect.h = h;
    SDL_FillRect(screen, &rect, color);
}
#endif

#define ALPHA_BLEND(a, oldp, newp, s)\
((((oldp << s) * (255 - (a))) + (newp * (a))) / (255 << s))

#define RGBA_IN(r, g, b, a, s)\
{\
unsigned int v = ((const uint32_t *)(s))[0];\
a = (v >> 24) & 0xff;\
r = (v >> 16) & 0xff;\
g = (v >> 8) & 0xff;\
b = v & 0xff;\
}

#define RGBA_OUT(d, r, g, b, a)\
{\
((uint32_t *)(d))[0] = (a << 24) | (r << 16) | (g << 8) | b;\
}

#define YUVA_IN(y, u, v, a, s, pal)\
{\
unsigned int val = ((const uint32_t *)(pal))[*(const uint8_t*)(s)];\
a = (val >> 24) & 0xff;\
y = (val >> 16) & 0xff;\
u = (val >> 8) & 0xff;\
v = val & 0xff;\
}

#define YUVA_OUT(d, y, u, v, a)\
{\
((uint32_t *)(d))[0] = (a << 24) | (y << 16) | (u << 8) | v;\
}


static void blend_subrect(AVPicture *dst, const AVSubtitleRect *rect, int imgw, int imgh)
{
    int dstx, dsty, dstw, dsth;
    
    dstw = av_clip(rect->w, 0, imgw);
    dsth = av_clip(rect->h, 0, imgh);
    dstx = av_clip(rect->x, 0, imgw - dstw);
    dsty = av_clip(rect->y, 0, imgh - dsth);
    
    int dstwrap = dst->linesize[0];
    int srcwrap = rect->pict.linesize[0];
    
    uint8_t *dstp = dst->data[0] + dsty * dst->linesize[0] + dstx * 4;
    uint8_t *srcp = rect->pict.data[0];
    
    for(int i=0; i<dsth; i++) {
        for(int j=0; j<dstw; j++) {
            uint8_t *dstq = dstp;
            uint8_t *srcq = srcp;
            int inr, ing, inb, ina;
            int outr, outg, outb, outa;
            RGBA_IN(inr, ing, inb, ina, srcq);
            RGBA_IN(outr, outg, outb, outa, dstq);
            outr = (inr * ina + outr * (255 - ina)) / 255;
            outg = (ing * ina + outg * (255 - ina)) / 255;
            outb = (inb * ina + outb * (255 - ina)) / 255;
            RGBA_OUT(dstq, outr, outg, outb, outa);
            srcq += 4;
            dstq += 4;
        }
        dstp += dstwrap;
        srcp += srcwrap;
    }
}

static void free_subpicture(SubPicture *sp)
{
    avsubtitle_free(&sp->sub);
}

static void video_image_display(VideoState *is)
{
    VideoPicture *vp;
    SubPicture *sp;
    AVPicture pict;
    int i;
    
    vp = &is->pictq[is->pictq_rindex];
    if (vp->bmp) {
        if (is->subtitle_st) {
            if (is->subpq_size > 0) {
                sp = &is->subpq[is->subpq_rindex];
                
                if (vp->pts >= sp->pts + ((float) sp->sub.start_display_time / 1000)) {
                    pthread_mutex_lock(&vp->bmp_mutex);
                    
                    pict.data[0] = CGBitmapContextGetData(vp->bmp);
                    pict.linesize[0] = CGBitmapContextGetBytesPerRow(vp->bmp);
                    
                    for (i = 0; i < sp->sub.num_rects; i++)
                        blend_subrect(&pict, sp->sub.rects[i],
                                      CGBitmapContextGetWidth(vp->bmp),
                                      CGBitmapContextGetHeight(vp->bmp));
                    
                    pthread_mutex_unlock(&vp->bmp_mutex);
                }
            }
        }
        
        is->no_background = 0;
        [is->view performSelectorOnMainThread:@selector(displayEvent:) withObject:[NSValue valueWithPointer:vp] waitUntilDone:YES];
    }
}

static inline int compute_mod(int a, int b)
{
    return a < 0 ? a%b + b : a%b;
}

static void video_audio_display(VideoState *s)
{
#if 0
    int i, i_start, x, y1, y, ys, delay, n, nb_display_channels;
    int ch, channels, h, h2, bgcolor, fgcolor;
    int16_t time_diff;
    int rdft_bits, nb_freq;
    
    for (rdft_bits = 1; (1 << rdft_bits) < 2 * s->height; rdft_bits++)
        ;
    nb_freq = 1 << (rdft_bits - 1);
    
    /* compute display index : center on currently output samples */
    channels = s->audio_tgt_channels;
    nb_display_channels = channels;
    if (!s->paused) {
        int data_used= s->show_mode == SHOW_MODE_WAVES ? s->width : (2*nb_freq);
        n = 2 * channels;
        delay = s->audio_write_buf_size;
        delay /= n;
        
        /* to be more precise, we take into account the time spent since
         the last buffer computation */
        if (audio_callback_time) {
            time_diff = av_gettime() - audio_callback_time;
            delay -= (time_diff * s->audio_tgt_freq) / 1000000;
        }
        
        delay += 2 * data_used;
        if (delay < data_used)
            delay = data_used;
        
        i_start= x = compute_mod(s->sample_array_index - delay * channels, SAMPLE_ARRAY_SIZE);
        if (s->show_mode == SHOW_MODE_WAVES) {
            h = INT_MIN;
            for (i = 0; i < 1000; i += channels) {
                int idx = (SAMPLE_ARRAY_SIZE + x - i) % SAMPLE_ARRAY_SIZE;
                int a = s->sample_array[idx];
                int b = s->sample_array[(idx + 4 * channels) % SAMPLE_ARRAY_SIZE];
                int c = s->sample_array[(idx + 5 * channels) % SAMPLE_ARRAY_SIZE];
                int d = s->sample_array[(idx + 9 * channels) % SAMPLE_ARRAY_SIZE];
                int score = a - d;
                if (h < score && (b ^ c) < 0) {
                    h = score;
                    i_start = idx;
                }
            }
        }
        
        s->last_i_start = i_start;
    } else {
        i_start = s->last_i_start;
    }
    
    bgcolor = SDL_MapRGB(screen->format, 0x00, 0x00, 0x00);
    if (s->show_mode == SHOW_MODE_WAVES) {
        fill_rectangle(screen,
                       s->xleft, s->ytop, s->width, s->height,
                       bgcolor);
        
        fgcolor = SDL_MapRGB(screen->format, 0xff, 0xff, 0xff);
        
        /* total height for one channel */
        h = s->height / nb_display_channels;
        /* graph height / 2 */
        h2 = (h * 9) / 20;
        for (ch = 0; ch < nb_display_channels; ch++) {
            i = i_start + ch;
            y1 = s->ytop + ch * h + (h / 2); /* position of center line */
            for (x = 0; x < s->width; x++) {
                y = (s->sample_array[i] * h2) >> 15;
                if (y < 0) {
                    y = -y;
                    ys = y1 - y;
                } else {
                    ys = y1;
                }
                fill_rectangle(screen,
                               s->xleft + x, ys, 1, y,
                               fgcolor);
                i += channels;
                if (i >= SAMPLE_ARRAY_SIZE)
                    i -= SAMPLE_ARRAY_SIZE;
            }
        }
        
        fgcolor = SDL_MapRGB(screen->format, 0x00, 0x00, 0xff);
        
        for (ch = 1; ch < nb_display_channels; ch++) {
            y = s->ytop + ch * h;
            fill_rectangle(screen,
                           s->xleft, y, s->width, 1,
                           fgcolor);
        }
        SDL_UpdateRect(screen, s->xleft, s->ytop, s->width, s->height);
    } else {
        nb_display_channels= FFMIN(nb_display_channels, 2);
        if (rdft_bits != s->rdft_bits) {
            av_rdft_end(s->rdft);
            av_free(s->rdft_data);
            s->rdft = av_rdft_init(rdft_bits, DFT_R2C);
            s->rdft_bits = rdft_bits;
            s->rdft_data = av_malloc(4 * nb_freq * sizeof(*s->rdft_data));
        }
        {
            FFTSample *data[2];
            for (ch = 0; ch < nb_display_channels; ch++) {
                data[ch] = s->rdft_data + 2 * nb_freq * ch;
                i = i_start + ch;
                for (x = 0; x < 2 * nb_freq; x++) {
                    double w = (x-nb_freq) * (1.0 / nb_freq);
                    data[ch][x] = s->sample_array[i] * (1.0 - w * w);
                    i += channels;
                    if (i >= SAMPLE_ARRAY_SIZE)
                        i -= SAMPLE_ARRAY_SIZE;
                }
                av_rdft_calc(s->rdft, data[ch]);
            }
            // least efficient way to do this, we should of course directly access it but its more than fast enough
            for (y = 0; y < s->height; y++) {
                double w = 1 / sqrt(nb_freq);
                int a = sqrt(w * sqrt(data[0][2 * y + 0] * data[0][2 * y + 0] + data[0][2 * y + 1] * data[0][2 * y + 1]));
                int b = (nb_display_channels == 2 ) ? sqrt(w * sqrt(data[1][2 * y + 0] * data[1][2 * y + 0]
                                                                    + data[1][2 * y + 1] * data[1][2 * y + 1])) : a;
                a = FFMIN(a, 255);
                b = FFMIN(b, 255);
                fgcolor = SDL_MapRGB(screen->format, a, b, (a + b) / 2);
                
                fill_rectangle(screen,
                               s->xpos, s->height-y, 1, 1,
                               fgcolor);
            }
        }
        SDL_UpdateRect(screen, s->xpos, s->ytop, 1, s->height);
        if (!s->paused)
            s->xpos++;
        if (s->xpos >= s->width)
            s->xpos= s->xleft;
    }
#endif
}

static void stream_close(VideoState *is)
{
    VideoPicture *vp;
    int i;
    /* XXX: use a special url_shutdown call to abort parse cleanly */
    is->abort_request = 1;
    pthread_join(is->read_tid, NULL);
    packet_queue_destroy(&is->videoq);
    packet_queue_destroy(&is->audioq);
    packet_queue_destroy(&is->subtitleq);
    
    /* free all pictures */
    for (i = 0; i < VIDEO_PICTURE_QUEUE_SIZE; i++) {
        vp = &is->pictq[i];
        pthread_mutex_lock(&vp->bmp_mutex);
        if (vp->bmp) {
            CFRelease(vp->bmp);
            vp->bmp = NULL;
        }
        pthread_mutex_unlock(&vp->bmp_mutex);
    }
    pthread_mutex_destroy(&is->pictq_mutex);
    pthread_cond_destroy(&is->pictq_cond);
    pthread_mutex_destroy(&is->subpq_mutex);
    pthread_cond_destroy(&is->subpq_cond);
#if !CONFIG_AVFILTER
    if (is->img_convert_ctx)
        sws_freeContext(is->img_convert_ctx);
#endif
    av_free(is);
}

static int video_open(VideoState *is, int force_set_video_mode)
{
    int w,h;
    VideoPicture *vp = &is->pictq[is->pictq_rindex];
    
    if (vp->width) {
        w = vp->width;
        h = vp->height;
    } else {
        w = 640;
        h = 480;
    }
    
    is->width  = w;
    is->height = h;
    
    return 0;
}

/* display the current picture, if any */
static void video_display(VideoState *is)
{
//    if (!screen)
        video_open(is, 0);
    if (is->audio_st && is->show_mode != SHOW_MODE_VIDEO)
        video_audio_display(is);
    else if (is->video_st)
        video_image_display(is);
}

/* get the current audio clock value */
static double get_audio_clock(VideoState *is)
{
    if (is->paused) {
        return is->audio_current_pts;
    } else {
        return is->audio_current_pts_drift + av_gettime() / 1000000.0;
    }
}

/* get the current video clock value */
static double get_video_clock(VideoState *is)
{
    if (is->paused) {
        return is->video_current_pts;
    } else {
        return is->video_current_pts_drift + av_gettime() / 1000000.0;
    }
}

/* get the current external clock value */
static double get_external_clock(VideoState *is)
{
    int64_t ti;
    ti = av_gettime();
    return is->external_clock + ((ti - is->external_clock_time) * 1e-6);
}

/* get the current master clock value */
static double get_master_clock(VideoState *is)
{
    double val;
    
    if (is->av_sync_type == AV_SYNC_VIDEO_MASTER) {
        if (is->video_st)
            val = get_video_clock(is);
        else
            val = get_audio_clock(is);
    } else if (is->av_sync_type == AV_SYNC_AUDIO_MASTER) {
        if (is->audio_st)
            val = get_audio_clock(is);
        else
            val = get_video_clock(is);
    } else {
        val = get_external_clock(is);
    }
    return val;
}

/* seek in the stream */
static void stream_seek(VideoState *is, int64_t pos, int64_t rel, int seek_by_bytes)
{
    if (!is->seek_req) {
        is->seek_pos = pos;
        is->seek_rel = rel;
        is->seek_flags &= ~AVSEEK_FLAG_BYTE;
        if (seek_by_bytes)
            is->seek_flags |= AVSEEK_FLAG_BYTE;
        is->seek_req = 1;
    }
}

/* pause or resume the video */
static void stream_toggle_pause(VideoState *is)
{
    if (is->paused) {
        is->frame_timer += av_gettime() / 1000000.0 + is->video_current_pts_drift - is->video_current_pts;
        if (is->read_pause_return != AVERROR(ENOSYS)) {
            is->video_current_pts = is->video_current_pts_drift + av_gettime() / 1000000.0;
        }
        is->video_current_pts_drift = is->video_current_pts - av_gettime() / 1000000.0;
    }
    is->paused = !is->paused;
}

static double compute_target_delay(double delay, VideoState *is)
{
    double sync_threshold, diff;
    
    /* update delay to follow master synchronisation source */
    if (((is->av_sync_type == AV_SYNC_AUDIO_MASTER && is->audio_st) ||
         is->av_sync_type == AV_SYNC_EXTERNAL_CLOCK)) {
        /* if video is slave, we try to correct big delays by
         duplicating or deleting a frame */
        diff = get_video_clock(is) - get_master_clock(is);
        
        /* skip or repeat frame. We take into account the
         delay to compute the threshold. I still don't know
         if it is the best guess */
        sync_threshold = FFMAX(AV_SYNC_THRESHOLD, delay);
        if (fabs(diff) < AV_NOSYNC_THRESHOLD) {
            if (diff <= -sync_threshold)
                delay = 0;
            else if (diff >= sync_threshold)
                delay = 2 * delay;
        }
    }
    
    av_dlog(NULL, "video: delay=%0.3f A-V=%f\n",
            delay, -diff);
    
    return delay;
}

static void pictq_next_picture(VideoState *is) {
    /* update queue size and signal for next picture */
    if (++is->pictq_rindex == VIDEO_PICTURE_QUEUE_SIZE)
        is->pictq_rindex = 0;
    
    pthread_mutex_lock(&is->pictq_mutex);
    is->pictq_size--;
    pthread_cond_signal(&is->pictq_cond);
    pthread_mutex_unlock(&is->pictq_mutex);
}

static void update_video_pts(VideoState *is, double pts, int64_t pos) {
    double time = av_gettime() / 1000000.0;
    /* update current video pts */
    is->video_current_pts = pts;
    is->video_current_pts_drift = is->video_current_pts - time;
    is->video_current_pos = pos;
    is->frame_last_pts = pts;
}

/* called to display each frame */
static void video_refresh(void *opaque)
{
    VideoState *is = opaque;
    VideoPicture *vp;
    double time;
    
    SubPicture *sp, *sp2;
    
    if (is->video_st) {
    retry:
        if (is->pictq_size == 0) {
            pthread_mutex_lock(&is->pictq_mutex);
            if (is->frame_last_dropped_pts != AV_NOPTS_VALUE && is->frame_last_dropped_pts > is->frame_last_pts) {
                update_video_pts(is, is->frame_last_dropped_pts, is->frame_last_dropped_pos);
                is->frame_last_dropped_pts = AV_NOPTS_VALUE;
            }
            pthread_mutex_unlock(&is->pictq_mutex);
            // nothing to do, no picture to display in the que
        } else {
            double last_duration, duration, delay;
            /* dequeue the picture */
            vp = &is->pictq[is->pictq_rindex];
            
            if (vp->skip) {
                pictq_next_picture(is);
                goto retry;
            }
            
            if (is->paused)
                goto display;
            
            /* compute nominal last_duration */
            last_duration = vp->pts - is->frame_last_pts;
            if (last_duration > 0 && last_duration < 10.0) {
                /* if duration of the last frame was sane, update last_duration in video state */
                is->frame_last_duration = last_duration;
            }
            delay = compute_target_delay(is->frame_last_duration, is);
            
            time= av_gettime()/1000000.0;
            if (time < is->frame_timer + delay)
                return;
            
            if (delay > 0)
                is->frame_timer += delay * FFMAX(1, floor((time-is->frame_timer) / delay));
            
            pthread_mutex_lock(&is->pictq_mutex);
            update_video_pts(is, vp->pts, vp->pos);
            pthread_mutex_unlock(&is->pictq_mutex);
            
            if (is->pictq_size > 1) {
                VideoPicture *nextvp = &is->pictq[(is->pictq_rindex + 1) % VIDEO_PICTURE_QUEUE_SIZE];
                duration = nextvp->pts - vp->pts; // More accurate this way, 1/time_base is often not reflecting FPS
            } else {
                duration = vp->duration;
            }
            
            if((framedrop>0 || (framedrop && is->audio_st)) && time > is->frame_timer + duration){
                if(is->pictq_size > 1){
                    is->frame_drops_late++;
                    pictq_next_picture(is);
                    goto retry;
                }
            }
            
            if (is->subtitle_st) {
                if (is->subtitle_stream_changed) {
                    pthread_mutex_lock(&is->subpq_mutex);
                    
                    while (is->subpq_size) {
                        free_subpicture(&is->subpq[is->subpq_rindex]);
                        
                        /* update queue size and signal for next picture */
                        if (++is->subpq_rindex == SUBPICTURE_QUEUE_SIZE)
                            is->subpq_rindex = 0;
                        
                        is->subpq_size--;
                    }
                    is->subtitle_stream_changed = 0;
                    
                    pthread_cond_signal(&is->subpq_cond);
                    pthread_mutex_unlock(&is->subpq_mutex);
                } else {
                    if (is->subpq_size > 0) {
                        sp = &is->subpq[is->subpq_rindex];
                        
                        if (is->subpq_size > 1)
                            sp2 = &is->subpq[(is->subpq_rindex + 1) % SUBPICTURE_QUEUE_SIZE];
                        else
                            sp2 = NULL;
                        
                        if ((is->video_current_pts > (sp->pts + ((float) sp->sub.end_display_time / 1000)))
                            || (sp2 && is->video_current_pts > (sp2->pts + ((float) sp2->sub.start_display_time / 1000))))
                        {
                            free_subpicture(sp);
                            
                            /* update queue size and signal for next picture */
                            if (++is->subpq_rindex == SUBPICTURE_QUEUE_SIZE)
                                is->subpq_rindex = 0;
                            
                            pthread_mutex_lock(&is->subpq_mutex);
                            is->subpq_size--;
                            pthread_cond_signal(&is->subpq_cond);
                            pthread_mutex_unlock(&is->subpq_mutex);
                        }
                    }
                }
            }
            
        display:
            /* display picture */
                video_display(is);
            
            if (!is->paused)
                pictq_next_picture(is);
        }
    } else if (is->audio_st) {
        /* draw the next audio frame */
        
        /* if only audio stream, then display the audio bars (better
         than nothing, just to test the implementation */
        
        /* display picture */
            video_display(is);
    }
    is->force_refresh = 0;
    if (show_status) {
        static int64_t last_time;
        int64_t cur_time;
        int aqsize, vqsize, sqsize;
        double av_diff;
        
        cur_time = av_gettime();
        if (!last_time || (cur_time - last_time) >= 30000) {
            aqsize = 0;
            vqsize = 0;
            sqsize = 0;
            if (is->audio_st)
                aqsize = is->audioq.size;
            if (is->video_st)
                vqsize = is->videoq.size;
            if (is->subtitle_st)
                sqsize = is->subtitleq.size;
            av_diff = 0;
            if (is->audio_st && is->video_st)
                av_diff = get_audio_clock(is) - get_video_clock(is);
            printf("%7.2f A-V:%7.3f fd=%4d aq=%5dKB vq=%5dKB sq=%5dB f=%"PRId64"/%"PRId64"   \r",
                   get_master_clock(is),
                   av_diff,
                   is->frame_drops_early + is->frame_drops_late,
                   aqsize / 1024,
                   vqsize / 1024,
                   sqsize,
                   is->video_st ? is->video_st->codec->pts_correction_num_faulty_dts : 0,
                   is->video_st ? is->video_st->codec->pts_correction_num_faulty_pts : 0);
            fflush(stdout);
            last_time = cur_time;
        }
    }
}

static int queue_picture(VideoState *is, AVFrame *src_frame, double pts1, int64_t pos)
{
    VideoPicture *vp;
    double frame_delay, pts = pts1;
    
    /* compute the exact PTS for the picture if it is omitted in the stream
     * pts1 is the dts of the pkt / pts of the frame */
    if (pts != 0) {
        /* update video clock with pts, if present */
        is->video_clock = pts;
    } else {
        pts = is->video_clock;
    }
    /* update video clock for next frame */
    frame_delay = av_q2d(is->video_st->codec->time_base);
    /* for MPEG2, the frame can be repeated, so we update the
     clock accordingly */
    frame_delay += src_frame->repeat_pict * (frame_delay * 0.5);
    is->video_clock += frame_delay;
    
    
    /* wait until we have space to put a new picture */
    pthread_mutex_lock(&is->pictq_mutex);
    
    while (is->pictq_size >= VIDEO_PICTURE_QUEUE_SIZE &&
           !is->videoq.abort_request) {
        pthread_cond_wait(&is->pictq_cond, &is->pictq_mutex);
    }
    pthread_mutex_unlock(&is->pictq_mutex);
    
    if (is->videoq.abort_request)
        return -1;
    
    vp = &is->pictq[is->pictq_windex];
    
    vp->duration = frame_delay;
    
    /* alloc or resize hardware picture buffer */
    if (!vp->bmp || vp->reallocate ||
        vp->width  != src_frame->width ||
        vp->height != src_frame->height)
    {
        vp->allocated  = 0;
        vp->reallocate = 0;
        
        [is->view performSelectorOnMainThread:@selector(allocEvent:) withObject:[NSValue valueWithPointer:src_frame] waitUntilDone:YES];
              
        if (is->videoq.abort_request)
            return -1;
    }
    
    /* if the frame is not skipped, then display it */
    if (vp->bmp) {
        AVPicture pict = { { 0 } };
     
        /* get a pointer on the bitmap */
        pthread_mutex_lock(&vp->bmp_mutex);
        
        pict.data[0] = CGBitmapContextGetData(vp->bmp);
        pict.data[1] = NULL;
        pict.data[2] = NULL;
        
        pict.linesize[0] = vp->width * 4;
        pict.linesize[1] = 0;
        pict.linesize[2] = 0;
        
        is->img_convert_ctx = sws_getCachedContext(is->img_convert_ctx,
                                                   vp->width, vp->height, vp->pix_fmt, vp->width, vp->height,
                                                   PIX_FMT_RGBA, SWS_BICUBIC, NULL, NULL, NULL);
        if (is->img_convert_ctx == NULL) {
            fprintf(stderr, "Cannot initialize the conversion context\n");
            exit(1);
        }
        sws_scale(is->img_convert_ctx, src_frame->data, src_frame->linesize,
                  0, vp->height, pict.data, pict.linesize);
        vp->sample_aspect_ratio = av_guess_sample_aspect_ratio(is->ic, is->video_st, src_frame);

        /* update the bitmap content */
        pthread_mutex_unlock(&vp->bmp_mutex);
        
        vp->pts = pts;
        vp->pos = pos;
        vp->skip = 0;
        
        /* now we can update the picture count */
        if (++is->pictq_windex == VIDEO_PICTURE_QUEUE_SIZE)
            is->pictq_windex = 0;
        pthread_mutex_lock(&is->pictq_mutex);
        is->pictq_size++;
        pthread_mutex_unlock(&is->pictq_mutex);
    }
    return 0;
}

static int get_video_frame(VideoState *is, AVFrame *frame, int64_t *pts, AVPacket *pkt)
{
    int got_picture, i;
    
    if (packet_queue_get(&is->videoq, pkt, 1) < 0)
        return -1;
    
    if (pkt->data == flush_pkt.data) {
        avcodec_flush_buffers(is->video_st->codec);
        
        pthread_mutex_lock(&is->pictq_mutex);
        // Make sure there are no long delay timers (ideally we should just flush the que but thats harder)
        for (i = 0; i < VIDEO_PICTURE_QUEUE_SIZE; i++) {
            is->pictq[i].skip = 1;
        }
        while (is->pictq_size && !is->videoq.abort_request) {
            pthread_cond_wait(&is->pictq_cond, &is->pictq_mutex);
        }
        is->video_current_pos = -1;
        is->frame_last_pts = AV_NOPTS_VALUE;
        is->frame_last_duration = 0;
        is->frame_timer = (double)av_gettime() / 1000000.0;
        is->frame_last_dropped_pts = AV_NOPTS_VALUE;
        pthread_mutex_unlock(&is->pictq_mutex);
        
        return 0;
    }
    
    avcodec_decode_video2(is->video_st->codec, frame, &got_picture, pkt);
    
    if (got_picture) {
        int ret = 1;
        
        if (decoder_reorder_pts == -1) {
            *pts = av_frame_get_best_effort_timestamp(frame);
        } else if (decoder_reorder_pts) {
            *pts = frame->pkt_pts;
        } else {
            *pts = frame->pkt_dts;
        }
        
        if (*pts == AV_NOPTS_VALUE) {
            *pts = 0;
        }
        
        if (((is->av_sync_type == AV_SYNC_AUDIO_MASTER && is->audio_st) || is->av_sync_type == AV_SYNC_EXTERNAL_CLOCK) &&
            (framedrop>0 || (framedrop && is->audio_st))) {
            pthread_mutex_lock(&is->pictq_mutex);
            if (is->frame_last_pts != AV_NOPTS_VALUE && *pts) {
                double clockdiff = get_video_clock(is) - get_master_clock(is);
                double dpts = av_q2d(is->video_st->time_base) * *pts;
                double ptsdiff = dpts - is->frame_last_pts;
                if (fabs(clockdiff) < AV_NOSYNC_THRESHOLD &&
                    ptsdiff > 0 && ptsdiff < AV_NOSYNC_THRESHOLD &&
                    clockdiff + ptsdiff - is->frame_last_filter_delay < 0) {
                    is->frame_last_dropped_pos = pkt->pos;
                    is->frame_last_dropped_pts = dpts;
                    is->frame_drops_early++;
                    ret = 0;
                }
            }
            pthread_mutex_unlock(&is->pictq_mutex);
        }
        
        if (ret)
            is->frame_last_returned_time = av_gettime() / 1000000.0;
        
        return ret;
    }
    return 0;
}


static int video_thread(void *arg)
{
    @autoreleasepool {
        VideoState *is = arg;
        AVFrame *frame = avcodec_alloc_frame();
        int64_t pts_int = AV_NOPTS_VALUE, pos = -1;
        double pts;
        int ret;
        
        
        for (;;) {
            AVPacket pkt;
            while (is->paused && !is->videoq.abort_request);
                ffmpeg_delay(10);
            ret = get_video_frame(is, frame, &pts_int, &pkt);
            pos = pkt.pos;
            av_free_packet(&pkt);
            if (ret == 0)
                continue;
            
            if (ret < 0)
                goto the_end;
            
            is->frame_last_filter_delay = av_gettime() / 1000000.0 - is->frame_last_returned_time;
            if (fabs(is->frame_last_filter_delay) > AV_NOSYNC_THRESHOLD / 10.0)
                is->frame_last_filter_delay = 0;
            
            
            pts = pts_int * av_q2d(is->video_st->time_base);
            
            ret = queue_picture(is, frame, pts, pos);
            
            if (ret < 0)
                goto the_end;
            
            if (is->step)
                stream_toggle_pause(is);
        }
    the_end:
        avcodec_flush_buffers(is->video_st->codec);
        av_free(frame);
        return 0;
    }
}

static int subtitle_thread(void *arg)
{
    @autoreleasepool {
        VideoState *is = arg;
        SubPicture *sp;
        AVPacket pkt1, *pkt = &pkt1;
        int got_subtitle;
        double pts;
        
        for (;;) {
            while (is->paused && !is->subtitleq.abort_request) {
                ffmpeg_delay(10);
            }
            if (packet_queue_get(&is->subtitleq, pkt, 1) < 0)
                break;
            
            if (pkt->data == flush_pkt.data) {
                avcodec_flush_buffers(is->subtitle_st->codec);
                continue;
            }
            pthread_mutex_lock(&is->subpq_mutex);
            while (is->subpq_size >= SUBPICTURE_QUEUE_SIZE &&
                   !is->subtitleq.abort_request) {
                pthread_cond_wait(&is->subpq_cond, &is->subpq_mutex);
            }
            pthread_mutex_unlock(&is->subpq_mutex);
            
            if (is->subtitleq.abort_request)
                return 0;
            
            sp = &is->subpq[is->subpq_windex];
            
            /* NOTE: ipts is the PTS of the _first_ picture beginning in
             this packet, if any */
            pts = 0;
            if (pkt->pts != AV_NOPTS_VALUE)
                pts = av_q2d(is->subtitle_st->time_base) * pkt->pts;
            
            avcodec_decode_subtitle2(is->subtitle_st->codec, &sp->sub,
                                     &got_subtitle, pkt);
            
            if (got_subtitle && sp->sub.format == 0) {
                sp->pts = pts;                
                
                /* now we can update the picture count */
                if (++is->subpq_windex == SUBPICTURE_QUEUE_SIZE)
                    is->subpq_windex = 0;
                pthread_mutex_lock(&is->subpq_mutex);
                is->subpq_size++;
                pthread_mutex_unlock(&is->subpq_mutex);
            }
            av_free_packet(pkt);
        }
        return 0;
    }
}

/* copy samples for viewing in editor window */
static void update_sample_display(VideoState *is, short *samples, int samples_size)
{
    int size, len;
    
    size = samples_size / sizeof(short);
    while (size > 0) {
        len = SAMPLE_ARRAY_SIZE - is->sample_array_index;
        if (len > size)
            len = size;
        memcpy(is->sample_array + is->sample_array_index, samples, len * sizeof(short));
        samples += len;
        is->sample_array_index += len;
        if (is->sample_array_index >= SAMPLE_ARRAY_SIZE)
            is->sample_array_index = 0;
        size -= len;
    }
}

/* return the wanted number of samples to get better sync if sync_type is video
 * or external master clock */
static int synchronize_audio(VideoState *is, int nb_samples)
{
    int wanted_nb_samples = nb_samples;
    
    /* if not master, then we try to remove or add samples to correct the clock */
    if (((is->av_sync_type == AV_SYNC_VIDEO_MASTER && is->video_st) ||
         is->av_sync_type == AV_SYNC_EXTERNAL_CLOCK)) {
        double diff, avg_diff;
        int min_nb_samples, max_nb_samples;
        
        diff = get_audio_clock(is) - get_master_clock(is);
        
        if (diff < AV_NOSYNC_THRESHOLD) {
            is->audio_diff_cum = diff + is->audio_diff_avg_coef * is->audio_diff_cum;
            if (is->audio_diff_avg_count < AUDIO_DIFF_AVG_NB) {
                /* not enough measures to have a correct estimate */
                is->audio_diff_avg_count++;
            } else {
                /* estimate the A-V difference */
                avg_diff = is->audio_diff_cum * (1.0 - is->audio_diff_avg_coef);
                
                if (fabs(avg_diff) >= is->audio_diff_threshold) {
                    wanted_nb_samples = nb_samples + (int)(diff * is->audio_src_freq);
                    min_nb_samples = ((nb_samples * (100 - SAMPLE_CORRECTION_PERCENT_MAX) / 100));
                    max_nb_samples = ((nb_samples * (100 + SAMPLE_CORRECTION_PERCENT_MAX) / 100));
                    wanted_nb_samples = FFMIN(FFMAX(wanted_nb_samples, min_nb_samples), max_nb_samples);
                }
                av_dlog(NULL, "diff=%f adiff=%f sample_diff=%d apts=%0.3f vpts=%0.3f %f\n",
                        diff, avg_diff, wanted_nb_samples - nb_samples,
                        is->audio_clock, is->video_clock, is->audio_diff_threshold);
            }
        } else {
            /* too big difference : may be initial PTS errors, so
             reset A-V filter */
            is->audio_diff_avg_count = 0;
            is->audio_diff_cum       = 0;
        }
    }
    
    return wanted_nb_samples;
}

/* decode one audio frame and returns its uncompressed size */
static int audio_decode_frame(VideoState *is, double *pts_ptr)
{
    AVPacket *pkt_temp = &is->audio_pkt_temp;
    AVPacket *pkt = &is->audio_pkt;
    AVCodecContext *dec = is->audio_st->codec;
    int len1, len2, data_size, resampled_data_size;
    int64_t dec_channel_layout;
    int got_frame;
    double pts;
    int new_packet = 0;
    int flush_complete = 0;
    int wanted_nb_samples;
    
    for (;;) {
        /* NOTE: the audio packet can contain several frames */
        while (pkt_temp->size > 0 || (!pkt_temp->data && new_packet)) {
            if (!is->frame) {
                if (!(is->frame = avcodec_alloc_frame()))
                    return AVERROR(ENOMEM);
            } else
                avcodec_get_frame_defaults(is->frame);
            
            if (flush_complete)
                break;
            new_packet = 0;
            len1 = avcodec_decode_audio4(dec, is->frame, &got_frame, pkt_temp);
            if (len1 < 0) {
                /* if error, we skip the frame */
                pkt_temp->size = 0;
                break;
            }
            
            pkt_temp->data += len1;
            pkt_temp->size -= len1;
            
            if (!got_frame) {
                /* stop sending empty packets if the decoder is finished */
                if (!pkt_temp->data && dec->codec->capabilities & CODEC_CAP_DELAY)
                    flush_complete = 1;
                continue;
            }
            data_size = av_samples_get_buffer_size(NULL, dec->channels,
                                                   is->frame->nb_samples,
                                                   dec->sample_fmt, 1);
            
            dec_channel_layout = (dec->channel_layout && dec->channels == av_get_channel_layout_nb_channels(dec->channel_layout)) ? dec->channel_layout : av_get_default_channel_layout(dec->channels);
            wanted_nb_samples = synchronize_audio(is, is->frame->nb_samples);
            
            if (dec->sample_fmt != is->audio_src_fmt ||
                dec_channel_layout != is->audio_src_channel_layout ||
                dec->sample_rate != is->audio_src_freq ||
                (wanted_nb_samples != is->frame->nb_samples && !is->swr_ctx)) {
                if (is->swr_ctx)
                    swr_free(&is->swr_ctx);
                is->swr_ctx = swr_alloc_set_opts(NULL,
                                                 is->audio_tgt_channel_layout, is->audio_tgt_fmt, is->audio_tgt_freq,
                                                 dec_channel_layout,           dec->sample_fmt,   dec->sample_rate,
                                                 0, NULL);
                if (!is->swr_ctx || swr_init(is->swr_ctx) < 0) {
                    fprintf(stderr, "Cannot create sample rate converter for conversion of %d Hz %s %d channels to %d Hz %s %d channels!\n",
                            dec->sample_rate,
                            av_get_sample_fmt_name(dec->sample_fmt),
                            dec->channels,
                            is->audio_tgt_freq,
                            av_get_sample_fmt_name(is->audio_tgt_fmt),
                            is->audio_tgt_channels);
                    break;
                }
                is->audio_src_channel_layout = dec_channel_layout;
                is->audio_src_channels = dec->channels;
                is->audio_src_freq = dec->sample_rate;
                is->audio_src_fmt = dec->sample_fmt;
            }
            
            resampled_data_size = data_size;
            if (is->swr_ctx) {
                const uint8_t *in[] = { is->frame->data[0] };
                uint8_t *out[] = {is->audio_buf2};
                if (wanted_nb_samples != is->frame->nb_samples) {
                    if (swr_set_compensation(is->swr_ctx, (wanted_nb_samples - is->frame->nb_samples) * is->audio_tgt_freq / dec->sample_rate,
                                             wanted_nb_samples * is->audio_tgt_freq / dec->sample_rate) < 0) {
                        fprintf(stderr, "swr_set_compensation() failed\n");
                        break;
                    }
                }
                len2 = swr_convert(is->swr_ctx, out, sizeof(is->audio_buf2) / is->audio_tgt_channels / av_get_bytes_per_sample(is->audio_tgt_fmt),
                                   in, is->frame->nb_samples);
                if (len2 < 0) {
                    fprintf(stderr, "audio_resample() failed\n");
                    break;
                }
                if (len2 == sizeof(is->audio_buf2) / is->audio_tgt_channels / av_get_bytes_per_sample(is->audio_tgt_fmt)) {
                    fprintf(stderr, "warning: audio buffer is probably too small\n");
                    swr_init(is->swr_ctx);
                }
                is->audio_buf = is->audio_buf2;
                resampled_data_size = len2 * is->audio_tgt_channels * av_get_bytes_per_sample(is->audio_tgt_fmt);
            } else {
                is->audio_buf = is->frame->data[0];
            }
            
            /* if no pts, then compute it */
            pts = is->audio_clock;
            *pts_ptr = pts;
            is->audio_clock += (double)data_size /
            (dec->channels * dec->sample_rate * av_get_bytes_per_sample(dec->sample_fmt));
            return resampled_data_size;
        }
        
        /* free the current packet */
        if (pkt->data)
            av_free_packet(pkt);
        memset(pkt_temp, 0, sizeof(*pkt_temp));
        
        if (is->paused || is->audioq.abort_request) {
            return -1;
        }
        
        /* read next packet */
        if ((new_packet = packet_queue_get(&is->audioq, pkt, 1)) < 0)
            return -1;
        
        if (pkt->data == flush_pkt.data) {
            avcodec_flush_buffers(dec);
            
            flush_complete = 0;
        }
        
        *pkt_temp = *pkt;
        
        /* if update the audio clock with the pts */
        if (pkt->pts != AV_NOPTS_VALUE) {
            is->audio_clock = av_q2d(is->audio_st->time_base)*pkt->pts;
        }
    }
}

/* prepare a new audio buffer */
static void ffmpeg_audio_queue_callback(void *opaque,
                                        AudioQueueRef outQ,
                                        AudioQueueBufferRef outQB)
{
    @autoreleasepool {
        outQB->mAudioDataByteSize = in.mDataFormat.mBytesPerFrame * in.frameCount;
        int len = outQB->mAudioDataByteSize;
        uint8_t *stream = outQB->mAudioData;

        VideoState *is = opaque;
        int audio_size, len1;
        int bytes_per_sec;
        int frame_size = av_samples_get_buffer_size(NULL, is->audio_tgt_channels, 1, is->audio_tgt_fmt, 1);
        double pts;
        
        audio_callback_time = av_gettime();
        
        while (len > 0) {
            if (is->audio_buf_index >= is->audio_buf_size) {
                audio_size = audio_decode_frame(is, &pts);
                if (audio_size < 0) {
                    /* if error, just output silence */
                    is->audio_buf      = is->silence_buf;
                    is->audio_buf_size = sizeof(is->silence_buf) / frame_size * frame_size;
//                    fprintf(stderr, "silence\n");
                } else {
                    if (is->show_mode != SHOW_MODE_VIDEO)
                        update_sample_display(is, (int16_t *)is->audio_buf, audio_size);
                    is->audio_buf_size = audio_size;
                }
                is->audio_buf_index = 0;
            }
            len1 = is->audio_buf_size - is->audio_buf_index;
            if (len1 > len)
                len1 = len;
/*            do {
                FILE *fp = fopen([path_in_docs(@"test.raw") UTF8String], "a");
                if (fp) {
                    fwrite((uint8_t *)is->audio_buf + is->audio_buf_index, len1, 1, fp);
                    fclose(fp);
                }
            } while (0);*/
            memcpy(stream, (uint8_t *)is->audio_buf + is->audio_buf_index, len1);
            len -= len1;
            stream += len1;
            is->audio_buf_index += len1;
        }
        bytes_per_sec = is->audio_tgt_freq * is->audio_tgt_channels * av_get_bytes_per_sample(is->audio_tgt_fmt);
        is->audio_write_buf_size = is->audio_buf_size - is->audio_buf_index;
        /* Let's assume the audio driver that is used by SDL has two periods. */
        is->audio_current_pts = is->audio_clock - (double)(2 * is->audio_hw_buf_size + is->audio_write_buf_size) / bytes_per_sec;
        is->audio_current_pts_drift = is->audio_current_pts - audio_callback_time / 1000000.0;
    }
    
    AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
}

/* open a given stream. Return 0 if OK */
static int stream_component_open(VideoState *is, int stream_index)
{
    AVFormatContext *ic = is->ic;
    AVCodecContext *avctx;
    AVCodec *codec;
    int64_t wanted_channel_layout = 0;
    int wanted_nb_channels;
    int wanted_spec_channels = 0;
    int wanted_spec_freq = 0;
    
    if (stream_index < 0 || stream_index >= ic->nb_streams)
        return -1;
    avctx = ic->streams[stream_index]->codec;
    
    codec = avcodec_find_decoder(avctx->codec_id);
    
    switch(avctx->codec_type){
        case AVMEDIA_TYPE_AUDIO   : is->last_audio_stream    = stream_index; if(audio_codec_name   ) codec= avcodec_find_decoder_by_name(   audio_codec_name); break;
        case AVMEDIA_TYPE_SUBTITLE: is->last_subtitle_stream = stream_index; if(subtitle_codec_name) codec= avcodec_find_decoder_by_name(subtitle_codec_name); break;
        case AVMEDIA_TYPE_VIDEO   : is->last_video_stream    = stream_index; if(video_codec_name   ) codec= avcodec_find_decoder_by_name(   video_codec_name); break;
    }
    if (!codec)
        return -1;
    
    avctx->workaround_bugs   = workaround_bugs;
    avctx->lowres            = lowres;
    if(avctx->lowres > codec->max_lowres){
        av_log(avctx, AV_LOG_WARNING, "The maximum value for lowres supported by the decoder is %d\n",
               codec->max_lowres);
        avctx->lowres= codec->max_lowres;
    }
    avctx->idct_algo         = idct;
    avctx->skip_frame        = skip_frame;
    avctx->skip_idct         = skip_idct;
    avctx->skip_loop_filter  = skip_loop_filter;
    avctx->error_concealment = error_concealment;
    
    if(avctx->lowres) avctx->flags |= CODEC_FLAG_EMU_EDGE;
    if (fast)   avctx->flags2 |= CODEC_FLAG2_FAST;
    if(codec->capabilities & CODEC_CAP_DR1)
        avctx->flags |= CODEC_FLAG_EMU_EDGE;
    
    if (avctx->codec_type == AVMEDIA_TYPE_AUDIO) {
        memset(&is->audio_pkt_temp, 0, sizeof(is->audio_pkt_temp));
        if (!wanted_channel_layout) {
            wanted_channel_layout = (avctx->channel_layout && avctx->channels == av_get_channel_layout_nb_channels(avctx->channel_layout)) ? avctx->channel_layout : av_get_default_channel_layout(avctx->channels);
            wanted_channel_layout &= ~AV_CH_LAYOUT_STEREO_DOWNMIX;
            wanted_nb_channels = av_get_channel_layout_nb_channels(wanted_channel_layout);
            /* SDL only supports 1, 2, 4 or 6 channels at the moment, so we have to make sure not to request anything else. */
            while (wanted_nb_channels > 0 && (wanted_nb_channels == 3 || wanted_nb_channels == 5 || wanted_nb_channels > 6)) {
                wanted_nb_channels--;
                wanted_channel_layout = av_get_default_channel_layout(wanted_nb_channels);
            }
        }
        
        wanted_spec_channels = av_get_channel_layout_nb_channels(wanted_channel_layout);
        wanted_spec_freq = avctx->sample_rate;
        if (wanted_spec_freq <= 0 || wanted_spec_channels <= 0) {
            fprintf(stderr, "Invalid sample rate or channel count!\n");
            return -1;
        }
        fprintf(stderr, "wanted_spec_freq %d wanted_spec_channels %d\n", wanted_spec_freq, wanted_spec_channels);
    }
    
//    if (!av_dict_get(opts, "threads", NULL, 0))
//        av_dict_set(&opts, "threads", "auto", 0);
    if (!codec ||
        avcodec_open2(avctx, codec, NULL) < 0)
        return -1;
//    if ((t = av_dict_get(opts, "", NULL, AV_DICT_IGNORE_SUFFIX))) {
//        av_log(NULL, AV_LOG_ERROR, "Option %s not found.\n", t->key);
//        return AVERROR_OPTION_NOT_FOUND;
//    }
    
    /* prepare audio output */
    if (avctx->codec_type == AVMEDIA_TYPE_AUDIO) {
        is->audio_hw_buf_size = 2*wanted_spec_channels*SDL_AUDIO_BUFFER_SIZE;
        is->audio_src_fmt = is->audio_tgt_fmt = AV_SAMPLE_FMT_S16;
        is->audio_src_freq = is->audio_tgt_freq = wanted_spec_freq;
        is->audio_src_channel_layout = is->audio_tgt_channel_layout = wanted_channel_layout;
        is->audio_src_channels = is->audio_tgt_channels = wanted_spec_channels;
    }
    
    ic->streams[stream_index]->discard = AVDISCARD_DEFAULT;
    switch (avctx->codec_type) {
        case AVMEDIA_TYPE_AUDIO:
            ffmpeg_audio_close();
            is->audio_stream = stream_index;
            is->audio_st = ic->streams[stream_index];
            is->audio_buf_size  = 0;
            is->audio_buf_index = 0;
            
            /* init averaging filter */
            is->audio_diff_avg_coef  = exp(log(0.01) / AUDIO_DIFF_AVG_NB);
            is->audio_diff_avg_count = 0;
            /* since we do not have a precise anough audio fifo fullness,
             we correct audio sync only if larger than this threshold */
            is->audio_diff_threshold = 2.0 * SDL_AUDIO_BUFFER_SIZE / wanted_spec_freq;
            
            memset(&is->audio_pkt, 0, sizeof(is->audio_pkt));
            packet_queue_start(&is->audioq);
            NSLog(@"ffmpeg_audio_open %d %d", wanted_spec_freq, wanted_spec_channels);
            ffmpeg_audio_open(wanted_spec_freq, wanted_spec_channels, is);
            break;
        case AVMEDIA_TYPE_VIDEO:
            is->video_stream = stream_index;
            is->video_st = ic->streams[stream_index];
            
            packet_queue_start(&is->videoq);
            pthread_create(&is->video_tid, NULL, video_thread, is);
            break;
        case AVMEDIA_TYPE_SUBTITLE:
            is->subtitle_stream = stream_index;
            is->subtitle_st = ic->streams[stream_index];
            packet_queue_start(&is->subtitleq);
            
            pthread_create(&is->subtitle_tid, NULL, subtitle_thread, is);
            break;
        default:
            break;
    }
    return 0;
}

static void stream_component_close(VideoState *is, int stream_index)
{
    AVFormatContext *ic = is->ic;
    AVCodecContext *avctx;
    
    if (stream_index < 0 || stream_index >= ic->nb_streams)
        return;
    avctx = ic->streams[stream_index]->codec;
    
    switch (avctx->codec_type) {
        case AVMEDIA_TYPE_AUDIO:
            packet_queue_abort(&is->audioq);
            
            ffmpeg_audio_close();
            
            packet_queue_flush(&is->audioq);
            av_free_packet(&is->audio_pkt);
            if (is->swr_ctx)
                swr_free(&is->swr_ctx);
            av_freep(&is->audio_buf1);
            is->audio_buf = NULL;
            av_freep(&is->frame);
            
            if (is->rdft) {
                av_rdft_end(is->rdft);
                av_freep(&is->rdft_data);
                is->rdft = NULL;
                is->rdft_bits = 0;
            }
            break;
        case AVMEDIA_TYPE_VIDEO:
            packet_queue_abort(&is->videoq);
            
            /* note: we also signal this mutex to make sure we deblock the
             video thread in all cases */
            pthread_mutex_lock(&is->pictq_mutex);
            pthread_cond_signal(&is->pictq_cond);
            pthread_mutex_unlock(&is->pictq_mutex);
            
            pthread_join(is->video_tid, NULL);
            
            packet_queue_flush(&is->videoq);
            break;
        case AVMEDIA_TYPE_SUBTITLE:
            packet_queue_abort(&is->subtitleq);
            
            /* note: we also signal this mutex to make sure we deblock the
             video thread in all cases */
            pthread_mutex_lock(&is->subpq_mutex);
            is->subtitle_stream_changed = 1;
            
            pthread_cond_signal(&is->subpq_cond);
            pthread_mutex_unlock(&is->subpq_mutex);
            
            pthread_join(is->subtitle_tid, NULL);
            
            packet_queue_flush(&is->subtitleq);
            break;
        default:
            break;
    }
    
    ic->streams[stream_index]->discard = AVDISCARD_ALL;
    avcodec_close(avctx);
    switch (avctx->codec_type) {
        case AVMEDIA_TYPE_AUDIO:
            is->audio_st = NULL;
            is->audio_stream = -1;
            break;
        case AVMEDIA_TYPE_VIDEO:
            is->video_st = NULL;
            is->video_stream = -1;
            break;
        case AVMEDIA_TYPE_SUBTITLE:
            is->subtitle_st = NULL;
            is->subtitle_stream = -1;
            break;
        default:
            break;
    }
}

static int decode_interrupt_cb(void *ctx)
{
    VideoState *is = ctx;
    return is->abort_request;
}

/* this thread gets the stream from the disk or the network */
static int read_thread(void *arg)
{
    @autoreleasepool {
        VideoState *is = arg;
        AVFormatContext *ic = NULL;
        int err, i, ret;
        int st_index[AVMEDIA_TYPE_NB];
        AVPacket pkt1, *pkt = &pkt1;
        int eof = 0;
        int pkt_in_play_range = 0;
        
        memset(st_index, -1, sizeof(st_index));
        is->last_video_stream = is->video_stream = -1;
        is->last_audio_stream = is->audio_stream = -1;
        is->last_subtitle_stream = is->subtitle_stream = -1;
        
        ic = avformat_alloc_context();
        ic->interrupt_callback.callback = decode_interrupt_cb;
        ic->interrupt_callback.opaque = is;
        err = avformat_open_input(&ic, is->filename, is->iformat, NULL);
        if (err < 0) {
            av_log(NULL, AV_LOG_ERROR, "avformat_open_input %s failed", is->filename);
            ret = -1;
            goto fail;
        }
        is->ic = ic;
        
        if (genpts)
            ic->flags |= AVFMT_FLAG_GENPTS;
            
        err = avformat_find_stream_info(ic, NULL);
        if (err < 0) {
            fprintf(stderr, "%s: could not find codec parameters\n", is->filename);
            ret = -1;
            goto fail;
        }
        
        if (ic->pb)
            ic->pb->eof_reached = 0; // FIXME hack, ffplay maybe should not use url_feof() to test for the end
        
        if (seek_by_bytes < 0)
            seek_by_bytes = !!(ic->iformat->flags & AVFMT_TS_DISCONT);
        
        /* if seeking requested, we execute it */
        if (start_time != AV_NOPTS_VALUE) {
            int64_t timestamp;
            
            timestamp = start_time;
            /* add the stream start time */
            if (ic->start_time != AV_NOPTS_VALUE)
                timestamp += ic->start_time;
            ret = avformat_seek_file(ic, -1, INT64_MIN, timestamp, INT64_MAX, 0);
            if (ret < 0) {
                fprintf(stderr, "%s: could not seek to position %0.3f\n",
                        is->filename, (double)timestamp / AV_TIME_BASE);
            }
        }
        
        for (i = 0; i < ic->nb_streams; i++)
            ic->streams[i]->discard = AVDISCARD_ALL;
            st_index[AVMEDIA_TYPE_VIDEO] =
            av_find_best_stream(ic, AVMEDIA_TYPE_VIDEO,
                                wanted_stream[AVMEDIA_TYPE_VIDEO], -1, NULL, 0);
            st_index[AVMEDIA_TYPE_AUDIO] =
            av_find_best_stream(ic, AVMEDIA_TYPE_AUDIO,
                                wanted_stream[AVMEDIA_TYPE_AUDIO],
                                st_index[AVMEDIA_TYPE_VIDEO],
                                NULL, 0);
            st_index[AVMEDIA_TYPE_SUBTITLE] =
            av_find_best_stream(ic, AVMEDIA_TYPE_SUBTITLE,
                                wanted_stream[AVMEDIA_TYPE_SUBTITLE],
                                (st_index[AVMEDIA_TYPE_AUDIO] >= 0 ?
                                 st_index[AVMEDIA_TYPE_AUDIO] :
                                 st_index[AVMEDIA_TYPE_VIDEO]),
                                NULL, 0);
        if (show_status) {
            av_dump_format(ic, 0, is->filename, 0);
        }
        
        is->show_mode = show_mode;
        
        /* open the streams */
        if (st_index[AVMEDIA_TYPE_AUDIO] >= 0) {
            stream_component_open(is, st_index[AVMEDIA_TYPE_AUDIO]);
        }
        
        ret = -1;
        if (st_index[AVMEDIA_TYPE_VIDEO] >= 0) {
            ret = stream_component_open(is, st_index[AVMEDIA_TYPE_VIDEO]);
        }
        if (is->show_mode == SHOW_MODE_NONE)
            is->show_mode = ret >= 0 ? SHOW_MODE_VIDEO : SHOW_MODE_RDFT;
        
        if (st_index[AVMEDIA_TYPE_SUBTITLE] >= 0) {
            stream_component_open(is, st_index[AVMEDIA_TYPE_SUBTITLE]);
        }
        
        if (is->video_stream < 0 && is->audio_stream < 0) {
            fprintf(stderr, "%s: could not open codecs\n", is->filename);
            ret = -1;
            goto fail;
        }
        
        for (;;) {
            if (is->abort_request)
                break;
            if (is->paused != is->last_paused) {
                is->last_paused = is->paused;
                if (is->paused)
                    is->read_pause_return = av_read_pause(ic);
                else
                    av_read_play(ic);
            }
    #if CONFIG_RTSP_DEMUXER || CONFIG_MMSH_PROTOCOL
            if (is->paused &&
                (!strcmp(ic->iformat->name, "rtsp") ||
                 (ic->pb && !strncmp(input_filename, "mmsh:", 5)))) {
                    /* wait 10 ms to avoid trying to get another packet */
                    /* XXX: horrible */
                    ffmpeg_delay(10);
                    continue;
                }
    #endif
            if (is->seek_req) {
                int64_t seek_target = is->seek_pos;
                int64_t seek_min    = is->seek_rel > 0 ? seek_target - is->seek_rel + 2: INT64_MIN;
                int64_t seek_max    = is->seek_rel < 0 ? seek_target - is->seek_rel - 2: INT64_MAX;
                // FIXME the +-2 is due to rounding being not done in the correct direction in generation
                //      of the seek_pos/seek_rel variables
                
                ret = avformat_seek_file(is->ic, -1, seek_min, seek_target, seek_max, is->seek_flags);
                if (ret < 0) {
                    fprintf(stderr, "%s: error while seeking\n", is->ic->filename);
                } else {
                    if (is->audio_stream >= 0) {
                        packet_queue_flush(&is->audioq);
                        packet_queue_put(&is->audioq, &flush_pkt);
                    }
                    if (is->subtitle_stream >= 0) {
                        packet_queue_flush(&is->subtitleq);
                        packet_queue_put(&is->subtitleq, &flush_pkt);
                    }
                    if (is->video_stream >= 0) {
                        packet_queue_flush(&is->videoq);
                        packet_queue_put(&is->videoq, &flush_pkt);
                    }
                }
                is->seek_req = 0;
                eof = 0;
            }
            
            /* if the queue are full, no need to read more */
            if (   is->audioq.size + is->videoq.size + is->subtitleq.size > MAX_QUEUE_SIZE
                || (   (is->audioq   .nb_packets > MIN_FRAMES || is->audio_stream < 0 || is->audioq.abort_request)
                    && (is->videoq   .nb_packets > MIN_FRAMES || is->video_stream < 0 || is->videoq.abort_request)
                    && (is->subtitleq.nb_packets > MIN_FRAMES || is->subtitle_stream < 0 || is->subtitleq.abort_request))) {
                    /* wait 10 ms */
                    ffmpeg_delay(10);
                    continue;
                }
            if (eof) {
                if (is->video_stream >= 0) {
                    av_init_packet(pkt);
                    pkt->data = NULL;
                    pkt->size = 0;
                    pkt->stream_index = is->video_stream;
                    packet_queue_put(&is->videoq, pkt);
                }
                if (is->audio_stream >= 0 &&
                    is->audio_st->codec->codec->capabilities & CODEC_CAP_DELAY) {
                    av_init_packet(pkt);
                    pkt->data = NULL;
                    pkt->size = 0;
                    pkt->stream_index = is->audio_stream;
                    packet_queue_put(&is->audioq, pkt);
                }
                ffmpeg_delay(10);
                if (is->audioq.size + is->videoq.size + is->subtitleq.size == 0) {
                    if (loop != 1 && (!loop || --loop)) {
                        stream_seek(is, start_time != AV_NOPTS_VALUE ? start_time : 0, 0, 0);
                    } else if (autoexit) {
                        ret = AVERROR_EOF;
                        goto fail;
                    }
                }
                eof=0;
                continue;
            }
            ret = av_read_frame(ic, pkt);
            if (ret < 0) {
                if (ret == AVERROR_EOF || url_feof(ic->pb))
                    eof = 1;
                if (ic->pb && ic->pb->error)
                    break;
                ffmpeg_delay(100); /* wait for user event */
                continue;
            }
            /* check if packet is in play range specified by user, then queue, otherwise discard */
            pkt_in_play_range = duration == AV_NOPTS_VALUE ||
            (pkt->pts - ic->streams[pkt->stream_index]->start_time) *
            av_q2d(ic->streams[pkt->stream_index]->time_base) -
            (double)(start_time != AV_NOPTS_VALUE ? start_time : 0) / 1000000
            <= ((double)duration / 1000000);
            if (pkt->stream_index == is->audio_stream && pkt_in_play_range) {
                packet_queue_put(&is->audioq, pkt);
            } else if (pkt->stream_index == is->video_stream && pkt_in_play_range) {
                packet_queue_put(&is->videoq, pkt);
            } else if (pkt->stream_index == is->subtitle_stream && pkt_in_play_range) {
                packet_queue_put(&is->subtitleq, pkt);
            } else {
                av_free_packet(pkt);
            }
        }
        /* wait until the end */
        while (!is->abort_request) {
            ffmpeg_delay(100);
        }
        
        ret = 0;
    fail:
        /* close each stream */
        if (is->audio_stream >= 0)
            stream_component_close(is, is->audio_stream);
        if (is->video_stream >= 0)
            stream_component_close(is, is->video_stream);
        if (is->subtitle_stream >= 0)
            stream_component_close(is, is->subtitle_stream);
        if (is->ic) {
            avformat_close_input(&is->ic);
        }
     
        if (ret != 0) {
            [is->view performSelectorOnMainThread:@selector(quitEvent:) withObject:nil waitUntilDone:YES];
        }
        return 0;
    }
}

static VideoState *stream_open(const char *filename, AVInputFormat *iformat, UIView *view)
{
    VideoState *is;
    
    is = av_mallocz(sizeof(VideoState));
    if (!is)
        return NULL;
    is->view = view;
    for(int i=0; i<VIDEO_PICTURE_QUEUE_SIZE; i++) {
        pthread_mutex_init(&is->pictq[i].bmp_mutex, NULL);
    }
    
    av_strlcpy(is->filename, filename, sizeof(is->filename));
    is->iformat = iformat;
    is->ytop    = 0;
    is->xleft   = 0;
    
    /* start video display */
    pthread_mutex_init(&is->pictq_mutex, NULL);
    pthread_cond_init(&is->pictq_cond, NULL);
    
    pthread_mutex_init(&is->subpq_mutex, NULL);
    pthread_cond_init(&is->subpq_cond, NULL);
    
    packet_queue_init(&is->videoq);
    packet_queue_init(&is->audioq);
    packet_queue_init(&is->subtitleq);
    
    is->av_sync_type = AV_SYNC_AUDIO_MASTER;
    if (pthread_create(&is->read_tid, NULL, read_thread, is) != 0) {
        av_free(is);
        return NULL;
    }
    return is;
}

static int lockmgr(void **mtx, enum AVLockOp op)
{
    switch(op) {
        case AV_LOCK_CREATE:
            if (pthread_mutex_init(mtx, NULL) != 0)
                return 1;
            return 0;
        case AV_LOCK_OBTAIN:
            if (pthread_mutex_lock(mtx) != 0)
                return 1;
            return 0;
        case AV_LOCK_RELEASE:
            if (pthread_mutex_unlock(mtx) != 0)
                return 1;
            return 0;
        case AV_LOCK_DESTROY:
            pthread_mutex_destroy(mtx);
            return 0;
    }
    return 1;
}

@interface FFMpegScreenView : UIView
{
    VideoState *_is;
    CGSize _videoSize;
}
@end

@implementation FFMpegScreenView

- (id)initWithFrame:(CGRect)r
{
    static BOOL is_initialized = NO;
    self = [super initWithFrame:r];
    if (self) {
        if (!is_initialized) {
            avcodec_register_all();
            av_register_all();
            avformat_network_init();
            
            if (av_lockmgr_register(lockmgr)) {
                avformat_network_deinit();
                [NSException raise:@"FFMpeg" format:@"Could not initialize lock manager!"];
            }
            
            av_init_packet(&flush_pkt);
            flush_pkt.data = (uint8_t *)"FLUSH";
            is_initialized = YES;
        }

    }
    return self;
}

- (void)fitToSuperview
{
    CGRect r = self.superview.frame;
    if (_videoSize.width && _videoSize.height) {
        CGSize s = proportional_size(r.size.width, r.size.height, _videoSize.width, _videoSize.height);
        self.frame = center_rect_in_size(CGRectMake(0.0, 0.0, s.width, s.height), r.size);
    }
}

- (void)stop
{
    if (_is) {
        stream_close(_is);
        _is = NULL;
    }
}

- (void)play:(NSString *)str
{
    static char input_filename[1024];
    [str getCString:input_filename maxLength:1024 encoding:NSUTF8StringEncoding];

    _is = stream_open(input_filename, NULL, self);
    if (!_is) {
        fprintf(stderr, "Failed to initialize VideoState!\n");
        return;
    }
}

- (void)quitEvent:(id)obj
{
}

void ffmpeg_cleanup_pixbuf(void *releaseInfo, void *data)
{
    if (releaseInfo != data) {
        fprintf(stderr, "cleanup_pixbuf: releaseInfo != data\n");
    } else {
        fprintf(stderr, "cleanup_pixbuf: releaseInfo == data\n");
    }
    av_free(data);
    fprintf(stderr, "cleanup_pixbuf: freed\n");
}

- (void)allocEvent:(id)obj
{
    AVFrame *frame = [(NSValue *)obj pointerValue];

    /* allocate a picture (needs to do that in main thread to avoid
     potential locking problems */
    VideoPicture *vp;
    
    vp = &_is->pictq[_is->pictq_windex];
    
    pthread_mutex_lock(&vp->bmp_mutex);
    
    if (vp->bmp)
        CFRelease(vp->bmp);
    
    
    vp->width   = frame->width;
    vp->height  = frame->height;
    vp->pix_fmt = frame->format;
    
    video_open(_is, 0);
    
    void *pixbuf = av_malloc(vp->width*vp->height*4);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
    vp->bmp = CGBitmapContextCreateWithData(pixbuf,
                                            vp->width,
                                            vp->height,
                                            8,
                                            vp->width*4,
                                            colorSpace,
                                            kCGImageAlphaPremultipliedLast,
                                            ffmpeg_cleanup_pixbuf,
                                            pixbuf);
    CFRelease(colorSpace);
    
    pthread_mutex_unlock(&vp->bmp_mutex);
    
    if (!vp->bmp) {
        /* SDL allocates a buffer smaller than requested if the video
         * overlay hardware is unable to support the requested size. */
        fprintf(stderr, "Error: the video system does not support an image\n"
                "size of %dx%d pixels. Try using -lowres or -vf \"scale=w:h\"\n"
                "to reduce the image size.\n", vp->width, vp->height );
        stream_close(_is);
        _is = NULL;
        return;
    }
    
    pthread_mutex_lock(&_is->pictq_mutex);
    vp->allocated = 1;
    pthread_cond_signal(&_is->pictq_cond);
    pthread_mutex_unlock(&_is->pictq_mutex);
}

- (void)refreshEvent:(id)obj
{
    if (_is) {
        if (!_is->refresh) {
            _is->refresh = 1;
            video_refresh(_is);
            _is->refresh = 0;
        }
    }
}

- (void)displayEvent:(id)obj
{
    VideoPicture *vp = [obj pointerValue];
    if (!vp->bmp) {
        return;
    }
    
    float aspect_ratio;
    int width, height;
    
    if (vp->sample_aspect_ratio.num == 0)
        aspect_ratio = 0;
    else
        aspect_ratio = av_q2d(vp->sample_aspect_ratio);
    
    if (aspect_ratio <= 0.0)
        aspect_ratio = 1.0;
    aspect_ratio *= (float)vp->width / (float)vp->height;
    
    
    /* XXX: we suppose the screen has a 1.0 pixel ratio */
    height = _is->height;
    width = ((int)rint(height * aspect_ratio)) & ~1;
    if (width > _is->width) {
        width = _is->width;
        height = ((int)rint(width / aspect_ratio)) & ~1;
    }
    width = FFMAX(width, 1);
    height = FFMAX(height, 1);
    if ((width != _videoSize.width) || (height != _videoSize.height)) {
        _videoSize.width = width;
        _videoSize.height = height;
        [self fitToSuperview];
    }

    CGImageRef cgImage = CGBitmapContextCreateImage(vp->bmp);
    self.layer.contents = (id)cgImage;
    CFRelease(cgImage);
    
}

- (void)seekRelative:(double)incr
{
    double pos;
    if (seek_by_bytes) {
        if (_is->video_stream >= 0 && _is->video_current_pos >= 0) {
            pos = _is->video_current_pos;
        } else if (_is->audio_stream >= 0 && _is->audio_pkt.pos >= 0) {
            pos = _is->audio_pkt.pos;
        } else {
            pos = avio_tell(_is->ic->pb);
        }
        if (_is->ic->bit_rate)
            incr *= _is->ic->bit_rate / 8.0;
        else
            incr *= 180000.0;
        pos += incr;
        stream_seek(_is, pos, incr, 1);
    } else {
        pos = get_master_clock(_is);
        pos += incr;
        stream_seek(_is, (int64_t)(pos * AV_TIME_BASE), (int64_t)(incr * AV_TIME_BASE), 0);
    }
}

- (void)seekAbsolute:(double)x
{
    if (!_is)
        return;
    
    if (x < 0.0)
        x = 0.0;
    if (x > 1.0)
        x = 1.0;
    
    if (seek_by_bytes || _is->ic->duration <= 0) {
        uint64_t size =  avio_size(_is->ic->pb);
        stream_seek(_is, size*x, 0, 1);
    } else {
        int64_t ts;
        int ns, hh, mm, ss;
        int tns, thh, tmm, tss;
        tns  = _is->ic->duration / 1000000LL;
        thh  = tns / 3600;
        tmm  = (tns % 3600) / 60;
        tss  = (tns % 60);
        ns   = x * tns;
        hh   = ns / 3600;
        mm   = (ns % 3600) / 60;
        ss   = (ns % 60);
        fprintf(stderr, "Seek to %2.0f%% (%2d:%02d:%02d) of total duration (%2d:%02d:%02d)\n", x*100, hh, mm, ss, thh, tmm, tss);
        ts = x * _is->ic->duration;
        if (_is->ic->start_time != AV_NOPTS_VALUE)
            ts += _is->ic->start_time;
        stream_seek(_is, ts, 0, 0);
    }
}

@end

@interface FFMpegView : UIView
@property (nonatomic, retain) CADisplayLink *displayLink;
@property (nonatomic, retain) FFMpegScreenView *screenView;
@end

@implementation FFMpegView
@synthesize displayLink = _displayLink;
@synthesize screenView = _screenView;

- (void)dealloc
{
    [self stop];
    [self.displayLink invalidate];
    self.displayLink = nil;
    [self.screenView removeFromSuperview];
    self.screenView = nil;
    [super dealloc];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = YES;
        self.exclusiveTouch = NO;
        self.screenView = [[[FFMpegScreenView alloc] initWithFrame:CGRectZero] autorelease];
        self.screenView.userInteractionEnabled = NO;
        self.screenView.clearsContextBeforeDrawing = NO;
        [self addSubview:self.screenView];
        [self.screenView fitToSuperview];
        self.displayLink = [CADisplayLink displayLinkWithTarget:self.screenView selector:@selector(refreshEvent:)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (void)layoutSubviews
{
    [self.screenView fitToSuperview];
}

- (void)stop { [self.screenView stop]; }
- (void)play:(NSString *)str
{
    [self.screenView stop];
    [self.screenView play:str];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGFloat dx = 0.0;
    for (UITouch *t in touches.allObjects) {
        if (t.phase == UITouchPhaseMoved) {
            CGPoint p = [t locationInView:self];
            CGPoint pp = [t previousLocationInView:self];
            dx += p.x - pp.x;
        }
    }
    NSLog(@"touchesMoved dx %f", dx);
    if (dx) {
        [self.screenView seekRelative:dx/100.0];
    }
}

@end

