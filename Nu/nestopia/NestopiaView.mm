#import "NestopiaView.h"
#import "Helper.h"
#import "Misc.h"

#define RADIANS( degrees ) ( degrees * M_PI / 180 )

extern int nst_load(const char *filename, int, int, id view);
extern void nst_unload(void);
extern void audio_close(void);
extern void audio_open(void);

@interface NesScreenLayer : CALayer
{
    CoreSurfaceBufferRef _screenSurface;
	CGAffineTransform rotateTransform;
}
@end

@implementation NesScreenLayer

+ (id)defaultActionForKey:(NSString *)key
{
    return nil;
}

- (id)init
{
    NSLog(@"NestopiaLayer init");
	self = [super init];
    if (self) {
        CFMutableDictionaryRef dict;
        extern int nes_screen_width, nes_screen_height;
        int w = nes_screen_width;
        int h = nes_screen_height;
        
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

        extern unsigned char *nes_videobuf;
        nes_videobuf = (unsigned char *) CoreSurfaceBufferGetBaseAddress(_screenSurface);

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

@interface NesScreenView : UIView
@end
@implementation NesScreenView

+ (Class) layerClass
{
    return [NesScreenLayer class];
}

- (void)drawRect:(CGRect)rect
{
    // UIView uses the existence of -drawRect: to determine if should allow its CALayer
    // to be invalidated, which would then lead to the layer creating a backing store and
    // -drawLayer:inContext: being called.
    // By implementing an empty -drawRect: method, we allow UIKit to continue to implement
    // this logic, while doing our real drawing work inside of -drawLayer:inContext:
}

@end

@implementation NesView
@synthesize screenView = _screenView;
@synthesize helpView = _helpView;
@synthesize path = _path;

- (void)dealloc
{
    nst_unload();
    [self.screenView removeFromSuperview];
    self.screenView = nil;
    self.helpView = nil;
    void (^removegr)(UISwipeGestureRecognizer **gr) = ^(UISwipeGestureRecognizer **gr) {
        [self removeGestureRecognizer:*gr];
        [*gr release];
        *gr = nil;
    };
    removegr(&grSwipeLeft);
    removegr(&grSwipeRight);
    [super dealloc];
}

CGRect nes_get_screen_rect(int w, int h, int origw, int origh)
{
    CGSize s = proportional_size(w, h, origw, origh);
    return CGRectMake((w-s.width)/2.0, (h-s.height)/2.0, s.width, s.height);
}

- (void)layoutSubviews
{
    extern int nes_screen_width, nes_screen_height;
    self.screenView.frame = nes_get_screen_rect(self.frame.size.width, self.frame.size.height, nes_screen_width, nes_screen_height);
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
    if (self) {
       self.multipleTouchEnabled = YES;
	   self.userInteractionEnabled = YES;
        UISwipeGestureRecognizer *(^addswipegr)(SEL selector, UISwipeGestureRecognizerDirection direction) = ^(SEL selector, UISwipeGestureRecognizerDirection direction) {
            UISwipeGestureRecognizer *gr = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:selector];
            gr.direction = direction;
            [self addGestureRecognizer:gr];
            return gr;
        };
        grSwipeLeft = addswipegr(@selector(handleSwipeLeft), UISwipeGestureRecognizerDirectionLeft);
        grSwipeRight = addswipegr(@selector(handleSwipeRight), UISwipeGestureRecognizerDirectionRight);
        self.screenView = [[[NesScreenView alloc] initWithFrame:CGRectZero] autorelease];
        self.screenView.userInteractionEnabled = NO;
        self.screenView.clearsContextBeforeDrawing = NO;
        [self addSubview:self.screenView];
        [self setNeedsLayout];
	}
	return self;
}

- (void)loadROM:(NSString *)path usePad:(BOOL)usePad useZapper:(BOOL)useZapper
{
    self.path = path;
    if (nst_load(getCString(self.path), usePad, useZapper, self)) {
        NSLog(@"loaded %@", self.path);
    } else {
        NSLog(@"unable to load %@", self.path);
    }
}

- (void)handleReset
{
    void nes_audio_close(void);
    nes_audio_close();
    extern int nes_audio_do_not_initialize;
    nes_audio_do_not_initialize = 1;
    UIAlertView *av = [[[UIAlertView alloc] initWithTitle:@"Reset" message:@"Are you sure?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil] autorelease];
    [av show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        extern void nst_reset(void);
        nst_reset();
    }
    extern int nes_audio_do_not_initialize;
    nes_audio_do_not_initialize = 0;
    void nes_audio_open(void);
    nes_audio_open();
}

- (void)handleTouchesZapper:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint p;
    
    static unsigned int x = ~0U;
    static unsigned int y = ~0U;
    static unsigned int fire = 0;
    
    int touchcount=0;
    for (UITouch *t in event.allTouches) {
        if (t.phase == UITouchPhaseCancelled)
            continue;
        if (touchcount) {
            touchcount = 0;
            break;
        }
        if (t.phase == UITouchPhaseBegan) {
            p = [t locationInView:self];
            for (UIView *v in self.subviews) {
                if ((p.x >= v.frame.origin.x) && (p.x < v.frame.origin.x+v.frame.size.width)) {
                    if ((p.y >= v.frame.origin.y) && (p.y < v.frame.origin.y+v.frame.size.height)) {
                        double analogx = (p.x - v.frame.origin.x) / v.frame.size.width;
                        double analogy = (p.y - v.frame.origin.y) / v.frame.size.height;
                        extern int nes_screen_width, nes_screen_height;
                        x = (unsigned int) (analogx * ((double) nes_screen_width));
                        y = (unsigned int) (analogy * ((double) nes_screen_height));
                    }
                }
                break;
            }
            fire = 1;
            touchcount++;
            continue;
        }
        if (t.phase == UITouchPhaseEnded) {
            fire = 0;
            touchcount++;
            continue;
        }
        touchcount++;
    }
    if (!touchcount) {
        x = ~0U;
        y = ~0U;
        fire = 0;
    }
    
    NSLog(@"zapper x %d y %d fire %d [%.f %.f]", x, y, fire, p.x, p.y);
    extern void set_zapper_buttons(unsigned int x, unsigned int y, unsigned int fire);
    set_zapper_buttons(x, y, fire);
}

- (void)handleTouchesPad:(NSSet *)touches withEvent:(UIEvent *)event
{
    /*
     A      = 0x01,
     B      = 0x02,
     SELECT = 0x04,
     START  = 0x08,
     UP     = 0x10,
     DOWN   = 0x20,
     LEFT   = 0x40,
     RIGHT  = 0x80
     */
    touch_buttons = 0;
    for (UITouch *t in event.allTouches) {
        if (t.phase == UITouchPhaseCancelled)
            continue;
        if (t.phase == UITouchPhaseEnded)
            continue;
        CGPoint p = [t locationInView:self];
        if (p.y < self.frame.size.height * 0.55) {
            touch_buttons |= 0x10;
            if (p.x < self.frame.size.width * 0.05) {
                touch_buttons |= 0x40;
            } else if (p.x > self.frame.size.width * 0.95) {
                touch_buttons |= 0x80;
                if (p.y < self.frame.size.height * 0.05) {
                    if (t.phase == UITouchPhaseBegan) {
                        if (self.helpView) {
                            [self.helpView removeFromSuperview];
                            self.helpView = nil;
                        } else {
//                            self.helpView = helpForTouch(self.frame);
//                            [self addSubview:self.helpView];
                        }
                    }
                }
            }
        } else if (p.y < self.frame.size.height * 0.95) {
            if (p.x < self.frame.size.width * 0.05) {
                touch_buttons |= 0x40;
            } else if (p.x < self.frame.size.width * 0.50) {
                touch_buttons |= 0x02;
            } else if (p.x < self.frame.size.width * 0.95) {
                touch_buttons |= 0x01;
            } else {
                touch_buttons |= 0x80;
            }
        } else {
            touch_buttons |= 0x20;
            if (p.x < self.frame.size.width * 0.05) {
                touch_buttons |= 0x40;
            } else if (p.x > self.frame.size.width * 0.95) {
                touch_buttons |= 0x80;
            }
        }
    }
}

- (void)handleTouches:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self handleTouchesZapper:touches withEvent:event];
    [self handleTouchesPad:touches withEvent:event];
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

- (void)handleSwipeLeft
{
    CGPoint p = [grSwipeLeft locationInView:self];
    if (p.x < self.frame.size.width / 2) {
        [self handleReset];
    } else {
        gesture_buttons |= 0x04;
        gesture_length++;
    }
}

- (void)handleSwipeRight
{
    NSLog(@"handleSwipeRight");
    CGPoint p = [grSwipeRight locationInView:self];
    if (p.x < self.frame.size.width * 0.05) {
//        extern RootViewController *rootViewController;
//        [rootViewController.navigationController popViewControllerAnimated:YES];
    } else if (p.x < self.frame.size.width / 2) {
    } else {
        gesture_buttons |= 0x08;
        gesture_length++;
    }
}

- (int)gestureButtons
{
    int val = gesture_buttons;
    if (gesture_length > 0) {
        gesture_length--;
        if (!gesture_length) {
            gesture_buttons = 0;
        }
    }
    return val;
}

- (int)joypadButtons
{
    return touch_buttons|self.gestureButtons;
}

@end

