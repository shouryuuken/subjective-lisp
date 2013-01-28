//
//  Helper.h
//  Artnestopia
//
//  Created by arthur on 22/01/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

/* Emoji Unicode
    Toilet = @"\ue140"
    PileOfPoo = @"\ue05a"
*/

UIFont *fontWithName(NSString *fontName, NSString *str, CGSize fits);
UIImage *imageWithPileOfPoo(CGSize size);
UIFont *emojiFontOfSize(CGFloat size);
BOOL isTablet(void);
NSString *getPathInBundle(NSString *name, NSString *extension);
NSString *getDisplayNameForPath(NSString *path);
NSString *getDocsPath(void);
BOOL containsString(NSString *str, NSString *match);
const char *getCString(NSString *str);
NSString *getPathInDocs(NSString *path);
