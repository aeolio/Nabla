################################################################################
#
# override libfuse3 configuration
#
################################################################################

LIBFUSE3_CONF_OPTS += -Ddisable-mtab=true

# fuse3 installs a rule anyway, regardless of udev presence on target system
ifneq ($(BR2_PACKAGE_HAS_UDEV),y)
define LIBFUSE3_REMOVE_UDEV
	rm $(TARGET_DIR)/lib/udev/rules.d/99-fuse3.rules
endef

LIBFUSE3_POST_INSTALL_TARGET_HOOKS += LIBFUSE3_REMOVE_UDEV
endif
