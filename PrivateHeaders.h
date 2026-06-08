#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FBProcessIdentity : NSObject
@property (nonatomic, readonly) NSString *embeddedApplicationIdentifier;
@end

@interface FBProcess : NSObject
@property (nonatomic, readonly) FBProcessIdentity *identity;
@property (nonatomic, readonly) NSString *bundleIdentifier;
@end

@interface FBSSceneSettings : NSObject
- (id)mutableCopy;
@end

@interface FBSMutableSceneSettings : FBSSceneSettings
@property (assign, getter=isForeground, nonatomic) BOOL foreground;
@property (assign, getter=isBackgrounded, nonatomic) BOOL backgrounded;
- (void)setForeground:(BOOL)arg1;
- (void)setBackgrounded:(BOOL)arg1;
@end

@interface UIMutableApplicationSceneSettings : FBSMutableSceneSettings
@end

@interface FBScene : NSObject
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, readonly) FBProcess *clientProcess;
@property (nonatomic, readonly) FBSSceneSettings *settings;
@property (getter=isValid, nonatomic, readonly) BOOL valid;
@end

@interface FBSceneManager : NSObject
+ (id)sharedInstance;
- (void)_applyMutableSettings:(UIMutableApplicationSceneSettings *)settings
                      toScene:(FBScene *)scene
        withTransitionContext:(id)transitionContext
                   completion:(id)completion;
- (void)_noteSceneMovedToBackground:(FBScene *)scene;
@end

@interface SBApplicationProcessState : NSObject
@property (nonatomic, readonly) int pid;
@end

@interface SBApplication : NSObject
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) SBApplicationProcessState *processState;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)sharedInstanceIfExists;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleIdentifier;
- (SBApplication *)applicationWithPid:(int)pid;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end

@interface UNSUserNotificationServer : NSObject
+ (instancetype)sharedInstance;
- (void)_didChangeApplicationState:(unsigned)state forBundleIdentifier:(NSString *)bundleIdentifier;
@end

@interface RBSProcessIdentifier : NSObject
+ (instancetype)identifierWithPid:(int)pid;
@property (nonatomic, readonly) int pid;
@end

@interface RBSTarget : NSObject
+ (instancetype)targetWithPid:(int)pid environmentIdentifier:(NSString *)environmentIdentifier;
@end

@interface RBSAssertionIdentifier : NSObject
@end

@interface RBSAttribute : NSObject
@end

@interface RBSLegacyAttribute : RBSAttribute
+ (instancetype)attributeWithReason:(uint32_t)reason flags:(uint32_t)flags;
@end

@interface RBSHereditaryGrant : RBSAttribute
+ (instancetype)grantWithNamespace:(NSString *)ns
                 sourceEnvironment:(NSString *)sourceEnvironment
                        attributes:(NSArray *)attributes;
@end

@interface RBSAssertion : NSObject
@property (getter=isValid, nonatomic, readonly) BOOL valid;
@property (nonatomic, copy, readonly) NSArray *attributes;
- (instancetype)initWithExplanation:(NSString *)explanation
                             target:(RBSTarget *)target
                         attributes:(NSArray *)attributes;
- (BOOL)acquireWithError:(NSError **)error;
- (void)invalidate;
@end

@interface RBSConnection : NSObject
+ (instancetype)sharedInstance;
- (RBSAssertionIdentifier *)acquireAssertion:(RBSAssertion *)assertion error:(NSError **)error;
- (void)invalidateAssertionWithIdentifier:(RBSAssertionIdentifier *)identifier error:(NSError **)error;
- (void)subscribeToProcessDeath:(RBSProcessIdentifier *)processID handler:(dispatch_block_t)handler;
@end

@interface SpringBoard (BASPrivate)
- (SBApplication *)_accessibilityFrontMostApplication;
@end

enum {
    BKSProcessAssertionPreventTaskSuspend = 1 << 0,
    BKSProcessAssertionPreventTaskThrottleDown = 1 << 1,
    BKSProcessAssertionWantsForegroundResourcePriority = 1 << 3,
    BKSProcessAssertionPreventThrottleDownUI = 1 << 5,
    BKSProcessAssertionReasonBackgroundUI = 9,
};
