export TARGET = iphone:clang:16.5:15.0
export ARCHS = arm64 arm64e
export THEOS_PACKAGE_SCHEME = rootless
export FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = backgrounderaction15autostate

backgrounderaction15autostate_FILES = Tweak.xm BackgroundKeepAlive.mm
backgrounderaction15autostate_CFLAGS = -fobjc-arc
backgrounderaction15autostate_PRIVATE_FRAMEWORKS = FrontBoardServices RunningBoardServices

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += backgrounderaction15autostateprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
