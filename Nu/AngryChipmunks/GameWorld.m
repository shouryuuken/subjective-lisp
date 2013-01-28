//
//  GameWorld.m
//  AngryChipmunks
//
//  Created by Scott Lembcke on 11/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GameWorld.h"

#import "Physics.h"

#import "BreakableBox.h"
#import "ChipmunkDebugNode.h"

#import "ChipmunkHastySpace.h"

@interface GameWorld()

@end

@implementation GameWorld

+(id) scene
{
	return [GameWorld node];
}


// Add an entire GameObject to  GameWorld, physics, sprites, everthing.
-(void) add:(GameObject *)gameObject{
	// Adding a gameobject that implements the ChipmunkObject protocol is easy
	// Using smartAdd: instead of just add: makes it safe from within a callback.
	// Just make sure you understand that smartAdd: will delay the addition when used in a callback.
  [space smartAdd:gameObject];
	
	// Add all the sprites
  for(CCSprite *sprite in gameObject.sprites){
    [spritesheet addChild:sprite];
  }
	
	[gameObjects addObject:gameObject];
	gameObject.world = self;
}

// Should be no surprises here.
-(void) remove:(GameObject *)gameObject{
  [space smartRemove:gameObject];
	
  for(CCSprite* sprite in gameObject.sprites){
    [spritesheet removeChild:sprite cleanup:TRUE];
  }
	
	[gameObjects removeObject:gameObject];
	gameObject.world = nil;
}

-(void) step: (ccTime) delta
{
	// Update the physics using the fixed time step.
	// Here the fixed timestep should match the framerate.
	// A slightly better solution is to decouple your updates and drawing.
	// That is beyond the scope of this example, but a good tutorial can be found here: http://gafferongames.com/game-physics/fix-your-timestep/
	[space step:FIXED_TIMESTEP];
}

#define GRABABLE_MASK_BIT (1<<31)

-(void)addDomino:(cpVect)pos width:(cpFloat)width height:(cpFloat)height flipped:(bool)flipped
{
    cpFloat mass = 1.0f;
    ChipmunkBody *body = [space add:[ChipmunkBody bodyWithMass:mass andMoment:cpMomentForBox(mass, width, height)]];
    body.pos = pos;


    ChipmunkShape *shape = (flipped ? [ChipmunkPolyShape boxWithBody:body width:height height:width]
                            : [ChipmunkPolyShape boxWithBody:body width:width height:height]);
    [space add:shape];
    shape.elasticity = 0.0f;
    shape.friction = 0.6f;
}

-(id) init
{
	if((self = [super init])){
		self.isTouchEnabled = YES;

        CGSize screensize = [[CCDirector sharedDirector] winSize];
		CGFloat screenw = screensize.width;
        CGFloat screenh = screensize.height;
		gameObjects = [[NSMutableArray alloc] init];

		space = [[ChipmunkHastySpace alloc] init];
		space.data = self;

        cpFloat grabForce = 1e5;
        _multiGrab = [[ChipmunkMultiGrab alloc] initForSpace:space withSmoothing:cpfpow(0.3, 60) withGrabForce:grabForce];
        _multiGrab.layers = GRABABLE_MASK_BIT;
        _multiGrab.grabFriction = grabForce*0.1;
        _multiGrab.grabRotaryFriction = 1e3;
        _multiGrab.grabRadius = 20.0;
        _multiGrab.pushMass = 1.0;
        _multiGrab.pushFriction = 0.7;
        _multiGrab.pushMode = TRUE;

        space.iterations = 20;
        space.gravity = cpv(0, -300.0);
        space.sleepTimeThreshold = 0.5f;
        space.collisionSlop = 0.5f;
        
        // Add a floor.
        ChipmunkShape *shape = [space add:[ChipmunkSegmentShape segmentWithBody:space.staticBody from:cpv(0, 20) to:cpv(screenw, 20) radius:0]];
        shape.elasticity = 1.0;
        shape.friction = 1.0;
        		
        int rows = 15;
        cpFloat height = 20.0;
        cpFloat width = height/4.0;
        
        // Add the dominoes.
        for(int i=0; i < rows; i++){
            for(int j=0; j<(rows-i); j++){
                cpVect offset = cpv((j - (rows - 1 - i)*0.5f)*1.5f*height + screenw/2.0, ((rows-1-i) + 0.5f)*(height + 2*width) - width + 20 + screenh);
                [self addDomino:offset width:width height:height flipped:FALSE];
                [self addDomino:cpvadd(offset, cpv(0, (height + width)/2.0f)) width:width height:height flipped:TRUE];
                
                if(j == 0){
                    [self addDomino:cpvadd(offset, cpv(0.5f*(width - height), height + width)) width:width height:height flipped:FALSE];
                }
                
                if(j != rows - i - 1){
                    [self addDomino:cpvadd(offset, cpv(height*0.75f, (height + 3*width)/2.0f)) width:width height:height flipped:TRUE];
                } else {
                    [self addDomino:cpvadd(offset, cpv(0.5f*(height - width), height + width)) width:width height:height flipped:FALSE];
                }
            }
        }	
				
		// Load some misc Cocos2D things.
		spritesheet = [[CCSpriteBatchNode  alloc] initWithFile:@"spotmeow.png" capacity:100];
		[self addChild:spritesheet z:0];
		
		// This is a handy utility node that you can use to draw all the collision shapes for Chipmunk.
		[self addChild:[ChipmunkDebugNode debugNodeForSpace:space] z:100];
		
		// This is the 'level definition' if you will. Add a couple boxes and the goal box.
		[self add:[Sprite squareBox:cpv(screenw/2.0, 52) forSheet:spritesheet]];
        
        
        // create and initialize a Label
        CCLabelTTF *label = [CCLabelTTF labelWithString:@"Shake to reset" fontName:@"Helvetica" fontSize:12];
        label.position =  ccp( screenw /2 , 10.0 );
        [self addChild: label];
        
		[self schedule:@selector(step:)];
	}
	
	return self;
}

- (cpVect)touchLocation:(NSSet *)touches {
	UITouch *touch = [touches anyObject];
	return [[CCDirector sharedDirector] convertToGL:[touch locationInView:[touch view]]];
}

- (cpVect)convertTouch:(UITouch *)touch
{
    return [[CCDirector sharedDirector] convertToGL:[touch locationInView:[touch view]]];
}

- (void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    for(UITouch *touch in touches){
        [_multiGrab beginLocation:[self convertTouch:touch]];
    }
}

- (void)ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    for(UITouch *touch in touches){
        [_multiGrab updateLocation:[self convertTouch:touch]];
    }
}

- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    for(UITouch *touch in touches){
        [_multiGrab endLocation:[self convertTouch:touch]];
    }
}

- (void)ccTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self ccTouchesEnded:touches withEvent:event];
}

- (void) dealloc
{
	[gameObjects release];
	
	[space release];
	[spritesheet release];
	
	[super dealloc];
}

- (void)restart
{
	[[CCScheduler sharedScheduler] unscheduleSelector:_cmd forTarget:self];
	[[CCDirector sharedDirector] replaceScene:[GameWorld scene]];
}

- (void)scheduleRestart
{
	if(!restarting){
		[[CCScheduler sharedScheduler] scheduleSelector:@selector(restart) forTarget:self	interval:1.0f paused:FALSE];
		restarting = TRUE;
	}
}

@end
