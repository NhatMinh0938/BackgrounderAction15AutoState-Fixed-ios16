export TARGET = iphone:clang:16.5:15.0
export ARCHS = arm64 arm64e
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = Backgrounder15AutoState

Backgrounder15AutoState_FILES = BASRootListController.m
Backgrounder15AutoState_FRAMEWORKS = UIKit
Backgrounder15AutoState_PRIVATE_FRAMEWORKS = Preferences
Backgrounder15AutoState_INSTALL_PATH = /Library/PreferenceBundles
Backgrounder15AutoState_EXTRA_FRAMEWORKS = AltList
Backgrounder15AutoState_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
