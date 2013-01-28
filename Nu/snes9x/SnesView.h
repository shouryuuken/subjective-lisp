/*
 * This file is part of iMAME4all.
 *
 * Copyright (C) 2010 David Valdeita (Seleuco)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 * In addition, as a special exception, Seleuco
 * gives permission to link the code of this program with
 * the MAME library (or with modified versions of MAME that use the
 * same license as MAME), and distribute linked combinations including
 * the two.  You must obey the GNU General Public License in all
 * respects for all of the code used other than MAME.  If you modify
 * this file, you may extend this exception to your version of the
 * file, but you are not obligated to do so.  If you do not wish to
 * do so, delete this exception statement from your version.
 */

#import <UIKit/UIKit.h>

#import <Foundation/Foundation.h>
#import "CoreSurface.h"
#import <QuartzCore/CALayer.h>

#import <pthread.h>
#import <sched.h>
#import <unistd.h>
#import <sys/time.h>

#import <CoreMotion/CoreMotion.h>

#import "Misc.h"

@interface SnesView : UIView <UIAlertViewDelegate>
{
    CMMotionManager *motionManager;
    
    double filteredAccelerationX;
    double filteredAccelerationY;
    double filteredAccelerationZ;
    
    uint16_t accel_buttons;
    uint16_t accel_freq;
    float accel_peak;
    
    uint16_t touch_buttons;
    uint16_t gesture_buttons;
    int gesture_length;
    UITapGestureRecognizer *grTap;
    UISwipeGestureRecognizer *grSwipeUp;
    UISwipeGestureRecognizer *grSwipeDown;
    UISwipeGestureRecognizer *grSwipeLeft;
    UISwipeGestureRecognizer *grSwipeRight;
}
- (void)handleTouches:(NSSet *)touches withEvent:(UIEvent *)event;
@property (nonatomic, assign) double filter;
@property (nonatomic, assign) float reverseX;
@property (nonatomic, assign) float reverseY;
@property (nonatomic, assign) float deadZoneX;
@property (nonatomic, assign) float deadZoneY;
@property (nonatomic, readonly) uint16_t gestureButtons;
@property (nonatomic, readonly) uint16_t joypadButtons;
@property (nonatomic, retain) UIView *screenView;
@property (nonatomic, retain) UIView *helpView;
@end
