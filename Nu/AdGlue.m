//
//  AdGlue.m
//  Nu
//
//  Created by arthur on 30/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GADBannerView.h"

@interface AdGlue : NSObject

@end

@implementation AdGlue

+ (GADBannerView *)GADBannerView
{
    return [[[GADBannerView alloc] initWithAdSize:kGADAdSizeBanner] autorelease];
}


@end
