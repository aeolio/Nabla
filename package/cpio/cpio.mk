################################################################################
#
# additional cpio logic
#
################################################################################

### propagate Buildroot rootfs compression setting to the kernel config

ifeq ($(BR2_TARGET_ROOTFS_CPIO_GZIP),y)
ROOTFS_CPIO_COMPRESS_INITRD = GZIP
endif
ifeq ($(BR2_TARGET_ROOTFS_CPIO_BZIP2),y)
ROOTFS_CPIO_COMPRESS_INITRD = BZIP2
endif
ifeq ($(BR2_TARGET_ROOTFS_CPIO_LZMA),y)
ROOTFS_CPIO_COMPRESS_INITRD = LZMA
endif
ifeq ($(BR2_TARGET_ROOTFS_CPIO_XZ),y)
ROOTFS_CPIO_COMPRESS_INITRD = XZ
endif
ifeq ($(BR2_TARGET_ROOTFS_CPIO_LZO),y)
ROOTFS_CPIO_COMPRESS_INITRD = LZ0
endif
ifeq ($(BR2_TARGET_ROOTFS_CPIO_LZ4),y)
ROOTFS_CPIO_COMPRESS_INITRD = LZ4
endif
ifeq ($(BR2_TARGET_ROOTFS_CPIO_ZSTD),y)
ROOTFS_CPIO_COMPRESS_INITRD = ZSTD
endif

ifneq ($(ROOTFS_CPIO_COMPRESS_INITRD),)
define ROOTFS_CPIO_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_ENABLE_OPT,CONFIG_RD_$(ROOTFS_CPIO_COMPRESS_INITRD))
endef
# this is necessary because fragment files do not get processed by inner-generic-package
PACKAGES_LINUX_CONFIG_FIXUPS += $(ROOTFS_CPIO_LINUX_CONFIG_FIXUPS)$(sep)
endif
