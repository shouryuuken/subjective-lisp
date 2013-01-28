//
//  Image.m
//  Nu
//
//  Created by arthur on 11/09/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGColorSpace.h>

@interface Image : NSObject

@end

@implementation Image

+ (UIImage *)settingsIcon
{    
    /*    int mult = 1;
     int imagesize = 20;
     int circlesizemult = 16;
     int linewidthmult = 4;
     int linelengthmult = 8;
     int holesizemult = 6;
     int nlines = 8;*/
    
    int mult = 1;
    int offsety = 1 * mult;
    int imagesize = 20;
    int circlesizemult = 14;
    int linewidthmult = 4;
    int linelengthmult = 7;
    int holesizemult = 6;
    int nlines = 8;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake((float)imagesize*mult, (float)imagesize*mult), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIColor clearColor] set];
    CGContextFillRect(context, CGRectMake(0, 0, imagesize*mult, imagesize*mult));
    [[UIColor blackColor] set];
    int circlesize = mult*circlesizemult;
    int circleindent = (imagesize*mult-circlesize)/2+circlesize%2;
    CGContextFillEllipseInRect(context, CGRectMake(circleindent, offsety+circleindent, circlesize, circlesize));
    
    int linewidth = mult*linewidthmult;
    int linelength = mult*linelengthmult;
    int lineoffset = imagesize*mult/2;
    CGContextSetLineWidth(context, linewidth);
    CGContextSetLineCap(context, kCGLineCapSquare);
    for(int i=0; i<nlines; i++) {
        double rad = M_PI*2*(double)i/(double)nlines;
        double x = cos(rad) * linelength;
        double y = sin(rad) * linelength;
        CGContextMoveToPoint(context, lineoffset, offsety+lineoffset);
        CGContextAddLineToPoint(context, lineoffset+x, offsety+lineoffset+y);
        CGContextStrokePath(context);
    }
    
    CGContextSetBlendMode(context, kCGBlendModeClear);
    int holesize = mult*holesizemult;
    int holeindent = (imagesize*mult-holesize)/2;
    CGContextFillEllipseInRect(context, CGRectMake(holeindent, offsety+holeindent, holesize, holesize));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSLog(@"imgSettingsIcon scale %.1f", image.scale);
    return image;
}

+ (UIImage *)maximizeIcon
{    
    int mult = 1;
    int iconsize = 20;
    int clearwidth = 16;
    int stemwidth = 4;
    int stemlength = 8;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake((float)iconsize, (float)iconsize), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIColor blackColor] set];
    CGContextFillRect(context, CGRectMake(0, 0, iconsize*mult, iconsize*mult));
    //    [[UIColor whiteColor] set];
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextSetLineWidth(context, clearwidth*mult);
    CGContextMoveToPoint(context, 0, 0);
    CGContextAddLineToPoint(context, iconsize*mult, iconsize*mult);
    CGContextStrokePath(context);
    //    [[UIColor blackColor] set];
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextSetLineWidth(context, stemwidth*mult);
    CGContextMoveToPoint(context, 0, iconsize*mult);
    CGContextAddLineToPoint(context, stemlength*mult, (iconsize-stemlength)*mult);
    CGContextStrokePath(context);
    CGContextMoveToPoint(context, iconsize*mult, 0);
    CGContextAddLineToPoint(context, (iconsize-stemlength)*mult, stemlength*mult);
    CGContextStrokePath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)minimizeIcon
{    
    int mult = 1;
    int boxsize = 11;
    int cornersize = 13;
    int stemwidth = 5;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20.0, 20.0), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    void (^draw_corner_lines)(int) = ^(int linewidth) {
        CGContextSetLineWidth(context, linewidth*mult);
        CGContextMoveToPoint(context, -20*mult, 0*mult);
        CGContextAddLineToPoint(context, 20*mult, 40*mult);
        CGContextStrokePath(context);
        CGContextMoveToPoint(context, 0*mult, -20*mult);
        CGContextAddLineToPoint(context, 40*mult, 20*mult);
        CGContextStrokePath(context);
    };
    
    [[UIColor blackColor] set];
    CGContextFillRect(context, CGRectMake(0, 0, 20*mult, 20*mult));
    
    CGContextSetBlendMode(context, kCGBlendModeClear);
    draw_corner_lines(cornersize);
    
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextSetLineWidth(context, stemwidth*mult);
    CGContextMoveToPoint(context, 0, 20*mult);
    CGContextAddLineToPoint(context, 20*mult, 0);
    CGContextStrokePath(context);
    
    CGContextSetBlendMode(context, kCGBlendModeClear);
    draw_corner_lines(stemwidth);
    
    CGContextFillRect(context, CGRectMake(0, 0, boxsize*mult, boxsize*mult));
    CGContextFillRect(context, CGRectMake((20-boxsize)*mult, (20-boxsize)*mult, 20*mult, 20*mult));
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

void drawDoubleArrowIconToContext(int scale)
{
    int yoffset = 2*scale;
    int cornersize = 15;
    int vertlinewidth = 4;
    int horizlinewidth = 6;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    void (^draw_corner_lines)(int) = ^(int linewidth) {
        CGContextSetLineWidth(context, linewidth*scale);
        CGContextMoveToPoint(context, -20*scale, yoffset);
        CGContextAddLineToPoint(context, 20*scale, yoffset+40*scale);
        CGContextStrokePath(context);
        CGContextMoveToPoint(context, 0*scale, yoffset-20*scale);
        CGContextAddLineToPoint(context, 40*scale, yoffset+20*scale);
        CGContextStrokePath(context);
        CGContextMoveToPoint(context, -20*scale, yoffset+20*scale);
        CGContextAddLineToPoint(context, 20*scale, yoffset-20*scale);
        CGContextStrokePath(context);
        CGContextMoveToPoint(context, 0*scale, yoffset+40*scale);
        CGContextAddLineToPoint(context, 40*scale, yoffset);
        CGContextStrokePath(context);
        
    };
    
    [[UIColor blackColor] set];
    CGContextFillRect(context, CGRectMake(0, 0, 20*scale, 20*scale));
    
    //    [[UIColor whiteColor] set];
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextSetLineWidth(context, vertlinewidth*scale);
    CGContextMoveToPoint(context, 10*scale, 0);
    CGContextAddLineToPoint(context, 10*scale, 20*scale);
    CGContextStrokePath(context);
    
    //    [[UIColor blackColor] set];
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextSetLineWidth(context, horizlinewidth*scale);
    CGContextMoveToPoint(context, 0, yoffset+10*scale);
    CGContextAddLineToPoint(context, 20*scale, yoffset+10*scale);
    CGContextStrokePath(context);
    
    //    [[UIColor whiteColor] set];
    CGContextSetBlendMode(context, kCGBlendModeClear);
    draw_corner_lines(cornersize);
}

+ (UIImage *)doubleArrowIcon
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20.0, 20.0), NO, 0.0);
    drawDoubleArrowIconToContext(1);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

void drawTableOfContentsIconToContext(int scale)
{
    int horizlinewidth = 2;
    int horizspacing = 5;
    int vertlinewidth = 2;
    float vertlinepos = 3.5;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
//    [[UIColor whiteColor] set];
//    CGContextFillRect(context, CGRectMake(0, 0, 20*scale, 20*scale));
    
    
    [[UIColor blackColor] set];
    CGContextSetLineWidth(context, horizlinewidth*scale);
    CGContextMoveToPoint(context, 0, 10*scale);
    CGContextAddLineToPoint(context, 20*scale, 10*scale);
    CGContextStrokePath(context);
    
    CGContextMoveToPoint(context, 0, (10-horizspacing)*scale);
    CGContextAddLineToPoint(context, 20*scale, (10-horizspacing)*scale);
    CGContextStrokePath(context);
    
    CGContextMoveToPoint(context, 0, (10+horizspacing)*scale);
    CGContextAddLineToPoint(context, 20*scale, (10+horizspacing)*scale);
    CGContextStrokePath(context);
    
//    [[UIColor whiteColor] set];
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextSetLineWidth(context, vertlinewidth*scale);
    CGContextMoveToPoint(context, vertlinepos*scale, 0);
    CGContextAddLineToPoint(context, vertlinepos*scale, 20*scale);
    CGContextStrokePath(context);
}

+ (UIImage *)tableOfContentsIcon
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20.0, 20.0), NO, 0.0);
    drawTableOfContentsIconToContext(1);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)imageWithRoundedRect:(NSString *)text sizeText:(NSString *)sizeText font:(UIFont *)font radius:(CGFloat)radius borderwidth:(CGFloat)borderwidth borderheight:(CGFloat)borderheight textColor:(UIColor *)textColor boxColor:(UIColor *)boxColor bgColor:(UIColor *)bgColor
{
    CGSize boxSize = [sizeText sizeWithFont:font];
    CGSize textSize = [text sizeWithFont:font];
    CGRect rrect = CGRectMake(0.0, 0.0, boxSize.width+borderwidth, boxSize.height+borderheight);
    
    UIGraphicsBeginImageContextWithOptions(rrect.size, NO, 0.0);
    CGContextRef context=UIGraphicsGetCurrentContext();
    
    [boxColor set];
    CGContextSetStrokeColorWithColor(context, bgColor.CGColor); 
    
    CGFloat minx = CGRectGetMinX(rrect), midx = CGRectGetMidX(rrect), maxx = CGRectGetMaxX(rrect); 
    CGFloat miny = CGRectGetMinY(rrect), midy = CGRectGetMidY(rrect), maxy = CGRectGetMaxY(rrect); 
    CGContextMoveToPoint(context, minx, midy); 
    CGContextAddArcToPoint(context, minx, miny, midx, miny, radius); 
    CGContextAddArcToPoint(context, maxx, miny, maxx, midy, radius); 
    CGContextAddArcToPoint(context, maxx, maxy, midx, maxy, radius); 
    CGContextAddArcToPoint(context, minx, maxy, minx, midy, radius); 
    CGContextClosePath(context); 
    CGContextDrawPath(context, kCGPathFillStroke); 
    
    if (textColor) {
        [textColor set];
    } else {
        CGContextSetBlendMode(context, kCGBlendModeClear);
    }
    [text drawInRect:CGRectMake((rrect.size.width-textSize.width)/2, (rrect.size.height-textSize.height)/2, textSize.width, textSize.height) withFont:font];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)numberImageWithRoundedRect:(int)val maxVal:(int)maxVal textColor:(UIColor *)textColor boxColor:(UIColor *)boxColor bgColor:(UIColor *)bgColor
{
    return [self imageWithRoundedRect:[NSString stringWithFormat:@"%d", val] sizeText:[NSString stringWithFormat:@"%d", maxVal] font:[UIFont boldSystemFontOfSize:14.0] radius:5.0 borderwidth:8.0 borderheight:2.0 textColor:textColor boxColor:boxColor bgColor:bgColor];
}

void drawPhotosIconToContext(int scale)
{    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //    [[UIColor whiteColor] set];
    //    CGContextFillRect(context, CGRectMake(0, 0, 20*scale, 20*scale));
    
    
    [[UIColor blackColor] set];
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextFillRect(context, CGRectMake(0, 0, 20*scale, 20*scale));
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextFillRect(context, CGRectMake(2*scale, 3*scale, 18*scale, 13*scale));
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextFillRect(context, CGRectMake(3*scale, 4*scale, 16*scale, 11*scale));
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextFillRect(context, CGRectMake(0*scale, 5*scale, 18*scale, 13*scale));
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextFillRect(context, CGRectMake(1*scale, 6*scale, 16*scale, 11*scale));
    
}

+ (UIImage *)photosIcon
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20.0, 20.0), NO, 0.0);
    drawPhotosIconToContext(1);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
