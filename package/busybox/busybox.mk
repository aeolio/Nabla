################################################################################
#
# additional busybox logic
#
################################################################################

# modify configuration
define BUSYBOX_MODIFY_INIT_CONFIG
	patch $(TARGET_DIR)/etc/mdev.conf $(BR2_EXTERNAL)/package/busybox/0000-additional-mdev-configurations.patch
endef
BUSYBOX_POST_INSTALL_TARGET_HOOKS += BUSYBOX_MODIFY_INIT_CONFIG
