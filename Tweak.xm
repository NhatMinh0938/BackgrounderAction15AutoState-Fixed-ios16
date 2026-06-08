#import "Tweak.h"
#import "BackgroundKeepAlive.h"
#import "PrivateHeaders.h"

id module;
NSMutableDictionary *mainPreferenceDict;
BOOL isTweakEnabled;

static NSArray *selectedApps(void) {
    id apps = mainPreferenceDict[@"selectedApps"];
    return [apps isKindOfClass:[NSArray class]] ? apps : @[];
}

static BOOL isToggleOn(void) {
    return module != nil && [module isSelected];
}

static BOOL shouldKeepAliveBundle(NSString *bundleId) {
    return [[BackgroundKeepAlive sharedInstance] shouldKeepAliveBundle:bundleId
                                                       selectedBundles:selectedApps()
                                                            toggleOn:isToggleOn()
                                                        tweakEnabled:isTweakEnabled];
}

static void loadPrefs() {
    mainPreferenceDict = nil;
    mainPreferenceDict = [[NSMutableDictionary alloc] initWithContentsOfFile:GENERAL_PREFS];
    isTweakEnabled = [mainPreferenceDict objectForKey:@"isTweakEnabled"] ? [[mainPreferenceDict objectForKey:@"isTweakEnabled"] boolValue] : YES;
    if (!isTweakEnabled) {
        [[BackgroundKeepAlive sharedInstance] cleanupAll];
    }
}

static void keepAliveScenesForBundle(NSString *bundleId) {
    if (!shouldKeepAliveBundle(bundleId)) return;

    FBSceneManager *sceneManager = [%c(FBSceneManager) sharedInstance];
    NSMutableDictionary *scenesByID = [sceneManager valueForKey:@"_scenesByID"];
    [scenesByID enumerateKeysAndObjectsUsingBlock:^(NSString *sceneID, FBScene *scene, BOOL *stop) {
        if ([scene.clientProcess.identity.embeddedApplicationIdentifier isEqualToString:bundleId] && scene.valid) {
            [[BackgroundKeepAlive sharedInstance] keepAliveScene:scene];
        }
    }];
}

%group backgrounderStateGroup

%hook CCUIToggleViewController
- (void)setModule:(id)arg1 {
    %orig(arg1);
    if ([arg1 isKindOfClass:NSClassFromString(@"BackgrounderActionCC")]) {
        module = arg1;
    }
}
%end

%hook CCUIToggleModule
- (void)setSelected:(BOOL)selected {
    BOOL wasBackgrounder = [self isKindOfClass:NSClassFromString(@"BackgrounderActionCC")];
  %orig;
    if (wasBackgrounder && !selected) {
        [[BackgroundKeepAlive sharedInstance] cleanupAll];
    } else if (wasBackgrounder && selected) {
        for (NSString *bundleId in selectedApps()) {
            keepAliveScenesForBundle(bundleId);
        }
    }
}
%end

%hook SpringBoard
- (void)frontDisplayDidChange:(id)arg1 {
    %orig(arg1);
    if (isTweakEnabled == NO || ![arg1 isKindOfClass:NSClassFromString(@"SBApplication")]) {
        return;
    }

    NSString *bundleId = [(SBApplication *)arg1 bundleIdentifier];
    BOOL isSelectedApp = [selectedApps() containsObject:bundleId];

    if (module != nil && [module isSelected] && isSelectedApp) {
        keepAliveScenesForBundle(bundleId);
        [[BackgroundKeepAlive sharedInstance] updateNotificationStateForBundle:bundleId foreground:YES];
        return;
    }

    if (arg1 == nil || (module != nil && [module isSelected])) {
        return;
    }

    if (module && isSelectedApp) {
        [module setSelected:YES];
        [(CCUIToggleModule *)module refreshState];
        keepAliveScenesForBundle(bundleId);
        [[BackgroundKeepAlive sharedInstance] updateNotificationStateForBundle:bundleId foreground:YES];
    }
}

%new
- (BOOL)backgrounderShouldKeepActiveState:(NSString *)bundleId {
    return shouldKeepAliveBundle(bundleId);
}
%end

%hook FBSceneManager
- (void)_noteSceneMovedToBackground:(FBScene *)scene {
    %orig;
    NSString *bundleId = scene.clientProcess.identity.embeddedApplicationIdentifier;
    if (shouldKeepAliveBundle(bundleId)) {
        [[BackgroundKeepAlive sharedInstance] keepAliveScene:scene];
    }
}

- (void)_applyMutableSettings:(UIMutableApplicationSceneSettings *)settings
                      toScene:(FBScene *)scene
        withTransitionContext:(id)transitionContext
                   completion:(id)completion {
    if (shouldKeepAliveBundle(scene.clientProcess.identity.embeddedApplicationIdentifier)) {
        [[BackgroundKeepAlive sharedInstance] applyKeepAliveSettingsToScene:scene settings:settings];
    }
    %orig;
}
%end

%hook SBApplication
- (void)_didExitWithContext:(id)arg1 {
    %orig;
    [[BackgroundKeepAlive sharedInstance] cleanupForBundle:self.bundleIdentifier];
}
%end

%end

%ctor {
    loadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, CFSTR("com.0xkuj.backgrounderaction15autostateprefs.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    %init(backgrounderStateGroup);
}
