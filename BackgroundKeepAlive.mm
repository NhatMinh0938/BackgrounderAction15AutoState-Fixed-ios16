#import "BackgroundKeepAlive.h"
#import "PrivateHeaders.h"
#import <objc/runtime.h>

@interface BackgroundKeepAlive ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, RBSAssertion *> *assertions;
@property (nonatomic, strong) NSMutableDictionary<NSString *, RBSAssertionIdentifier *> *assertionIdentifiers;
@property (nonatomic, strong) NSMutableSet<NSString *> *keptAliveBundles;
@property (nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation BackgroundKeepAlive

+ (instancetype)sharedInstance {
    static BackgroundKeepAlive *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _assertions = [NSMutableDictionary dictionary];
        _assertionIdentifiers = [NSMutableDictionary dictionary];
        _keptAliveBundles = [NSMutableSet set];
    }
    return self;
}

- (BOOL)shouldKeepAliveBundle:(NSString *)bundleId
              selectedBundles:(NSArray *)selectedBundles
                   toggleOn:(BOOL)toggleOn
               tweakEnabled:(BOOL)tweakEnabled {
    if (!tweakEnabled || !toggleOn || bundleId.length == 0 || !selectedBundles.count) {
        return NO;
    }
    return [selectedBundles containsObject:bundleId];
}

- (int)pidForBundleIdentifier:(NSString *)identifier {
    SBApplicationController *controller = [objc_getClass("SBApplicationController") sharedInstanceIfExists];
    if (!controller) return -1;
    SBApplication *app = [controller applicationWithBundleIdentifier:identifier];
    if (!app.processState) return -1;
    return app.processState.pid;
}

- (NSString *)bundleIdentifierForPid:(int)pid {
    if (pid <= 0) return nil;
    SBApplicationController *controller = [objc_getClass("SBApplicationController") sharedInstanceIfExists];
    if (!controller) return nil;
    SBApplication *app = [controller applicationWithPid:pid];
    return app.bundleIdentifier;
}

- (BOOL)isFrontMostBundle:(NSString *)identifier {
    SpringBoard *springBoard = (SpringBoard *)[UIApplication sharedApplication];
    SBApplication *frontMostApp = [springBoard _accessibilityFrontMostApplication];
    BOOL isFrontMost = [frontMostApp.bundleIdentifier isEqualToString:identifier];
    SBLockScreenManager *lockManager = [objc_getClass("SBLockScreenManager") sharedInstance];
    if (lockManager.isUILocked) {
        isFrontMost = NO;
    }
    return isFrontMost;
}

- (RBSAssertion *)assertionWithTarget:(RBSTarget *)target {
    Class legacyAttrClass = objc_getClass("RBSLegacyAttribute");
    Class hereditaryGrantClass = objc_getClass("RBSHereditaryGrant");
    Class assertionClass = objc_getClass("RBSAssertion");

    uint32_t flags = BKSProcessAssertionPreventTaskSuspend
        | BKSProcessAssertionPreventTaskThrottleDown
        | BKSProcessAssertionPreventThrottleDownUI
        | BKSProcessAssertionWantsForegroundResourcePriority;

    RBSLegacyAttribute *legacyAttr = [legacyAttrClass attributeWithReason:BKSProcessAssertionReasonBackgroundUI flags:flags];
    RBSHereditaryGrant *endpointGrant = [hereditaryGrantClass grantWithNamespace:@"com.apple.boardservices.endpoint-injection"
                                                               sourceEnvironment:@"UIScene:com.apple.frontboard.systemappservices::com.apple.springboard"
                                                                      attributes:nil];
    RBSHereditaryGrant *visibilityGrant = [hereditaryGrantClass grantWithNamespace:@"com.apple.frontboard.visibility"
                                                                sourceEnvironment:@"UIScene:com.apple.frontboard.systemappservices::com.apple.springboard"
                                                                       attributes:nil];

    return [[assertionClass alloc] initWithExplanation:@"BackgrounderAction15AutoState keep-alive"
                                                target:target
                                            attributes:@[legacyAttr, endpointGrant, visibilityGrant]];
}

- (void)invalidateAssertionForSceneID:(NSString *)sceneID {
    RBSAssertion *assertion = self.assertions[sceneID];
    RBSAssertionIdentifier *identifier = self.assertionIdentifiers[sceneID];
    if (!assertion || !identifier) return;

    [assertion invalidate];
    [[objc_getClass("RBSConnection") sharedInstance] invalidateAssertionWithIdentifier:identifier error:nil];
    [self.assertions removeObjectForKey:sceneID];
    [self.assertionIdentifiers removeObjectForKey:sceneID];
}

- (void)acquireAssertionForScene:(FBScene *)scene {
    NSString *bundleId = scene.clientProcess.identity.embeddedApplicationIdentifier;
    NSString *sceneID = scene.identifier;
    if (!bundleId.length || !sceneID.length || !scene.valid) return;

    RBSAssertion *existing = self.assertions[sceneID];
    if (existing.valid) return;

    if (existing) {
        [self invalidateAssertionForSceneID:sceneID];
    }

    int pid = [self pidForBundleIdentifier:bundleId];
    if (pid <= 0) return;

    RBSTarget *target = [objc_getClass("RBSTarget") targetWithPid:pid environmentIdentifier:sceneID];
    if (!target) return;

    RBSAssertion *assertion = [self assertionWithTarget:target];
    NSError *error = nil;
    [assertion acquireWithError:&error];
    if (error) return;

    RBSAssertionIdentifier *identifier = [[objc_getClass("RBSConnection") sharedInstance] acquireAssertion:assertion error:&error];
    if (!identifier) return;

    self.assertions[sceneID] = assertion;
    self.assertionIdentifiers[sceneID] = identifier;

    RBSProcessIdentifier *processID = [objc_getClass("RBSProcessIdentifier") identifierWithPid:pid];
    if (processID) {
        __weak BackgroundKeepAlive *weakSelf = self;
        [[objc_getClass("RBSConnection") sharedInstance] subscribeToProcessDeath:processID handler:^{
            BackgroundKeepAlive *strongSelf = weakSelf;
            if (!strongSelf) return;
            NSString *deadBundle = [strongSelf bundleIdentifierForPid:processID.pid];
            if (deadBundle) {
                [strongSelf cleanupForBundle:deadBundle];
            }
        }];
    }
}

- (void)startRefreshTimerIfNeeded {
    if (self.refreshTimer) return;
    __weak BackgroundKeepAlive *weakSelf = self;
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:45.0 repeats:YES block:^(NSTimer *timer) {
        [weakSelf refreshAllKeptAliveScenes];
    }];
}

- (void)stopRefreshTimerIfNeeded {
    if (self.keptAliveBundles.count > 0) return;
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)keepAliveScene:(FBScene *)scene {
    NSString *bundleId = scene.clientProcess.identity.embeddedApplicationIdentifier;
    if (!bundleId.length) return;

    [self.keptAliveBundles addObject:bundleId];
    [self acquireAssertionForScene:scene];
    [self updateNotificationStateForBundle:bundleId foreground:[self isFrontMostBundle:bundleId]];
    [self startRefreshTimerIfNeeded];
}

- (void)applyKeepAliveSettingsToScene:(FBScene *)scene
                             settings:(UIMutableApplicationSceneSettings *)settings {
    NSString *bundleId = scene.clientProcess.identity.embeddedApplicationIdentifier;
    if (![self.keptAliveBundles containsObject:bundleId]) return;
    if ([self isFrontMostBundle:bundleId]) return;

    [settings setForeground:YES];
    [settings setBackgrounded:NO];
}

- (void)updateNotificationStateForBundle:(NSString *)bundleId foreground:(BOOL)foreground {
    if (!bundleId.length) return;
    unsigned state = foreground ? 8 : 4;
    [[objc_getClass("UNSUserNotificationServer") sharedInstance] _didChangeApplicationState:state forBundleIdentifier:bundleId];
}

- (void)cleanupAssertionsForBundle:(NSString *)bundleId {
    if (!bundleId.length) return;
    NSMutableArray<NSString *> *sceneIDs = [NSMutableArray array];
    FBSceneManager *sceneManager = [objc_getClass("FBSceneManager") sharedInstance];
    NSMutableDictionary *scenesByID = [sceneManager valueForKey:@"_scenesByID"];
    [scenesByID enumerateKeysAndObjectsUsingBlock:^(NSString *sceneID, FBScene *scene, BOOL *stop) {
        if ([scene.clientProcess.identity.embeddedApplicationIdentifier isEqualToString:bundleId]) {
            [sceneIDs addObject:sceneID];
        }
    }];
    for (NSString *sceneID in sceneIDs) {
        [self invalidateAssertionForSceneID:sceneID];
    }
}

- (void)cleanupForBundle:(NSString *)bundleId {
    if (!bundleId.length) return;
    [self.keptAliveBundles removeObject:bundleId];
    [self cleanupAssertionsForBundle:bundleId];
    [self stopRefreshTimerIfNeeded];
}

- (void)cleanupAll {
    for (NSString *sceneID in self.assertions.allKeys.copy) {
        [self invalidateAssertionForSceneID:sceneID];
    }
    [self.keptAliveBundles removeAllObjects];
    [self stopRefreshTimerIfNeeded];
}

- (void)refreshAllKeptAliveScenes {
    if (self.keptAliveBundles.count == 0) return;

    FBSceneManager *sceneManager = [objc_getClass("FBSceneManager") sharedInstance];
    NSMutableDictionary *scenesByID = [sceneManager valueForKey:@"_scenesByID"];

    [scenesByID enumerateKeysAndObjectsUsingBlock:^(NSString *sceneID, FBScene *scene, BOOL *stop) {
        NSString *bundleId = scene.clientProcess.identity.embeddedApplicationIdentifier;
        if (![self.keptAliveBundles containsObject:bundleId] || !scene.valid) return;

        [self acquireAssertionForScene:scene];

        if (![self isFrontMostBundle:bundleId]) {
            UIMutableApplicationSceneSettings *settings = [(UIMutableApplicationSceneSettings *)scene.settings mutableCopy];
            [settings setForeground:YES];
            [settings setBackgrounded:NO];
            [sceneManager _applyMutableSettings:settings
                                        toScene:scene
                          withTransitionContext:nil
                                     completion:nil];
            [self updateNotificationStateForBundle:bundleId foreground:NO];
        }
    }];
}

@end
