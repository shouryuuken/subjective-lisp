//
//  Glue.m
//  NuMagick
//
//  Created by arthur on 12/04/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "Nu.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#include <event2/event.h>

#define M_PI   3.14159265358979323846264338327950288   
#define DEG_TO_RADIANS(angle) (angle / 180.0 * M_PI)

@interface Glue : NSObject
@end

@implementation Glue


+ (NSArray*)pixelColorsFromImage:(UIImage*)image
{
    NSMutableArray *result = [NSMutableArray array];
    
    // First get the image into your data buffer
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char*) calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    // Now your rawData contains the image data in the RGBA8888 pixel format.
    for (int y=0; y<height; y++) {
        NSMutableArray *row = [NSMutableArray array];
        for (int x=0; x<width; x++) {
            int byteIndex = (bytesPerRow * y) + x * bytesPerPixel;
            CGFloat red   = (rawData[byteIndex]     * 1.0) / 255.0;
            CGFloat green = (rawData[byteIndex + 1] * 1.0) / 255.0;
            CGFloat blue  = (rawData[byteIndex + 2] * 1.0) / 255.0;
            CGFloat alpha = (rawData[byteIndex + 3] * 1.0) / 255.0;
            UIColor *acolor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
            [row addObject:acolor];
        }
        [result addObject:row];
    }
    
    free(rawData);
    
    return result;
}


UIImage *scaleAndRotateImage(UIImage *image, int kMaxResolution)
{    
    CGImageRef imgRef = image.CGImage;
    
    CGFloat width = CGImageGetWidth(imgRef);
    CGFloat height = CGImageGetHeight(imgRef);
    
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGRect bounds = CGRectMake(0, 0, width, height);
    if (width > kMaxResolution || height > kMaxResolution) {
        CGFloat ratio = width/height;
        if (ratio > 1) {
            bounds.size.width = kMaxResolution;
            bounds.size.height = bounds.size.width / ratio;
        }
        else {
            bounds.size.height = kMaxResolution;
            bounds.size.width = bounds.size.height * ratio;
        }
    }
    
    CGFloat scaleRatio = bounds.size.width / width;
    CGSize imageSize = CGSizeMake(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
    CGFloat boundHeight;
    UIImageOrientation orient = image.imageOrientation;
    switch(orient) {
            
        case UIImageOrientationUp: //EXIF = 1
            prn(@"UIImageOrientationUp");
            transform = CGAffineTransformIdentity;
            break;
            
        case UIImageOrientationUpMirrored: //EXIF = 2
            prn(@"UIImageOrientationUpMirrored");
            transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            break;
            
        case UIImageOrientationDown: //EXIF = 3
            prn(@"UIImageOrientationDown");
            transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationDownMirrored: //EXIF = 4
            prn(@"UIImageOrientationDownMirrored");
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
            transform = CGAffineTransformScale(transform, 1.0, -1.0);
            break;
            
        case UIImageOrientationLeftMirrored: //EXIF = 5
            prn(@"UIImageOrientationLeftMirrored");
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case UIImageOrientationLeft: //EXIF = 6
            prn(@"UIImageOrientationLeft");
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case UIImageOrientationRightMirrored: //EXIF = 7
            prn(@"UIImageOrientationRightMirrored");
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeScale(-1.0, 1.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        case UIImageOrientationRight: //EXIF = 8
            prn(@"UIImageOrientationRight");
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Invalid image orientation"];
            
    }
    
    UIGraphicsBeginImageContext(bounds.size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if (orient == UIImageOrientationRight || orient == UIImageOrientationLeft) {
        CGContextScaleCTM(context, -scaleRatio, scaleRatio);
        CGContextTranslateCTM(context, -height, 0);
    }
    else {
        CGContextScaleCTM(context, scaleRatio, -scaleRatio);
        CGContextTranslateCTM(context, 0, -height);
    }
    
    CGContextConcatCTM(context, transform);
    
    CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, width, height), imgRef);
    UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return imageCopy;
}


+ (UIWebView *)UIWebView:(CGRect)r { return [[[UIWebView alloc] initWithFrame:r] autorelease]; }

+ (void)animateWithDuration:(NSTimeInterval)duration block:(NuBlock *)block
{
    [UIView animateWithDuration:duration animations:^{[block evalWithArguments:[NSNull null] context:[[Nu sharedParser] context]];}];
}

+ (void)animateWithDuration:(NSTimeInterval)duration animations:(NuBlock *)animations completion:(NuBlock *)completion
{
    [UIView animateWithDuration:duration animations:^{[animations evalWithArguments:[NSNull null] context:[[Nu sharedParser] context]];} completion:^(BOOL finished) { [completion evalWithArguments:[NSNull null] context:[[Nu sharedParser] context]]; } ];
}

+ (void)scaleImage:(id)lst
{
    UIImage *orig = [lst objectAtIndex:0];
    NSString *path = [lst objectAtIndex:1];
    NSNumber *pixels = [lst objectAtIndex:2];
    [Glue scaleImage:orig path:path pixels:[pixels intValue]];
}

+ (void)scaleImage:(UIImage *)orig path:(NSString *)path pixels:(int)pixels
{
    UIImage *image = scaleAndRotateImage(orig, pixels);
    [Glue writeImage:image path:path];
}

+ (UIImage *)scaleImage:(UIImage *)orig maxPixels:(int)maxPixels
{
    UIImage *image = orig;
    if ((orig.size.width > maxPixels) || (orig.size.height > maxPixels))
        image = scaleAndRotateImage(orig, maxPixels);
    return image;
}

+ (CGSize)proportionalSize:(CGSize)currentSize maxSize:(CGSize)maxSize
{
    int image_width = currentSize.width;
    int image_height = currentSize.height;
    int tmp_width = maxSize.width;
    int tmp_height = ((((tmp_width * image_height) / image_width)+7)&~7);
    if(tmp_height > maxSize.height)
    {
        tmp_height = maxSize.height;
        tmp_width = ((((tmp_height * image_width) / image_height)+7)&~7);
    }   
    return CGSizeMake(tmp_width, tmp_height);
}

+ (void)writeImage:(id)lst
{
    UIImage *image = [lst objectAtIndex:0];
    NSString *path = [lst objectAtIndex:1];
    [Glue writeImage:image path:path];
}

+ (void)writeImage:(UIImage *)image path:(NSString *)path
{
    [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
}

+ (void)saveToCameraRoll:(UIImage *)image
{
    if (image) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }
}

+ (void)composite:(NSString *)srcbg fg:(NSString *)srcfg alpha:(CGFloat)alpha dst:(NSString *)dst
{
    UIImage *bg = [UIImage imageWithContentsOfFile:srcbg];
    UIImage *fg = [UIImage imageWithContentsOfFile:srcfg];
    UIGraphicsBeginImageContextWithOptions(bg.size, NO, bg.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [bg drawAtPoint:CGPointMake(0.0, 0.0)];
    [fg drawAtPoint:CGPointMake(0.0, 0.0) blendMode:kCGBlendModeHardLight alpha:alpha];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    [image retain];
    UIGraphicsEndImageContext();
    [Glue writeImage:image path:dst];
}

+ (NSMutableArray *)sortFileArrayAlphabetically:(NSMutableArray *)arr
{
    NSComparator cmp = ^(NSString *a, NSString *b) {
        if ([a.lowercaseString hasPrefix:[b.lowercaseString stringByDeletingPathExtension]])
            return (NSComparisonResult)NSOrderedDescending;
        if ([b.lowercaseString hasPrefix:[a.lowercaseString stringByDeletingPathExtension]])
            return (NSComparisonResult)NSOrderedAscending;
        return (NSComparisonResult)[a localizedCaseInsensitiveCompare:b];
    };
    [arr sortUsingComparator:cmp];
    return arr;
}

static UIFont *fontWithName(NSString *fontName, NSString *str, CGSize fits)
{
    CGFloat fontSize = 12.0f;
    CGFloat val = (fits.width > fits.height) ? fits.height : fits.width;
    for(;;) {
        UIFont *f = [UIFont fontWithName:fontName size:fontSize+1.0f];
        CGSize s = [str sizeWithFont:f];
        if ((s.width > val) || (s.height > val)) {
            return f;
        }
        fontSize += 1.0f;
    }
}

+ (UIImage *)imageWithString:(NSString *)str font:(UIFont *)font
{
    CGSize size = [str sizeWithFont:font];
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    /*    CGContextRef context = UIGraphicsGetCurrentContext();
     [[UIColor colorWithRed:0.875 green:0.875 blue:0.5 alpha:1.0] set];
     CGContextFillRect(context, CGRectMake(0.0, 0.0, size.width, size.height));*/
    [[UIColor whiteColor] set];
    [str drawInRect:CGRectMake(0, 0, size.width, size.height) withFont:font];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)imageWithString:(NSString *)str font:(UIFont *)font size:(CGSize)size
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    /*    CGContextRef context = UIGraphicsGetCurrentContext();
     [[UIColor colorWithRed:0.875 green:0.875 blue:0.5 alpha:1.0] set];
     CGContextFillRect(context, CGRectMake(0.0, 0.0, size.width, size.height));*/
    CGSize textSize = [str sizeWithFont:font];
    [[UIColor whiteColor] set];
    [str drawInRect:CGRectMake((size.width-textSize.width)/2.0, (size.height-textSize.height)/2.0, textSize.width, textSize.height) withFont:font];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)imageWithEmoji:(NSString *)str size:(CGSize)size
{
    UIFont *font = fontWithName(@"AppleColorEmoji", str, size);
    return [Glue imageWithString:str font:font size:size];
}

+ (NSString *)unicodeForPileOfPoo { return @"\ue05a"; }
+ (NSString *)unicodeForCryingFace { return @"\ue411"; }
+ (NSString *)unicodeForHamster { return @"\U0001F439"; }

+ (UIImage *)scaleImageOnly:(UIImage *)image size:(CGSize)s
{
    UIGraphicsBeginImageContext(s);

    CGContextRef context = UIGraphicsGetCurrentContext();

    [image drawInRect:CGRectMake(0.0, 0.0, s.width, s.height)];
    UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return imageCopy;
}

@end

CGFloat *enumerable_to_cgfloat(id enumerable, int *countref)
{
    int count = [enumerable count];
    if (!count) {
        if (countref)
            *countref = 0;
        return NULL;
    }
    CGFloat *result = malloc(sizeof(CGFloat)*count);
    int i=0;
    for (id obj in enumerable) {
        if (i == count)
            break;
        result[i] = [obj floatValue];
        i++;
    }
    *countref = i;
    return result;
}
unsigned short *enumerable_to_unsigned_short(id enumerable, int *countref)
{
    int count = [enumerable count];
    if (!count) {
        if (countref)
            *countref = 0;
        return NULL;
    }
    unsigned short *result = malloc(sizeof(unsigned short)*count);
    int i=0;
    for (id obj in enumerable) {
        if (i == count)
            break;
        result[i] = [obj floatValue];
        i++;
    }
    *countref = i;
    return result;
}

@interface CGPath : NSValue
@end
@implementation CGPath
@end

@interface CGColorSpace : NSValue
@end
@implementation CGColorSpace
@end

@interface CGPDFPage : NSObject
{
    CGPDFPageRef _page;
}
@property (nonatomic, retain) id document;
@end
@implementation CGPDFPage
@synthesize document = _document;

+ (id)pageNumber:(size_t)page document:(id)document
{
    return [[[self alloc] initWithPageNumber:page document:document] autorelease];
}

- (void)dealloc
{
    if (_page) {
        CGPDFPageRelease(_page);
        _page = NULL;
    }
    self.document = nil;
    [super dealloc];
}

- (id)initWithPageNumber:(size_t)page document:(id)document
{
    self = [super init];
    if (self) {
        self.document = document;
        _page = CGPDFDocumentGetPage([document document], page);
        if (_page) {
            CGPDFPageRetain(_page);
        }
    }
    return self;
}

- (CGPDFPageRef)CGPDFPage { return _page; }

- (CGAffineTransform)drawingTransform:(CGPDFBox)box rect:(CGRect)rect rotate:(int)rotate preserveAspectRatio:(BOOL)preserveAspectRatio
{
    return CGPDFPageGetDrawingTransform(_page, box, rect, rotate, preserveAspectRatio);
}

@end

@interface CGPDFDocument : NSObject
{
    CGPDFDocumentRef _document;
}
@end
@implementation CGPDFDocument
+ (id)documentWithURL:(NSURL *)url
{
    return [[[self alloc] initWithURL:url] autorelease];
}
- (void)dealloc
{
    if (_document) {
        NSLog(@"CGPDFDocument dealloc %p", self);
        CGPDFDocumentRelease(_document);
        _document = NULL;
    }
    [super dealloc];
}
- (id)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self) {
        _document = CGPDFDocumentCreateWithURL((CFURLRef)url);
        if (!_document)
            return nil;
    }
    return self;
}
- (CGPDFDocumentRef)document { return _document; }
- (id)page:(size_t)page
{
    return [CGPDFPage pageNumber:page document:self];
}
@end

@interface CGFont : NSObject
{
    CGFontRef _font;
}
@end
@implementation CGFont
+ (id)fontWithName:(NSString *)name
{
    return [[[self alloc] initWithFontName:name] autorelease];
}
- (void)dealloc
{
    if (_font) {
        CGFontRelease(_font);
        _font = NULL;
    }
    [super dealloc];
}
- (id)initWithFontName:(NSString *)name
{
    self = [super init];
    if (self) {
        _font = CGFontCreateWithFontName((CFStringRef)name);
        if (!_font)
            return nil;
    }
    return self;
}
- (CGFontRef)CGFont { return _font; }
@end

@interface CGGradient : NSObject
{
    CGGradientRef _gradient;
}
@end
@implementation CGGradient
+ (id)gradientWithRGBColorComponents:(id)colorsList locations:(id)locationsList
{
    return [[[self alloc] initWithRGBColorComponents:colorsList locations:locationsList] autorelease];
}
- (void)dealloc
{
    if (_gradient) {
        CGGradientRelease(_gradient);
        _gradient = NULL;
    }
    [super dealloc];
}
- (id)initWithRGBColorComponents:(id)colorsList locations:(id)locationsList
{
    self = [super init];
    if (self) {
        CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
        int count, locations_count;
        void *colors = enumerable_to_cgfloat(colorsList, &count);
        count /= 4;
        if (!count)
            return nil;
        void *locations = enumerable_to_cgfloat(locationsList, &locations_count);
        if (locations_count && (locations_count < count))
            count = locations_count;
        _gradient = CGGradientCreateWithColorComponents(rgb, colors, locations, count);
        if (colors)
            free(colors);
        if (locations)
            free(locations);
        CGColorSpaceRelease(rgb);
        if (!_gradient)
            return nil;
    }
    return self;
}
- (CGGradientRef)CGGradient { return _gradient; }
@end

@class DrawView;
void cgpattern_draw_helper(void *info, CGContextRef context)
{
    //FIXME
    DrawView *v = [[DrawView alloc] initWithFrame:CGRectZero];
    [v setContext:context];
    NSLog(@"cgpattern_callback_helper %@", (id)info);
    eval_block((id)info, v, nil);
    [v release];
}
void cgpattern_release_helper(void *info)
{
    [(id)info release];
}

@interface CGPattern : NSObject
{
    CGPatternRef _pattern;
    CGColorSpaceRef _colorspace;
}
@end
@implementation CGPattern
+ (id)patternWithBounds:(CGRect)bounds transform:(CGAffineTransform)transform xStep:(CGFloat)xStep yStep:(CGFloat)yStep tiling:(CGPatternTiling)tiling block:(id)block
{
    return [[[self alloc] initWithBounds:bounds transform:transform xStep:xStep yStep:yStep tiling:tiling block:block] autorelease];
}
- (void)dealloc
{
    CGPatternRelease(_pattern);
    CGColorSpaceRelease(_colorspace);
    [super dealloc];
}
- (id)initWithBounds:(CGRect)bounds transform:(CGAffineTransform)transform xStep:(CGFloat)xStep yStep:(CGFloat)yStep tiling:(CGPatternTiling)tiling block:(id)block
{
    self = [super init];
    if (self) {
        [block retain];
        CGPatternCallbacks callbacks = {0, cgpattern_draw_helper, cgpattern_release_helper};
        _pattern = CGPatternCreate(block, bounds, transform, xStep, yStep, tiling, FALSE, &callbacks);
        CGColorSpaceRef deviceRGB = CGColorSpaceCreateDeviceRGB();
        _colorspace = CGColorSpaceCreatePattern(deviceRGB);
        CGColorSpaceRelease(deviceRGB);
    }
    return self;
}
- (CGPatternRef)pattern { return _pattern; }
- (CGColorSpaceRef)colorspace { return _colorspace; }
@end

@interface UIColorPattern : UIColor
@end
@implementation UIColorPattern
- (void)dealloc
{
    [super dealloc];
}

+ (id)patternWithBounds:(CGRect)bounds transform:(CGAffineTransform)transform xStep:(CGFloat)xStep yStep:(CGFloat)yStep tiling:(CGPatternTiling)tiling block:(id)block
{
    return [[[self alloc] initWithBounds:bounds transform:transform xStep:xStep yStep:yStep tiling:tiling block:block] autorelease];
}

- (id)initWithBounds:(CGRect)bounds transform:(CGAffineTransform)transform xStep:(CGFloat)xStep yStep:(CGFloat)yStep tiling:(CGPatternTiling)tiling block:(id)block
{
    [block retain];
    NSLog(@"UIColorPattern %@", block);
    CGPatternCallbacks callbacks = { 0, cgpattern_draw_helper, cgpattern_release_helper };
    CGPatternRef pattern = CGPatternCreate(block, bounds, transform, xStep, yStep, tiling, TRUE, &callbacks);
    CGColorSpaceRef colorSpace = CGColorSpaceCreatePattern(NULL);
    CGFloat alpha = 1.0;
    CGColorRef color = CGColorCreateWithPattern(colorSpace, pattern, &alpha);
    CGColorSpaceRelease(colorSpace);
    CGPatternRelease(pattern);
    self = [super initWithCGColor:color];
    CGColorRelease(color);
    return self;
}
- (void)set
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [self CGColor]);
    CGContextSetStrokeColorWithColor(context, [self CGColor]);
}
- (void)setFill
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [self CGColor]);
}
- (void)setStroke
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [self CGColor]);
}
@end

@interface CGMutablePath : NSObject
{
    CGMutablePathRef _path;
}
@end
@implementation CGMutablePath
- (void)dealloc
{
    if (_path) {
        CGPathRelease(_path);
        _path = NULL;
    }
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self) {
        _path = CGPathCreateMutable();
    }
    return self;
}
- (CGMutablePathRef)path { return _path; }

- (void)addRect:(CGRect)r { CGPathAddRect(_path, NULL, r); }
- (void)addRect:(CGRect)r transform:(CGAffineTransform)t { CGPathAddRect(_path, &t, r); }

@end

@interface CFAttributedString : NSObject
{
    CFMutableAttributedStringRef _string;
}
@end
@implementation CFAttributedString
- (void)dealloc
{
    if (_string) {
        CFRelease(_string);
        _string = NULL;
    }
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self) {
        _string = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    }
    return self;
}
- (CFMutableAttributedStringRef)string { return _string; }
- (void)replaceString:(NSString *)replacement range:(NSRange)range
{
    CFAttributedStringReplaceString(_string, CFRangeMake(range.location, range.length), (CFStringRef)replacement);
}

- (void)setAttribute:(CFStringRef)name value:(CFTypeRef)val range:(NSRange)range
{
    CFAttributedStringSetAttribute(_string, CFRangeMake(range.location, range.length), name, val);
}

@end

@interface CGBitmapContext : NSObject
{
    CGContextRef _context;
}
@end
@implementation CGBitmapContext
+ (id)contextWithSize:(CGSize)size bitsPerComponent:(size_t)bitsPerComponent bytesPerRow:(size_t)bytesPerRow info:(CGBitmapInfo)info
{
    return [[[self alloc] initWithSize:size bitsPerComponent:bitsPerComponent bytesPerRow:bytesPerRow info:info] autorelease];
}
- (void)dealloc
{
    if (_context) {
        CGContextRelease(_context);
        _context = NULL;
    }
    [super dealloc];
}
- (id)initWithSize:(CGSize)size bitsPerComponent:(size_t)bitsPerComponent bytesPerRow:(size_t)bytesPerRow info:(CGBitmapInfo)info
{
    self = [super init];
    if (self) {
        _context = CGBitmapContextCreate(NULL, size.width, size.height, bitsPerComponent, bytesPerRow, NULL, info);
        if (!_context)
            return nil;
    }
    return self;
}
- (CGContextRef)context { return _context; }

- (UIImage *)imageMask:(BOOL)shouldInterpolate
{
    void *bytes = CGBitmapContextGetData(_context);
    size_t bytesPerRow = CGBitmapContextGetBytesPerRow(_context);
    size_t width = CGBitmapContextGetWidth(_context);
    size_t height = CGBitmapContextGetHeight(_context);
    size_t nbytes = bytesPerRow*height;
    size_t bitsPerComponent = CGBitmapContextGetBitsPerComponent(_context);
    size_t bitsPerPixel = CGBitmapContextGetBitsPerPixel(_context);
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, bytes, nbytes, NULL);
    CGImageRef image = CGImageMaskCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, dataProvider, NULL, shouldInterpolate);
    CGDataProviderRelease(dataProvider);
    UIImage *result = [UIImage imageWithCGImage:image];
    CGImageRelease(image);
    return result;
}

#include "cgcontext_methods.c"

@end

@interface DrawView : UIView
{
    NuBlock *_block;
    CGContextRef _context;
}
@end

@implementation DrawView

- (void)dealloc
{
    NSLog(@"DrawView dealloc %p", self);
    [_block release];
    _block = nil;
    [super dealloc];
}

- (id)block { return _block; }
- (void)setBlock:(NuBlock *)block
{
    [block retain];
    [_block release];
    _block = block;
    [self setNeedsDisplay];
}

- (CGContextRef)context { return _context; }
- (void)setContext:(CGContextRef)context { _context = context; }

- (void)drawRect:(CGRect)rect
{
    if (self.block) {
        _context = UIGraphicsGetCurrentContext();
        eval_block(self.block, self, nil);
        _context = nil;
    }
}

#include "cgcontext_methods.c"

- (void)drawAttributedString:(CFAttributedString *)string path:(CGMutablePath *)path
{
    // Create the framesetter with the attributed string.
    CTFramesetterRef framesetter =
    CTFramesetterCreateWithAttributedString([string string]);

    // Create the frame and draw it into the graphics context
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), [path path], NULL);
    CFRelease(framesetter);
    CTFrameDraw(frame, _context);
    CFRelease(frame);
}

@end

@interface AnimatedView : DrawView
@property (nonatomic, retain) CADisplayLink *displayLink;
@end

@implementation AnimatedView
@synthesize displayLink = _displayLink;

- (void)dealloc
{
    NSLog(@"AnimatedView dealloc %p", self);
    [self.displayLink invalidate];
    self.displayLink = nil;
    [super dealloc];
}

- (id)block { return _block; }
- (void)setBlock:(NuBlock *)block
{
    [super setBlock:block];
    if (!self.displayLink) {
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(setNeedsDisplay)]];
        [invocation setTarget:self];
        [invocation setSelector:@selector(setNeedsDisplay)];
        self.displayLink = [CADisplayLink displayLinkWithTarget:invocation selector:@selector(invoke)];
        objc_setAssociatedObject(self.displayLink, @"ios6sucks", invocation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

/*- (void)setFrame:(CGRect)frame
{
    prn([NSString stringWithFormat:@"AnimatedView setFrame:%f %f %f %f", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height]);
//    CGRect r = frame;
//    if (r.size.height > 44.0)
//        r.origin.y = 44.0 - r.size.height;
    [super setFrame:frame];
}*/


@end


@interface FileDictionary : NSObject
@property (nonatomic, retain) NSString *path;
@end

@implementation FileDictionary
@synthesize path = _path;

- (id)valueForKey:(NSString *)key
{
    NSString *file = [self.path stringByAppendingPathComponent:key];
    if ([file isDirectory]) {
        FileDictionary *dict = [[[FileDictionary alloc] init] autorelease];
        dict.path = file;
        return dict;
    }
    return [NSString stringWithContentsOfFile:[self.path stringByAppendingPathComponent:key] encoding:NSUTF8StringEncoding error:nil];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    if (nu_objectIsKindOfClass(value, [NSString class])) {
        [(NSString *)value writeToFile:[self.path stringByAppendingPathComponent:key] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        NSLog(@"FileDictionary value is not an NSString, setValue %@ forKey %@", value, key);
    }
}

@end

