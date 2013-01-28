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

NSString *getDocsPath()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths objectAtIndex:0];
}

NSString *getPathInDocs(NSString *path)
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths objectAtIndex:0] stringByAppendingPathComponent:path];
}

NSString *getPathInBundle(NSString *name, NSString *extension)
{
    return [[NSBundle mainBundle] pathForResource:name ofType:extension];
}

UIFont *emojiFontOfSize(CGFloat size)
{
    return [UIFont fontWithName:@"AppleColorEmoji" size:size];
}

const char *getPathInBundleCString(NSString *name, NSString *extension)
{
    static char buf[1024];
    NSString *str = getPathInBundle(name, extension);
    [str getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}

const char *getDocsPathCString()
{
    static char buf[1024];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    [[paths objectAtIndex:0] getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}

const char *getPathBaseNameCString(const char *path)
{
    static char buf[1024];
    NSString *str = [NSString stringWithCString:path encoding:NSASCIIStringEncoding];
    [[[str lastPathComponent] stringByDeletingPathExtension] getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}

const char *getPathInDocsCString(const char *path)
{
    static char buf[1024];
    NSString *str = [NSString stringWithCString:path encoding:NSASCIIStringEncoding];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    str = [[paths objectAtIndex:0] stringByAppendingPathComponent:str];
    [str getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}
    
const char *getPathWithExtensionCString(const char *path, const char *extension)
{
    static char buf[1024];
    NSString *str = [NSString stringWithCString:path encoding:NSASCIIStringEncoding];
    [[str stringByAppendingString:[NSString stringWithCString:extension encoding:NSASCIIStringEncoding]] getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}

NSMutableArray *readContentsOfPath(NSString *path)
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *arr = [[[NSMutableArray alloc] init] autorelease];
    NSDirectoryEnumerator *dirEnum =[fm enumeratorAtPath:path];
    NSString *file;
    while (file = [dirEnum nextObject]) {
        if ([[dirEnum fileAttributes] fileType] == NSFileTypeRegular) {
            [arr addObject:getPathInDocs(file)];
        }
    }
    return arr;
}

void sortFileArrayAlphabetically(NSMutableArray *arr)
{
    NSComparator cmp = ^(NSString *a, NSString *b) {
        if ([a.lowercaseString hasPrefix:[b.lowercaseString stringByDeletingPathExtension]])
            return NSOrderedDescending;
        if ([b.lowercaseString hasPrefix:[a.lowercaseString stringByDeletingPathExtension]])
            return NSOrderedAscending;
        return [a localizedCaseInsensitiveCompare:b];
    };
    [arr sortUsingComparator:^(id a, id b) { return cmp(a, b); }];
}

NSString *getDisplayNameForPath(NSString *path)
{
    return [[path lastPathComponent] stringByDeletingPathExtension];
}

const char *getCString(NSString *str)
{
    static char buf[1024];
    [str getCString:buf maxLength:1024 encoding:NSASCIIStringEncoding];
    return buf;
}

NSString *stringFromSettings(NSString *key, NSString *val)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *str = [defaults stringForKey:key];
    return (str) ? str : val;
}

void saveStringToSettings(NSString *key, NSString *val)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:val forKey:key];
}

BOOL containsString(NSString *str, NSString *match)
{
    NSRange r = [str rangeOfString:match];
    return (r.location == NSNotFound) ? NO : YES;
}
