################################################################################
#
# additional nfs-utils installation
#
################################################################################

NFS_UTILS_LIBDIR = var/lib/nfs

ifeq ($(BR2_PACKAGE_NFS_UTILS_RPC_NFSD),y)
define NFS_UTILS_CREATE_RECOVERY_DIR
	mkdir -p $(TARGET_DIR)/$(NFS_UTILS_LIBDIR) && \
	ln -fs ../../../tmp $(TARGET_DIR)/$(NFS_UTILS_LIBDIR)/v4recovery
endef
NFS_UTILS_POST_INSTALL_TARGET_HOOKS += NFS_UTILS_CREATE_RECOVERY_DIR
endif
