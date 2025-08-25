################################################################################
#
# additional nfs-utils installation
#
################################################################################

# linux kernel needs NFS and NFSv3 if NFS daemon is selected
ifeq ($(BR2_PACKAGE_NFS_UTILS_RPC_NFSD),y)
define NFS_UTILS_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_ENABLE_OPT,CONFIG_NFSD)
	$(call KCONFIG_ENABLE_OPT,CONFIG_NFSD_V3)
endef
# this is necessary because fragment files do not get processed by inner-generic-package
PACKAGES_LINUX_CONFIG_FIXUPS += $(NFS_UTILS_LINUX_CONFIG_FIXUPS)$(sep)
endif

NFS_UTILS_LIBDIR = var/lib/nfs

ifeq ($(BR2_PACKAGE_NFS_UTILS_RPC_NFSD),y)
define NFS_UTILS_CREATE_RECOVERY_DIR
	mkdir -p $(TARGET_DIR)/$(NFS_UTILS_LIBDIR) && \
	ln -fs ../../../tmp $(TARGET_DIR)/$(NFS_UTILS_LIBDIR)/v4recovery
endef
NFS_UTILS_POST_INSTALL_TARGET_HOOKS += NFS_UTILS_CREATE_RECOVERY_DIR
endif

# nfs-utils installs a rule anyway, regardless of udev presence on target system
ifneq ($(BR2_PACKAGE_HAS_UDEV),y)
define NFS_UTILS_REMOVE_UDEV
	rm $(TARGET_DIR)/usr/lib/udev/rules.d/99-nfs.rules
endef
NFS_UTILS_POST_INSTALL_TARGET_HOOKS += NFS_UTILS_REMOVE_UDEV
endif
