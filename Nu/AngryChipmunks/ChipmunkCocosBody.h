#import "ObjectiveChipmunk.h"
#import "cocos2d.h"

@interface ChipmunkCocosBody : ChipmunkBody {
@private
	NSArray *_syncedNodes;
}

@property(nonatomic, retain) NSArray *syncedNodes;

@end
