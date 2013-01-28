//
//  GameKitGlue.m
//  Nu
//
//  Created by arthur on 7/01/13.
//
//


#import "GameKitGlue.h"

@interface GameKitHelper() <GKGameCenterControllerDelegate, GKTurnBasedMatchmakerViewControllerDelegate, GKTurnBasedEventHandlerDelegate>
{
    BOOL _gameCenterFeaturesEnabled;
}
@end

@implementation GameKitHelper
@synthesize delegate = _delegate;
@synthesize lastError = _lastError;
@synthesize match = _match;

+ (id)sharedGameKitHelper
{
    static GameKitHelper *sharedGameKitHelper;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedGameKitHelper = [[GameKitHelper alloc] init];
    });
    return sharedGameKitHelper;
}

- (void)authenticateLocalPlayer
{
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    localPlayer.authenticateHandler = ^(UIViewController *viewController, NSError *error)
    {
        [self setLastError:error];
        if (localPlayer.authenticated) {
            _gameCenterFeaturesEnabled = YES;
            NSLog(@"_gameCenterFeaturesEnabled = YES");
            [[GKTurnBasedEventHandler sharedTurnBasedEventHandler] setDelegate:self];
            [self performSelectorOnMainThread:@selector(presentMatchMaker) withObject:nil waitUntilDone:NO];
        } else if (viewController) {
            NSLog(@"[self presentViewController:viewController]");
            [self presentViewController:viewController];
        } else {
            _gameCenterFeaturesEnabled = NO;
            NSLog(@"_gameCenterFeaturesEnabled = NO");
        }
    };
}

- (void)setLastError:(NSError *)error
{
    _lastError = [error copy];
    if (_lastError) {
        NSLog(@"GameKitHelper error: %@", [[_lastError userInfo] description]);
    }
}

- (UIViewController *)getRootViewController
{
    return [[[[UIApplication sharedApplication] delegate] window] rootViewController];
}

- (void)presentViewController:(UIViewController *)vc
{
    UIViewController *rootVC = [self getRootViewController];
    [rootVC presentViewController:vc animated:YES completion:nil];
}

- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)vc
{
    NSLog(@"gameCenterViewControllerDidFinish");
    [vc dismissViewControllerAnimated:YES completion:nil];
}

- (GKMatchRequest *)matchRequestWithMin:(int)min max:(int)max
{
    GKMatchRequest *req = [[[GKMatchRequest alloc] init] autorelease];
    req.minPlayers = min;
    req.maxPlayers = max;
    return req;
}

- (void)presentMatchMaker
{
    GKMatchRequest *req = [self matchRequestWithMin:2 max:4];
    GKTurnBasedMatchmakerViewController *vc = [[[GKTurnBasedMatchmakerViewController alloc] initWithMatchRequest:req] autorelease];
    vc.turnBasedMatchmakerDelegate = self;
    [self presentViewController:vc];
}

- (void)turnBasedMatchmakerViewController:(GKTurnBasedMatchmakerViewController *)vc didFailWithError:(NSError *)error
{
    NSLog(@"turnBasedMatchmakerViewController didFailWithError");
    [vc dismissViewControllerAnimated:YES completion:nil];
}

- (void)turnBasedMatchmakerViewController:(GKTurnBasedMatchmakerViewController *)vc didFindMatch:(GKTurnBasedMatch *)match
{
    NSLog(@"turnBasedMatchmakerViewController didFindMatch");
    [vc dismissViewControllerAnimated:YES completion:nil];
    [self handleMatch:match];
}

- (void)turnBasedMatchmakerViewController:(GKTurnBasedMatchmakerViewController *)vc playerQuitForMatch:(GKTurnBasedMatch *)match
{
    NSLog(@"turnBasedMatchmakerViewController playerQuitForMatch");
    [vc dismissViewControllerAnimated:YES completion:nil];
}

- (void)turnBasedMatchmakerViewControllerWasCancelled:(GKTurnBasedMatchmakerViewController *)vc
{
    NSLog(@"turnBasedMatchmakerViewController wasCancelled");
    [vc dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleInviteFromGameCenter:(NSArray *)playersToInvite
{
    NSLog(@"handleInviteFromGameCenter");
}

- (void)handleTurnEventForMatch:(GKTurnBasedMatch *)match didBecomeActive:(BOOL)didBecomeActive
{
    NSLog(@"handleTurnEventForMatch");
}

- (void)handleMatchEnded:(GKTurnBasedMatch *)match
{
    NSLog(@"handleMatchEnded");
}

- (void)handleMatch:(GKTurnBasedMatch *)match
{
    [match loadMatchDataWithCompletionHandler:^(NSData *matchData, NSError *error) {
        NSLog(@"matchData loaded");
        self.match = match;
    }];
}

@end