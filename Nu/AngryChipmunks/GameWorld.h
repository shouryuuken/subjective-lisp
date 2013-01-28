//
//  GameWorld.h
//  AngryChipmunks
//
//  Created by Scott Lembcke on 11/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "cocos2d.h"
#import "ObjectiveChipmunk.h"

@class CCLayer;
@class GameObject;
@class ChipmunkSpace;

// Yay, the vaunted GameWorld class.
// This is where all the game logic goes and along with GameObject it binds Cocos2D and Chipmunk together nicely.
@interface GameWorld : CCLayer {
	NSMutableArray *gameObjects;
	
	ChipmunkSpace *space;
  CCSpriteBatchNode  *spritesheet;
		
	bool restarting;
    
    ChipmunkMultiGrab *_multiGrab;
}

+(id) scene;

-(void) add:(GameObject *)gameObject;
-(void) remove:(GameObject *)gameObject;



@end
