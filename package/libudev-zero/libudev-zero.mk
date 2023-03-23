################################################################################
#
# libudev-zero
#
################################################################################

LIBUDEV_ZERO_VERSION = 1.0.1
LIBUDEV_ZERO_SITE = $(call github,illiliti,libudev-zero,$(LIBUDEV_ZERO_VERSION))
LIBUDEV_ZERO_INSTALL_STAGING = YES
LIBUDEV_ZERO_LICENSE = ISC
LIBUDEV_ZERO_LICENSE_FILES = LICENSE

define LIBUDEV_ZERO_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) PREFIX=$(STAGING_DIR)/usr -C $(@D)
endef

define LIBUDEV_ZERO_INSTALL_STAGING_CMDS
	$(MAKE) PREFIX=$(STAGING_DIR)/usr -C $(@D) install
endef

define LIBUDEV_ZERO_INSTALL_TARGET_CMDS
	$(MAKE) PREFIX=$(TARGET_DIR)/usr -C $(@D) install
endef

$(eval $(generic-package))
