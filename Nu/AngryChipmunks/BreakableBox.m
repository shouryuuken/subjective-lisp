#import "Physics.h"

#import "BreakableBox.h"

@implementation Sprite

- (id) initWithPos:(CGPoint) pos rect:(CGRect)r file:(NSString *)file collisionType:(cpCollisionType)type
{
  if((self = [super init])){
		
		// Build the physics objects as normal.
		// Technically you should retain the body when it's stored in an instance variable, but it's also being stored in the chipmunkObjects set on this object.
		cpFloat mass = r.size.width*r.size.height/4096.0f;
    _body = [ChipmunkCocosBody bodyWithMass:mass andMoment:cpMomentForBox(mass, r.size.width, r.size.height)];
    _body.pos = pos;
    
    ChipmunkShape * shape = [ChipmunkPolyShape boxWithBody:_body width:r.size.width height:r.size.height];
		shape.elasticity = 0.3f;
		shape.friction = 0.8f;
		shape.layers = PhysicsLayerGrabbable;
		// The collision type controls what collision callbacks will be triggered when this shape touches other shapes.
		// See more in GameWorld about how.
		shape.collisionType = type;
    shape.data = self;
    
		// Keep a reference to the sprite handy so we can split it up when it's broken.
     // _sprite = [CCSprite spriteWithBatchNode:sheet rect:r];
      _sprite = [CCSprite spriteWithFile:file];
		
		// Now the rest of the lines finish initializing the game object.
		
		// Create a set with all the physics objects in it. This fullfils the ChipmunkObject protocol.
    chipmunkObjects = [[NSArray alloc] initWithObjects:_body, shape, nil];
  	
		// Create an array of sprites
    sprites = [[NSArray alloc] initWithObjects:_sprite, nil];
		_body.syncedNodes = sprites;
  }
	
  return self;
    
    
}

+ (Sprite *) squareBox:(CGPoint)pos rect:(CGRect)r file:(NSString *)file
{  
	return [[[Sprite alloc] initWithPos:pos rect:r file:file collisionType:nil] autorelease];
}

- (CCSprite *)sprite { return _sprite; }
- (ChipmunkCocosBody *)body { return _body; }

@end
