################################################################################
#
# interbench
#
################################################################################

INTERBENCH_VERSION = master
# INTERBENCH_SOURCE = interbench-$(INTERBENCH_VERSION).tar.gz
INTERBENCH_SITE = https://github.com/ckolivas/interbench.git
INTERBENCH_SITE_METHOD = git
INTERBENCH_LICENSE = GPLv2
INTERBENCH_LICENSE_FILES = COPYING
INTERBENCH_INSTALL_STAGING = NO
INTERBENCH_INSTALL_TARGET = YES

# interbench comes with precompiled binaries
define INTERBENCH_REMOVE_OBJECTS
    $(RM) -fr $(@D)/*.o interbench
endef
INTERBENCH_POST_EXTRACT_HOOKS += INTERBENCH_REMOVE_OBJECTS

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
