//
//  Helper.c
//  Artnestopia
//
//  Created by arthur on 22/01/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "Helper.h"

UIFont *fontWithName(NSString *fontName, NSString *str, CGSize fits)
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

UIImage *imageWithPileOfPoo(CGSize size)
{
    NSString *str = @"\ue05a";
    UIFont *font = fontWithName(@"AppleColorEmoji", str, size);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
/*    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIColor colorWithRed:0.875 green:0.875 blue:0.5 alpha:1.0] set];
    CGContextFillRect(context, CGRectMake(0.0, 0.0, size.width, size.height));*/
    CGSize pileOfPooSize = [str sizeWithFont:font];
    [str drawInRect:CGRectMake((size.width-pileOfPooSize.width)/2.0, (size.height-pileOfPooSize.height)/2.0, pileOfPooSize.width, pileOfPooSize.height) withFont:font];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIFont *emojiFontOfSize(CGFloat size)
{
    return [UIFont fontWithName:@"AppleColorEmoji" size:size];
}

BOOL isTablet()
{
    return ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? YES : NO;
}

NSString *getPathInBundle(NSString *name, NSString *extension)
{
    return [[NSBundle mainBundle] pathForResource:name ofType:extension];
}


NSString *getDisplayNameForPath(NSString *path)
{
    return [[path lastPathComponent] stringByDeletingPathExtension];
}

NSString *getDocsPath()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

BOOL containsString(NSString *str, NSString *match)
{
    NSRange r = [str rangeOfString:match];
    return (r.location == NSNotFound) ? NO : YES;
}

const char *getCString(NSString *str)
{
    static char buf[1024];
    [str getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}

NSString *getPathInDocs(NSString *path)
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths objectAtIndex:0] stringByAppendingPathComponent:path];
}
