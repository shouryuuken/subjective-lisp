#import "ChipmunkCocosBody.h"


@implementation ChipmunkCocosBody

@synthesize syncedNodes = _syncedNodes;

static void
UpdatePosition(cpBody *body, cpFloat dt)
{
	cpBodyUpdatePosition(body, dt);
	
	for(CCNode *node in ((ChipmunkCocosBody *)body->data)->_syncedNodes){
		node.position = body->p;
		node.rotation = CC_RADIANS_TO_DEGREES(-body->a);
	}
}

- (id)initWithMass:(cpFloat)mass andMoment:(cpFloat)moment
{
	if((self = [super initWithMass:mass andMoment:moment])){
		self.body->position_func = UpdatePosition;
	}
	
	return self;
}

- (void)dealloc
{
	self.syncedNodes = nil;
	
	[super dealloc];
}

@end
