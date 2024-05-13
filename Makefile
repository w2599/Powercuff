PACKAGE_VERSION = 1.0
THEOS_DEVICE_IP = 192.168.31.158
ARCHS = arm64e

TARGET := iphone:clang:latest:14.5

INSTALL_TARGET_PROCESSES = thermalmonitord SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = 0Powercuff
$(TWEAK_NAME)_FILES = Powercuff.x
$(TWEAK_NAME)_FRAMEWORKS = Foundation UIKit
# $(TWEAK_NAME)_CFLAGS = -std=c99
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_USE_MODULES = false



include $(THEOS_MAKE_PATH)/tweak.mk


clean::
	rm -rf .theos/obj
	rm -rf packages