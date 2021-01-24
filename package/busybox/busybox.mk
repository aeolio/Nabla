################################################################################
#
# additional busybox logic
#
################################################################################

# modify configuration
define BUSYBOX_MODIFY_INIT_CONFIG
	if [ -f "$(TARGET_DIR)/etc/mdev.conf" ]; then \
		patch $(TARGET_DIR)/etc/mdev.conf \
			$(BR2_EXTERNAL)/package/busybox/0000-additional-mdev-configurations.patch; \
	fi
endef
BUSYBOX_POST_INSTALL_TARGET_HOOKS += BUSYBOX_MODIFY_INIT_CONFIG
