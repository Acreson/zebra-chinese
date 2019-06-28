
export THEOS=/opt/theos
export THEOS_DEVICE_IP=10.0.0.30


include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/null.mk

all::
	xcodebuild -quiet -scheme Zebra archive -archivePath Zebra.xcarchive PACKAGE_VERSION='@\"$(THEOS_PACKAGE_BASE_VERSION)\"'

after-stage::
	mv Zebra.xcarchive/Products/Applications $(THEOS_STAGING_DIR)/Applications
	rm -rf Zebra.xcarchive
	$(MAKE) -C Supersling
	mkdir -p $(THEOS_STAGING_DIR)/usr/libexec/zebra
	mv $(THEOS_OBJ_DIR)/supersling $(THEOS_STAGING_DIR)/usr/libexec/zebra
	rm -rf $(THEOS_STAGING_DIR)/Applications/Zebra.app/embedded.mobileprovision
	ldid -SZebra/Zebra.entitlements $(THEOS_STAGING_DIR)/Applications/Zebra.app/Zebra

after-install::
	install.exec "killall \"Zebra\"" || true
