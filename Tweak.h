#pragma once

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <rootless.h>
#import "PrivateHeaders.h"

#define GENERAL_PREFS ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.0xkuj.backgrounderaction15autostateprefs.plist")

@interface CCUIToggleModule : NSObject
@property (nonatomic, assign, getter=isSelected) BOOL selected;
- (void)refreshState;
@end
