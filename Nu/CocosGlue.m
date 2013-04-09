//
//  CocosGlue.m
//  Nu
//
//  Created by arthur on 26/02/13.
//
//

#import <QuartzCore/QuartzCore.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>


#import "Nu.h"

#import "cocos2d.h"

@implementation CCLayer(Nu)

- (void)update:(ccTime)delta
{
    id block = [self valueForIvar:@"update:"];
    if (block) {
        execute_block_safely(^(void) { return [block evalWithArguments:nulist([NSNumber numberWithFloat:delta], nil)]; });
        return;
    }
}
@end

@interface CCParticleSystemQuad(Nu)
@property (nonatomic) CGFloat positionX;
@property (nonatomic) CGFloat positionY;
@property (nonatomic) CGFloat posVarX;
@property (nonatomic) CGFloat posVarY;
@property (nonatomic) GLfloat startColorRed;
@property (nonatomic) GLfloat startColorGreen;
@property (nonatomic) GLfloat startColorBlue;
@property (nonatomic) GLfloat startColorAlpha;
@property (nonatomic) GLfloat startColorVarRed;
@property (nonatomic) GLfloat startColorVarGreen;
@property (nonatomic) GLfloat startColorVarBlue;
@property (nonatomic) GLfloat startColorVarAlpha;
@property (nonatomic) GLfloat endColorRed;
@property (nonatomic) GLfloat endColorGreen;
@property (nonatomic) GLfloat endColorBlue;
@property (nonatomic) GLfloat endColorAlpha;
@property (nonatomic) GLfloat endColorVarRed;
@property (nonatomic) GLfloat endColorVarGreen;
@property (nonatomic) GLfloat endColorVarBlue;
@property (nonatomic) GLfloat endColorVarAlpha;
@property (nonatomic) CGFloat gravityX;
@property (nonatomic) CGFloat gravityY;
@end

@implementation CCParticleSystemQuad(Nu)

- (void)update:(ccTime)dt
{
    id open_emitter = [[[UIApplication sharedApplication] delegate] valueForIvar:@"open-emitter"];
    if (!nu_valueIsNull(open_emitter)) {
        execute_block_safely(^(void) { return [open_emitter evalWithArguments:nil]; });
        [[[UIApplication sharedApplication] delegate] setValue:nil forIvar:@"open-emitter"];
    }
    if (!_active) {
        if ((_duration > 0) && !_particleCount) {
            [self resetSystem];
        }
        if (_duration == kCCParticleDurationInfinity) {
            [self resetSystem];
        }
    }
    [super update:dt];
}

- (CGFloat)positionX { return _position.x; }
- (CGFloat)positionY { return _position.y; }
- (void)setPositionX:(CGFloat)x { _position.x = x; }
- (void)setPositionY:(CGFloat)y { _position.y = y; }

- (CGFloat)posVarX { return _posVar.x; }
- (CGFloat)posVarY { return _posVar.y; }
- (void)setPosVarX:(CGFloat)x { _posVar.x = x; }
- (void)setPosVarY:(CGFloat)y { _posVar.y = y; }

- (GLfloat)startColorRed { return _startColor.r; }
- (GLfloat)startColorGreen { return _startColor.g; }
- (GLfloat)startColorBlue { return _startColor.b; }
- (GLfloat)startColorAlpha {return _startColor.a; }
- (void)setStartColorRed:(GLfloat)r { _startColor.r = r; }
- (void)setStartColorGreen:(GLfloat)g { _startColor.g = g; }
- (void)setStartColorBlue:(GLfloat)b { _startColor.b = b; }
- (void)setStartColorAlpha:(GLfloat)a { _startColor.a = a; }

- (GLfloat)startColorVarRed { return _startColorVar.r; }
- (GLfloat)startColorVarGreen { return _startColorVar.g; }
- (GLfloat)startColorVarBlue { return _startColorVar.b; }
- (GLfloat)startColorVarAlpha {return _startColorVar.a; }
- (void)setStartColorVarRed:(GLfloat)r { _startColorVar.r = r; }
- (void)setStartColorVarGreen:(GLfloat)g { _startColorVar.g = g; }
- (void)setStartColorVarBlue:(GLfloat)b { _startColorVar.b = b; }
- (void)setStartColorVarAlpha:(GLfloat)a { _startColorVar.a = a; }

- (GLfloat)endColorRed { return _endColor.r; }
- (GLfloat)endColorGreen { return _endColor.g; }
- (GLfloat)endColorBlue { return _endColor.b; }
- (GLfloat)endColorAlpha {return _endColor.a; }
- (void)setEndColorRed:(GLfloat)r { _endColor.r = r; }
- (void)setEndColorGreen:(GLfloat)g { _endColor.g = g; }
- (void)setEndColorBlue:(GLfloat)b { _endColor.b = b; }
- (void)setEndColorAlpha:(GLfloat)a { _endColor.a = a; }

- (GLfloat)endColorVarRed { return _endColorVar.r; }
- (GLfloat)endColorVarGreen { return _endColorVar.g; }
- (GLfloat)endColorVarBlue { return _endColorVar.b; }
- (GLfloat)endColorVarAlpha {return _endColorVar.a; }
- (void)setEndColorVarRed:(GLfloat)r { _endColorVar.r = r; }
- (void)setEndColorVarGreen:(GLfloat)g { _endColorVar.g = g; }
- (void)setEndColorVarBlue:(GLfloat)b { _endColorVar.b = b; }
- (void)setEndColorVarAlpha:(GLfloat)a { _endColorVar.a = a; }

- (CGFloat)gravityX { return _mode.A.gravity.x; }
- (CGFloat)gravityY { return _mode.A.gravity.y; }
- (void)setGravityX:(CGFloat)x { _mode.A.gravity.x = x; }
- (void)setGravityY:(CGFloat)y { _mode.A.gravity.y = y; }

- (GLenum)blendFuncSource { return _blendFunc.src; }
- (GLenum)blendFuncDestination { return _blendFunc.dst; }
- (void)setBlendFuncSource:(GLenum)src { _blendFunc.src = src; }
- (void)setBlendFuncDestination:(GLenum)dst { _blendFunc.dst = dst; }

@end

@interface CCDotNode : CCDrawNode
@property (nonatomic, assign) CGFloat radius;
@property (nonatomic, assign) ccColor4F color;
@end

@implementation CCDotNode
@synthesize radius = _radius;
@synthesize color = _color;

- (void)draw
{
    [self drawDot:self.position radius:_radius color:_color];
    [super draw];
    [super clear];
}

@end


#include <zlib.h>

#define CHUNK 16384

static NSData *zdef(NSData *src)
{
    int level = Z_DEFAULT_COMPRESSION;
    int ret;
    z_stream strm;
    unsigned char *srcbytes = (unsigned char *)src.bytes;
    int srclen = src.length;
    NSMutableData *dst = [NSMutableData dataWithLength:srclen * 2];
    unsigned char *dstbytes = (unsigned char *)dst.bytes;
    
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    ret = deflateInit(&strm, level);
    if (ret != Z_OK) {
        return nil;
    }
    
    strm.avail_in = srclen;
    strm.next_in = srcbytes;
    strm.avail_out = srclen * 2;
    strm.next_out = dstbytes;
    ret = deflate(&strm, Z_FINISH);
    [dst setLength:(srclen*2)-strm.avail_out];
    (void)deflateEnd(&strm);

    return dst;
}

#include <sys/types.h>
#include <sys/param.h>
#include <sys/socket.h>

#include <netinet/in.h>
#include <arpa/inet.h>
#include <arpa/nameser.h>

#include <ctype.h>
#include <resolv.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char Base64[] =
"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const char Pad64 = '=';


int
b64_ntop(u_char const *src, size_t srclength, char *target, size_t targsize) {
	size_t datalength = 0;
	u_char input[3];
	u_char output[4];
	size_t i;
    
	while (2 < srclength) {
		input[0] = *src++;
		input[1] = *src++;
		input[2] = *src++;
		srclength -= 3;
        
		output[0] = input[0] >> 2;
		output[1] = ((input[0] & 0x03) << 4) + (input[1] >> 4);
		output[2] = ((input[1] & 0x0f) << 2) + (input[2] >> 6);
		output[3] = input[2] & 0x3f;
        
		if (datalength + 4 > targsize)
			return (-1);
		target[datalength++] = Base64[output[0]];
		target[datalength++] = Base64[output[1]];
		target[datalength++] = Base64[output[2]];
		target[datalength++] = Base64[output[3]];
	}
    
	/* Now we worry about padding. */
	if (0 != srclength) {
		/* Get what's left. */
		input[0] = input[1] = input[2] = '\0';
		for (i = 0; i < srclength; i++)
			input[i] = *src++;
        
		output[0] = input[0] >> 2;
		output[1] = ((input[0] & 0x03) << 4) + (input[1] >> 4);
		output[2] = ((input[1] & 0x0f) << 2) + (input[2] >> 6);
        
		if (datalength + 4 > targsize)
			return (-1);
		target[datalength++] = Base64[output[0]];
		target[datalength++] = Base64[output[1]];
		if (srclength == 1)
			target[datalength++] = Pad64;
		else
			target[datalength++] = Base64[output[2]];
		target[datalength++] = Pad64;
	}
	if (datalength >= targsize)
		return (-1);
	target[datalength] = '\0';	/* Returned value doesn't count \0. */
	return (datalength);
}

@implementation NSData(Nu)

- (NSString *)encodeBase64
{
    unsigned char *srcbytes = (unsigned char *)self.bytes;
    char *dstbytes = malloc(sizeof(char)*self.length*2);
    int len = b64_ntop(srcbytes, self.length, dstbytes, self.length*2-1);
    if (len < 0)
        return nil;
    NSString *str = [NSString stringWithCString:dstbytes encoding:NSUTF8StringEncoding];
    free(dstbytes);
    return str;
}

@end


@implementation CCParticleSystem(Nu)

-(NSMutableDictionary *)dictValue
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    void (^set_obj)(NSString *key, id obj) = ^(NSString *key, id obj) {
        [dict setValue:obj forKey:key];
    };
    void (^set_int)(NSString *key, int n) = ^(NSString *key, int n) {
        set_obj(key, [NSNumber numberWithInt:n]);
    };
    void (^set_float)(NSString *key, float n) = ^(NSString *key, float n) {
        set_obj(key, [NSNumber numberWithFloat:n]);
    };
    
    set_int(@"maxParticles", _totalParticles);
    set_float(@"angle", _angle);
    set_float(@"angleVariance", _angleVar);
    set_float(@"duration", _duration);
    set_int(@"blendFuncSource", _blendFunc.src);
    set_int(@"blendFuncDestination", _blendFunc.dst);
    set_float(@"startColorRed", _startColor.r);
    set_float(@"startColorGreen", _startColor.g);
    set_float(@"startColorBlue", _startColor.b);
    set_float(@"startColorAlpha", _startColor.a);
    set_float(@"startColorVarianceRed", _startColorVar.r);
    set_float(@"startColorVarianceGreen", _startColorVar.g);
    set_float(@"startColorVarianceBlue", _startColorVar.b);
    set_float(@"startColorVarianceAlpha", _startColorVar.a);
    set_float(@"finishColorRed", _endColor.r);
    set_float(@"finishColorGreen", _endColor.g);
    set_float(@"finishColorBlue", _endColor.b);
    set_float(@"finishColorAlpha", _endColor.a);
    set_float(@"finishColorVarianceRed", _endColorVar.r);
    set_float(@"finishColorVarianceGreen", _endColorVar.g);
    set_float(@"finishColorVarianceBlue", _endColorVar.b);
    set_float(@"finishColorVarianceAlpha", _endColorVar.a);
    set_float(@"startParticleSize", _startSize);
    set_float(@"startParticleSizeVariance", _startSizeVar);
    set_float(@"finishParticleSize", _endSize);
    set_float(@"finishParticleSizeVariance", _endSizeVar);
    set_float(@"sourcePositionx", self.position.x);
    set_float(@"sourcePositiony", self.position.y);
    set_float(@"sourcePositionVariancex", _posVar.x);
    set_float(@"sourcePositionVariancey", _posVar.y);
    set_float(@"rotationStart", _startSpin);
    set_float(@"rotationStartVariance", _startSpinVar);
    set_float(@"rotationEnd", _endSpin);
    set_float(@"rotationEndVariance", _endSpinVar);
    set_int(@"emitterType", _emitterMode);
    set_float(@"gravityx", _mode.A.gravity.x);
    set_float(@"gravityy", _mode.A.gravity.y);
    set_float(@"speed", _mode.A.speed);
    set_float(@"speedVariance", _mode.A.speedVar);
    set_float(@"radialAcceleration", _mode.A.radialAccel);
    set_float(@"radialAccelVariance", _mode.A.radialAccelVar);
    set_float(@"tangentialAcceleration", _mode.A.tangentialAccel);
    set_float(@"tangentialAccelVariance", _mode.A.tangentialAccelVar);
    set_float(@"maxRadius", _mode.B.startRadius);
    set_float(@"maxRadiusVariance", _mode.B.startRadiusVar);
    set_float(@"minRadius", _mode.B.endRadius);
    set_float(@"rotatePerSecond", _mode.B.rotatePerSecond);
    set_float(@"rotatePerSecondVariance", _mode.B.rotatePerSecondVar);
    set_float(@"particleLifespan", _life);
    set_float(@"particleLifespanVariance", _lifeVar);
    
    id cgimage = [_texture valueForKey:@"CGImage"];
    UIImage *image = (cgimage) ? [UIImage imageWithCGImage:(CGImageRef)cgimage] : nil;
    NSData *imagedata = (image) ? UIImagePNGRepresentation(image) : nil;
    NSLog(@"image data len %d", imagedata.length);
    NSData *zdata = (imagedata) ? zdef(imagedata) : nil;
    NSLog(@"zdata len %d", zdata.length);
    NSString *b64str = [zdata encodeBase64];
    NSLog(@"b64str len %d", b64str.length);
    
    if (b64str) {
        set_obj(@"textureImageData", b64str);
    }
    
    return dict;
}

@end
