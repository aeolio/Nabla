################################################################################
#
# Fragment file for syslinux
#
################################################################################

target = $(findstring rockpi4,$(BR2_DEFCONFIG))

# syslinux.sys is needed to create a bootable disk image
# copy the file syslinux.sys to image directory
ifeq ($(BR2_TARGET_SYSLINUX_LEGACY_BIOS),y)
define SYSLINUX_INSTALL_LEGACY_BIOS_DRIVER
	$(INSTALL) -D -m 0755 $(@D)/bios/core/ldlinux.sys \
		$(BINARIES_DIR)/syslinux/ldlinux.sys
endef
SYSLINUX_POST_INSTALL_IMAGES_HOOKS += SYSLINUX_INSTALL_LEGACY_BIOS_DRIVER
endif
