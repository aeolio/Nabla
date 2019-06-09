################################################################################
#
# additional uboot configurations for Rockchip
#
################################################################################

target = $(findstring rockpi4,$(BR2_DEFCONFIG))

# Rockchip board has been selected
ifeq ($(target),rockpi4)

# provides necessary binaries for image creation
UBOOT_DEPENDENCIES += rk-firmware

# create boot images
define UBOOT_BUILD_RK3399
	$(HOST_DIR)/bin/loaderimage --pack --uboot $(@D)/u-boot-dtb.bin $(@D)/uboot.img 0x200000 --size 1024 1
	sed -e 's|uboot.img|$(@D)/uboot.img|' \
		-e 's|trust.img|$(BINARIES_DIR)/u-boot/trust.img|' \
		-e 's|bin/rk33|$(BINARIES_DIR)/firmware|g' \
		$(RK_FIRMWARE_PKGDIR)/spi.ini > $(@D)/spi.ini
	$(HOST_DIR)/bin/firmwareMerger -P $(@D)/spi.ini $(@D)
endef

# install boot images
define UBOOT_INSTALL_IMAGE_RK3399
	$(INSTALL) -D -m 0644 $(@D)/uboot.img $(BINARIES_DIR)/u-boot/uboot.img
	$(INSTALL) -D -m 0644 $(@D)/Firmware.img $(BINARIES_DIR)/u-boot/spi/uboot-trust-spi.img
	$(INSTALL) -D -m 0644 $(@D)/Firmware.md5 $(BINARIES_DIR)/u-boot/spi/uboot-trust-spi.img.md5
endef

UBOOT_POST_BUILD_HOOKS += UBOOT_BUILD_RK3399
UBOOT_POST_INSTALL_IMAGES_HOOKS += UBOOT_INSTALL_IMAGE_RK3399

endif # Rockchip modifications
