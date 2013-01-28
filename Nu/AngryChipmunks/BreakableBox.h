//
//  BreakableBox.h
//  AngryChipmunks
//
//  Created by Andy Korth on 11/19/10.
//  Copyright 2010 Howling Moon Software. All rights reserved.
//

#import "GameObject.h"

@class CCSprite;

// Create a box that can be broken.
// Callbacks in the GameWorld calculate the damage applied to the box.
@interface Sprite : GameObject
{
    CCSprite *_sprite;
    ChipmunkCocosBody *_body;
}
@end
