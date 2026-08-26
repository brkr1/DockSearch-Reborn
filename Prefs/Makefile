ARCHS = arm64 arm64e

ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
    TARGET := iphone:clang:latest:15.0
    TARGET_OS_DEPLOYMENT_VERSION = 15.0
    ifneq ($(wildcard $(THEOS)/sdks/iPhoneOS15.6.sdk),)
        SYSROOT=$(THEOS)/sdks/iPhoneOS15.6.sdk
        SDKVERSION = 15.6
        INCLUDE_SDKVERSION = 15.6
    endif
else
    TARGET := iphone:clang:latest:13.0
    TARGET_OS_DEPLOYMENT_VERSION = 13.0
endif

include $(THEOS)/makefiles/common.mk

# Same arm64e class_ro signing probe as the tweak's Makefile - see there for
# the full explanation.
DSR_PTRAUTH_FLAG := -fno-ptrauth-objc-class-ro
DSR_PTRAUTH_SUPPORTED := $(shell $(TARGET_CC) -target arm64e-apple-ios15.0 -x objective-c \
	-fsyntax-only $(DSR_PTRAUTH_FLAG) /dev/null >/dev/null 2>&1 && echo yes)

ifeq ($(DSR_PTRAUTH_SUPPORTED),yes)
DSR_PTRAUTH_CFLAGS := $(DSR_PTRAUTH_FLAG)
else ifeq ($(filter arm64e,$(ARCHS)),)
DSR_PTRAUTH_CFLAGS :=
else
$(error $(DSR_PTRAUTH_FLAG) is not accepted by $(TARGET_CC), but arm64e is in ARCHS.)
endif

BUNDLE_NAME = DockSearchRebornPrefs

DockSearchRebornPrefs_FILES = $(wildcard *.m)
DockSearchRebornPrefs_INSTALL_PATH = /Library/PreferenceBundles
DockSearchRebornPrefs_FRAMEWORKS = UIKit
DockSearchRebornPrefs_PRIVATE_FRAMEWORKS = Preferences
DockSearchRebornPrefs_EXTRA_FRAMEWORKS = CepheiPrefs Cephei
DockSearchRebornPrefs_CFLAGS = -fobjc-arc $(DSR_PTRAUTH_CFLAGS)

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/$(BUNDLE_NAME).plist$(ECHO_END)
