#import "SnesView.h"
#include "snes9x.h"

#define RADIANS( degrees ) ( degrees * M_PI / 180 )

extern int snes_load(const char *romfile, int frameskip, id view);
extern void snes_unload(void);
extern void audio_open();
extern void audio_close();

static const char *getCString(NSString *str)
{
    static char buf[1024];
    [str getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}

@interface SnesScreenLayer : CALayer
{
    CoreSurfaceBufferRef _screenSurface;
	CGAffineTransform rotateTransform;
}
@end

@implementation SnesScreenLayer

+ (id)defaultActionForKey:(NSString *)key
{
    return nil;
}

- (id)init
{
	self = [super init];
    if (self) {
        CFMutableDictionaryRef dict;
        extern int snes_screen_width, snes_screen_height;
        int w = snes_screen_width;
        int h = snes_screen_height;
        
        int pitch = w * 2, allocSize = 2 * w * h;
        char *pixelFormat = "565L";
        
        dict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                         &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(dict, kCoreSurfaceBufferGlobal, kCFBooleanTrue);
        CFDictionarySetValue(dict, kCoreSurfaceBufferMemoryRegion,
                             @"IOSurfaceMemoryRegion");
        CFDictionarySetValue(dict, kCoreSurfaceBufferPitch,
                             CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pitch));
        CFDictionarySetValue(dict, kCoreSurfaceBufferWidth,
                             CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &w));
        CFDictionarySetValue(dict, kCoreSurfaceBufferHeight,
                             CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &h));
        CFDictionarySetValue(dict, kCoreSurfaceBufferPixelFormat,
                             CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, pixelFormat));
        CFDictionarySetValue(dict, kCoreSurfaceBufferAllocSize,
                             CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &allocSize));
        
        _screenSurface = CoreSurfaceBufferCreate(dict);

        extern unsigned char *snes_videobuf;
        snes_videobuf = (unsigned char *) CoreSurfaceBufferGetBaseAddress(_screenSurface);

        rotateTransform = CGAffineTransformIdentity;
        self.affineTransform = rotateTransform;

        [self setMagnificationFilter:kCAFilterLinear];
        [self setMinificationFilter:kCAFilterLinear];        
    }
	return self;
}
	
- (void)display
{        
    CoreSurfaceBufferLock(_screenSurface, 3);
    self.contents = nil;    
    self.affineTransform = rotateTransform;
    self.contents = (id)_screenSurface;    
    CoreSurfaceBufferUnlock(_screenSurface);
}

- (void)dealloc
{
    if(_screenSurface!=nil)
    {
        CFRelease(_screenSurface);
        _screenSurface = nil;
    }
    [super dealloc];
}

@end

@interface SnesScreenView : UIView
@end

@implementation SnesScreenView

+ (Class) layerClass
{
    return [SnesScreenLayer class];
}

- (void)drawRect:(CGRect)rect
{
    //printf("Draw rect\n");
    // UIView uses the existence of -drawRect: to determine if should allow its CALayer
    // to be invalidated, which would then lead to the layer creating a backing store and
    // -drawLayer:inContext: being called.
    // By implementing an empty -drawRect: method, we allow UIKit to continue to implement
    // this logic, while doing our real drawing work inside of -drawLayer:inContext:
}

@end


@implementation SnesView

@synthesize filter;
@synthesize reverseX;
@synthesize reverseY;
@synthesize deadZoneX;
@synthesize deadZoneY;
@synthesize screenView = _screenView;
@synthesize helpView = _helpView;

- (void)dealloc
{
	snes_unload();
    [self.screenView removeFromSuperview];
    self.screenView = nil;
    self.helpView = nil;
    void (^removegr)(UIGestureRecognizer **gr) = ^(UIGestureRecognizer **gr) {
        [self removeGestureRecognizer:*gr];
        [*gr release];
        *gr = nil;
    };
    removegr(&grSwipeLeft);
    removegr(&grSwipeRight);
    removegr(&grSwipeUp);
    removegr(&grSwipeDown);
    removegr(&grTap);
    [motionManager stopAccelerometerUpdates];
    [motionManager release];
    motionManager = nil;
    [super dealloc];
}

CGRect snes_get_screen_rect(int w, int h, int origw, int origh)
{
    CGSize s = proportional_size(w, h, origw, origh);
    return CGRectMake((w-s.width)/2.0, (h-s.height)/2.0, s.width, s.height);
}

- (void)layoutSubviews
{
    extern int snes_screen_width, snes_screen_height;
    self.screenView.frame = snes_get_screen_rect(self.frame.size.width, self.frame.size.height, snes_screen_width, snes_screen_height);
}
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = YES;
        self.exclusiveTouch = NO;

        filter = 0.8f;
        reverseX = 1.0;
        reverseY = 1.0;
        deadZoneX = 0.2;
        deadZoneY = 0.2;
        
        motionManager = [[CMMotionManager alloc] init];
        motionManager.accelerometerUpdateInterval = 0.01;
        [motionManager startAccelerometerUpdates];
        
        UISwipeGestureRecognizer *(^addswipegr)(SEL selector, UISwipeGestureRecognizerDirection direction) = ^(SEL selector, UISwipeGestureRecognizerDirection direction) {
            UISwipeGestureRecognizer *gr = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:selector];
            gr.direction = direction;
            [self addGestureRecognizer:gr];
            return gr;
        };
        grSwipeLeft = addswipegr(@selector(handleSwipeLeft), UISwipeGestureRecognizerDirectionLeft);
        grSwipeRight = addswipegr(@selector(handleSwipeRight), UISwipeGestureRecognizerDirectionRight);
        grSwipeUp = addswipegr(@selector(handleSwipeUp), UISwipeGestureRecognizerDirectionUp);
        grSwipeDown = addswipegr(@selector(handleSwipeDown), UISwipeGestureRecognizerDirectionDown);
        grTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
        [self addGestureRecognizer:grTap];
        
        self.screenView = [[[SnesScreenView alloc] initWithFrame:CGRectZero] autorelease];
        self.screenView.userInteractionEnabled = NO;
        self.screenView.clearsContextBeforeDrawing = NO;
        [self addSubview:self.screenView];
        [self setNeedsLayout];

    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouches:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self handleTouches:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self handleTouches:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self handleTouches:touches withEvent:event];
}

- (void)handleTouches:(NSSet *)touches withEvent:(UIEvent *)event
{
    touch_buttons = 0;
    for (UITouch *t in event.allTouches) {
        if (t.phase == UITouchPhaseCancelled)
            continue;
        if (t.phase == UITouchPhaseEnded)
            continue;
        CGPoint p = [t locationInView:self];
        if (p.x < self.frame.size.width / 2) {
            if (p.y > self.frame.size.height * 0.95) {
                touch_buttons |= SNES_X_MASK;
            } else {
                touch_buttons |= SNES_B_MASK;
            }
        } else if (p.x > self.frame.size.width * 0.95) {
            if (p.y < self.frame.size.height * 0.05) {
                if (self.helpView) {
                    [self.helpView removeFromSuperview];
                    self.helpView = nil;
                } else {
//                    self.helpView = helpForSMK(self.frame);
//                    [self addSubview:self.helpView];
                }
            }
        }
    }
}

- (void)handleSwipeLeft
{
    CGPoint p = [grSwipeLeft locationInView:self];
    if (p.x < self.frame.size.width / 2) {
        [self handleReset];
    } else {
        gesture_buttons |= SNES_SELECT_MASK;
        gesture_length++;
    }
}

- (void)handleSwipeRight
{
    CGPoint p = [grSwipeRight locationInView:self];
    if (p.x < self.frame.size.width * 0.05) {
//        [rootViewController.navigationController popViewControllerAnimated:YES];
    } else if (p.x < self.frame.size.width / 2) {
    } else {
        gesture_buttons |= SNES_START_MASK;
        gesture_length++;
    }
}

- (void)handleSwipeUp
{
    CGPoint p = [grSwipeRight locationInView:self];
    if (p.x < self.frame.size.width / 2) {
    } else {
        gesture_buttons |= SNES_TR_MASK;
        gesture_length++;
    }
}

- (void)handleSwipeDown
{
    CGPoint p = [grSwipeDown locationInView:self];
    if (p.x < self.frame.size.width / 2) {
    } else {
        gesture_buttons |= SNES_DOWN_MASK;
        gesture_buttons |= SNES_A_MASK;
        gesture_length += 2;
    }
}

- (void)handleTap
{
    NSLog(@"handleTap");
    CGPoint p = [grTap locationInView:self];
    if (p.x > self.frame.size.width/2) {
        NSLog(@"tap");
        gesture_buttons |= SNES_UP_MASK;
        gesture_buttons |= SNES_A_MASK;
        gesture_length += 2;
    }
}

- (void)readAccelerometer
{
    CMAccelerometerData *newestAccel = motionManager.accelerometerData;
    filteredAccelerationX = filteredAccelerationX * (1.0-filter) + newestAccel.acceleration.x * filter;
    filteredAccelerationY = filteredAccelerationY * (1.0-filter) + newestAccel.acceleration.y * filter;
    filteredAccelerationZ = filteredAccelerationZ * (1.0-filter) + newestAccel.acceleration.z * filter;
    float (^calcx)(float) =  ^(float val) {
        val *= 2.0f;
        if (val < -1.0f)
            return -1.0f;
        if (val > 1.0f)
            return 1.0f;
        return val;
    };
    float (^calcy)(float) = ^(float val) {
        if (val < -0.95f)
            return -1.0f;
        if (val > -0.5f)
            return 1.0f;
        val += 0.95f;
        val *= 1.0f/0.45f*2.0f;
        val -= 1.0f;
        if (val < -1.0f)
            return -1.0f;
        if (val > 1.0f)
            return 1.0f;
        return val;
    };
    float x = calcx((float)filteredAccelerationY)*reverseX;
    float y = calcy((float)filteredAccelerationZ)*reverseY;
    accel_buttons = 0;
    if (x < -deadZoneX) {
        if (x <= accel_peak) {
            accel_buttons |= SNES_LEFT_MASK;
            accel_peak = x;
        } else {
            accel_peak *= 0.97;
        }
    } else if (x > deadZoneX) {
        if (x >= accel_peak) {
            accel_buttons |= SNES_RIGHT_MASK;
            accel_peak = x;
        } else {
            accel_peak *= 0.97;
        }
    } else {
        accel_peak = 0;
    }
    if (y < -deadZoneY) {
    } else if (y > deadZoneY) {
    } else {
    }
    if (!deadZoneX && !deadZoneY) {
        accel_freq = fabs(x) * 60;
        accel_freq = 60 - accel_freq;
        if (accel_freq < 1)
            accel_freq = 1;
    } else {
        accel_freq = 0;
    }
    
    //    NSLog(@"%.4f %.4f %.4f %.4f %.4f", *analogx, *analogy, newestAccel.acceleration.x, newestAccel.acceleration.y, newestAccel.acceleration.z);
}

- (uint16_t)gestureButtons
{
    uint16_t val = gesture_buttons;
    if (gesture_length > 0) {
        gesture_length--;
        if (!gesture_length) {
            gesture_buttons = 0;
        }
    }
    return val;
}

- (uint16_t)joypadButtons
{
    [self readAccelerometer];
    return touch_buttons|accel_buttons|self.gestureButtons;
}

- (int)loadROM:(NSString *)path frameSkip:(int)frameSkip
{
		if (snes_load(getCString(path), frameSkip, self)) {
			NSLog(@"loaded rom '%@'", path);
			return 1;
		}
		return 0;
}

- (void)handleReset
{
    void snes_audio_close(void);
    snes_audio_close();
    extern int snes_audio_do_not_initialize;
    snes_audio_do_not_initialize = 1;
    UIAlertView *av = [[[UIAlertView alloc] initWithTitle:@"Reset" message:@"Are you sure?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil] autorelease];
    [av show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        extern void snes_reset(void);
        snes_reset();
    }
    extern int snes_audio_do_not_initialize;
    snes_audio_do_not_initialize = 0;
    void snes_audio_open(void);
    snes_audio_open();
}

@end
