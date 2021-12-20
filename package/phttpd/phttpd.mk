################################################################################
#
# thttpd
#
################################################################################

PHTTPD_VERSION = 1
PHTTPD_SITE = /home/iago/phttpd
PHTTPD_SITE_METHOD = local
#PHTTPD_LICENSE = GPLv3
#PHTTPD_LICENSE_FILES = COPYING
PHTTPD_DEPENDENCIES = libmicrohttpd

define PHTTPD_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D)
endef

define PHTTPD_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/usr/bin
	$(INSTALL) -m 0755 $(@D)/phttpd $(TARGET_DIR)/usr/bin
	$(INSTALL) -d $(TARGET_DIR)/etc/init.d
	$(INSTALL) -m 0644 $(@D)/config/phttpd.conf $(TARGET_DIR)/etc
	$(INSTALL) -m 0755 $(@D)/config/S50phttpd $(TARGET_DIR)/etc/init.d
endef

$(eval $(generic-package))
