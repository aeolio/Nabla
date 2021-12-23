################################################################################
#
# additional busybox logic
#
################################################################################

BUSYBOX_MDEV_CONFIG = $(TARGET_DIR)/etc/mdev.conf

# modify mdev configuration
define BUSYBOX_MODIFY_INIT_CONFIG
	if [ -f "$(BUSYBOX_MDEV_CONFIG)" ]; then \
		patch $(BUSYBOX_MDEV_CONFIG) \
			$(BR2_EXTERNAL)/package/busybox/0000-additional-mdev-configurations.patch; \
	fi
endef
BUSYBOX_POST_INSTALL_TARGET_HOOKS += BUSYBOX_MODIFY_INIT_CONFIG
