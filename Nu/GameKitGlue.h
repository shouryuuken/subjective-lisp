//
//  GameKitGlue.h
//  Nu
//
//  Created by arthur on 7/01/13.
//
//

#import <GameKit/GameKit.h>

@interface GameKitHelper : NSObject
@property (nonatomic, assign) id delegate;
@property (nonatomic, readonly) NSError *lastError;
@property (nonatomic, retain) GKTurnBasedMatch *match;
+ (id)sharedGameKitHelper;
- (void)authenticateLocalPlayer;
@end