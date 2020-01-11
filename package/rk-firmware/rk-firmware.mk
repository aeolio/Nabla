################################################################################
#
# rk-firmware
#
################################################################################

RK_FIRMWARE_VERSION = ce80f14c683d1eb5d1b2af0360512480848ff6f9
RK_FIRMWARE_SITE = $(call github,radxa,rkbin,$(RK_FIRMWARE_VERSION))
RK_FIRMWARE_LICENSE = PROPRIETARY
RK_FIRMWARE_LICENSE_FILES = 
RK_FIRMWARE_INSTALL_IMAGES = YES
RK_FIRMWARE_INSTALL_STAGING = NO
RK_FIRMWARE_INSTALL_TARGET = NO
RK_FIRMWARE_DEPENDENCIES = host-rk-firmware host-uboot-tools

RK_FIRMWARE_DDRFW = rk3399_ddr_800MHz_v1.20.bin
RK_FIRMWARE_IDBLDR = rk3399_miniloader_v1.19.bin
RK_FIRMWARE_SPILDR = rk3399_miniloader_spinor_v1.14.bin

# Rockchip version
# RK_FIRMWARE_TRUSTED_FW = $(@D)/RKTRUST/RK3399TRUST.ini
# Radxa version
RK_FIRMWARE_TRUSTED_FW = $(RK_FIRMWARE_PKGDIR)/trust.ini

# binary tools supplied by Rockchip for generating images
define HOST_RK_FIRMWARE_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/tools/firmwareMerger $(HOST_DIR)/bin/firmwareMerger
	$(INSTALL) -D -m 0755 $(@D)/tools/loaderimage $(HOST_DIR)/bin/loaderimage
	$(INSTALL) -D -m 0755 $(@D)/tools/trust_merger $(HOST_DIR)/bin/trust_merger
endef

define RK_FIRMWARE_BUILD_CMDS
	$(MKIMAGE) -n rk3399 -T rksd -d $(@D)/bin/rk33/$(RK_FIRMWARE_DDRFW) $(@D)/idbloader.img
	cat $(@D)/bin/rk33/$(RK_FIRMWARE_IDBLDR) >> $(@D)/idbloader.img
	$(MKIMAGE) -n rk3399 -T rkspi -d $(@D)/bin/rk33/$(RK_FIRMWARE_DDRFW) $(@D)/idbloader-spi.img
	cat $(@D)/bin/rk33/$(RK_FIRMWARE_SPILDR) >> $(@D)/idbloader-spi.img
	sed -e 's|PATH=|PATH=$(@D)/|g' $(RK_FIRMWARE_TRUSTED_FW) > $(@D)/trust.ini
	$(@D)/tools/trust_merger --size 1024 1 $(@D)/trust.ini
endef

define RK_FIRMWARE_INSTALL_IMAGES_CMDS
	$(INSTALL) -D -m 0644 $(@D)/idbloader.img $(BINARIES_DIR)/u-boot/idbloader.img
	$(INSTALL) -D -m 0644 $(@D)/idbloader-spi.img $(BINARIES_DIR)/u-boot/spi/idbloader-spi.img
	# next two are needed later for U-Boot build
	$(INSTALL) -D -m 0644 $(@D)/bin/rk33/$(RK_FIRMWARE_DDRFW) $(BINARIES_DIR)/firmware/$(RK_FIRMWARE_DDRFW)
	$(INSTALL) -D -m 0644 $(@D)/bin/rk33/$(RK_FIRMWARE_SPILDR) $(BINARIES_DIR)/firmware/$(RK_FIRMWARE_SPILDR)
	$(INSTALL) -D -m 0644 $(@D)/trust.img $(BINARIES_DIR)/u-boot/trust.img
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
