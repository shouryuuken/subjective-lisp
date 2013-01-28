//
//  HelpView.m
//  Artsnes9x
//
//  Created by arthur on 4/02/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "HelpView.h"
#import "Helper.h"

void addHelpBox(UIView *v, CGFloat x, CGFloat y, CGFloat w, CGFloat h, UIColor *color, NSString *text);
void addHelpBox(UIView *v, CGFloat x, CGFloat y, CGFloat w, CGFloat h, UIColor *color, NSString *text)
{
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(x, y, w, h)] autorelease];
    l.backgroundColor = (color) ? [color colorWithAlphaComponent:0.5] : [UIColor clearColor];
    l.text = text;
    l.font = emojiFontOfSize(12.0);
    l.textColor = [UIColor whiteColor];
    if (containsString(text, @"\n")) {
        l.numberOfLines = 0;
    } else {
        l.adjustsFontSizeToFitWidth = YES;
    }
    l.textAlignment = UITextAlignmentCenter;
    [v addSubview:l];
}

UIView *helpForZapper(CGRect frame)
{
    UIView *v = [[[UIView alloc] initWithFrame:frame] autorelease];
    addHelpBox(v, 0.0, 0.0, frame.size.width, frame.size.height, [UIColor yellowColor], @"Tap to shoot\n\nTo aim, look through camera");
    v.backgroundColor = [UIColor clearColor];
    v.userInteractionEnabled = NO;
    return v;
}

UIView *helpForTouch(CGRect frame)
{
    UIView *v = [[[UIView alloc] initWithFrame:frame] autorelease];
    addHelpBox(v, frame.size.width*0.05, 0.0, frame.size.width*0.90, frame.size.height*0.55, nil, @"\n\n\n\nUp: Touch");
    addHelpBox(v, 0.0, 0.0, frame.size.width*0.05, frame.size.height, [UIColor colorWithRed:0.25 green:0.25 blue:0.0 alpha:1.0], @"Q\nu\ni\nt\n:\n\ue234\n\nL\ne\nf\nt\n:\nT\no\nu\nc\nh");
    addHelpBox(v, frame.size.width*0.05, frame.size.height*0.95, frame.size.width*0.9, frame.size.height*0.05, nil, @"Down: Touch");
    addHelpBox(v, frame.size.width*0.05+frame.size.width*0.90, 0.0, frame.size.width*0.05, frame.size.height, [UIColor colorWithRed:0.25 green:0.25 blue:0.0 alpha:1.0], @"R\ni\ng\nh\nt\n:\nT\no\nu\nc\nh");
    addHelpBox(v, frame.size.width*0.05, frame.size.height*0.55, frame.size.width*0.45, frame.size.height*0.40, [UIColor colorWithRed:0.0 green:0.5 blue:0.0 alpha:1.0], @"B: Touch\n\nReset: Swipe \ue235");
    addHelpBox(v, frame.size.width*0.5, frame.size.height*0.55, frame.size.width*0.45, frame.size.height*0.40, [UIColor colorWithRed:0.0 green:0.0 blue:0.5 alpha:1.0], @"A: Touch\n\nSELECT: Swipe \ue235\nSTART: Swipe \ue234");
    v.backgroundColor = [[UIColor yellowColor] colorWithAlphaComponent:0.5];
    v.userInteractionEnabled = NO;
    return v;
}
