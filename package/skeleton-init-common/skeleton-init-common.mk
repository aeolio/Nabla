################################################################################
#
# Fragment file for skeleton-init-common
#
################################################################################

# this will generate a random initial password if none exists
ifeq ($(BR2_TARGET_ENABLE_ROOT_LOGIN),y)
define SKELETON_INIT_COMMON_GENERATE_ROOT_PASSWD
	$(BR2_EXTERNAL_NABLA_PATH)/scripts/mkpasswd.py $(BR2_CONFIG)
endef
SKELETON_INIT_COMMON_TARGET_FINALIZE_HOOKS += SKELETON_INIT_COMMON_GENERATE_ROOT_PASSWD
endif
