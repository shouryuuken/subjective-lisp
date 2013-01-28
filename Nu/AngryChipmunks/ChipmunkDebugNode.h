//
//  ChipmunkDebugNode.h
//  AngryChipmunks
//
//  Created by Scott Lembcke on 11/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "cocos2d.h"
#import "ObjectiveChipmunk.h"

@interface ChipmunkDebugNode : CCNode {
	ChipmunkSpace *space;
}

@property (retain) ChipmunkSpace *space;

+ debugNodeForSpace:(ChipmunkSpace *)space;

@end
