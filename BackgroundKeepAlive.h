#pragma once

#import "PrivateHeaders.h"

@interface BackgroundKeepAlive : NSObject

+ (instancetype)sharedInstance;

- (BOOL)shouldKeepAliveBundle:(NSString *)bundleId
              selectedBundles:(NSArray *)selectedBundles
                     toggleOn:(BOOL)toggleOn
                 tweakEnabled:(BOOL)tweakEnabled;

- (void)keepAliveScene:(FBScene *)scene;
- (void)applyKeepAliveSettingsToScene:(FBScene *)scene
                             settings:(UIMutableApplicationSceneSettings *)settings;
- (void)updateNotificationStateForBundle:(NSString *)bundleId foreground:(BOOL)foreground;
- (void)cleanupForBundle:(NSString *)bundleId;
- (void)cleanupAll;
- (void)refreshAllKeptAliveScenes;

@end
