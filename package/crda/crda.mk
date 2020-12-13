################################################################################
#
# override crda configuration
#
################################################################################

# crda installs a rule anyway, regardless of udev presence on target system
ifneq ($(BR2_PACKAGE_HAS_UDEV),y)
define CRDA_REMOVE_UDEV
	rm $(TARGET_DIR)/lib/udev/rules.d/85-regulatory.rules
endef

CRDA_POST_INSTALL_TARGET_HOOKS += CRDA_REMOVE_UDEV
endif
