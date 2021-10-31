################################################################################
#
# interbench
#
################################################################################

INTERBENCH_VERSION = 0.36
INTERBENCH_SITE = $(call github,aeolio,interbench,$(INTERBENCH_VERSION))
INTERBENCH_LICENSE = GPLv3
INTERBENCH_LICENSE_FILES = COPYING

define INTERBENCH_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) \
		CC="$(TARGET_CC)" LD="$(TARGET_LD)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		CPPFLAGS="-DUSE_SETAFFINITY" \
		$(INTERBENCH_MAKE_OPTS) \
		-C $(@D) interbench
endef

define INTERBENCH_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/usr/bin
	$(INSTALL) -m 0755 $(@D)/interbench $(TARGET_DIR)/usr/bin
endef

$(eval $(generic-package))
