################################################################################
#
# rtl8723bs -- Realtek SDIO Wi-Fi driver, mainlined with kernel 4.12.y
#
################################################################################

RTL8723BS_VERSION = db2c4f61d48fe3b47c167c8bcd722ce83c24aca5
RTL8723BS_SITE = https://github.com/hadess/rtl8723bs
RTL8723BS_SITE_METHOD = git
RTL8723BS_INSTALL_STAGING = YES
RTL8723BS_DEPENDENCIES = linux
RTL8723BS_LICENSE = GPL3
RTL8723BS_LICENSE_FILES = COPYING

RTL8723BS_KERNEL_VER = $(BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE)
RTL8723BS_SOURCE_DIR = $(BUILD_DIR)/linux-$(RTL8723BS_KERNEL_VER)

define RTL8723BS_BUILD_CMDS
	$(MAKE) CXX="$(TARGET_CXX)" 	LD="$(TARGET_LD)" \
		USER_EXTRA_CFLAGS="-DCONFIG_LITTLE_ENDIAN" \
		SUBARCH=i686 \
		ARCH=x86_64 \
		CROSS_COMPILE="$(HOST_DIR)/usr/bin/x86_64-buildroot-linux-uclibc-" \
		KVER=$(LINUX_VERSION_PROBED) \
		KSRC=$(LINUX_DIR) \
		MODDESTDIR="$(TARGET_DIR)/lib64/modules/$(KVER)/kernel/drivers/net/wireless/" \
		INSTALL_PREFIX="" -C $(@D)
endef

define RTL8723BS_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(@D)/r8723bs.ko \
		$(TARGET_DIR)/lib/modules/$(LINUX_VERSION_PROBED)/kernel/drivers/net/wireless/ \
		|| exit 1; \
	$(HOST_DIR)/sbin/depmod -a -b $(TARGET_DIR) $(LINUX_VERSION_PROBED)
endef

$(eval $(generic-package))
