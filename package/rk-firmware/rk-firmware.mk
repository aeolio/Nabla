################################################################################
#
# rk-firmware
#
################################################################################

RK_FIRMWARE_VERSION = 169dea138c76f06d1e06c43ff953636cf673e5b1
RK_FIRMWARE_SITE = $(call github,radxa,rkbin,$(RK_FIRMWARE_VERSION))
RK_FIRMWARE_LICENSE = PROPRIETARY
RK_FIRMWARE_LICENSE_FILES = 
RK_FIRMWARE_INSTALL_IMAGES = YES
RK_FIRMWARE_INSTALL_STAGING = NO
RK_FIRMWARE_INSTALL_TARGET = NO
RK_FIRMWARE_DEPENDENCIES = host-rk-firmware

# binary tools supplied by Rockchips for generating images
define HOST_RK_FIRMWARE_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/tools/firmwareMerger $(HOST_DIR)/bin/firmwareMerger
	$(INSTALL) -D -m 0755 $(@D)/tools/loaderimage $(HOST_DIR)/bin/loaderimage
	$(INSTALL) -D -m 0755 $(@D)/tools/trust_merger $(HOST_DIR)/bin/trust_merger
endef

define RK_FIRMWARE_BUILD_CMDS
	$(MKIMAGE) -n rk3399 -T rksd -d $(@D)/bin/rk33/rk3399_ddr_800MHz_v1.20.bin $(@D)/idbloader.img
	cat $(@D)/bin/rk33/rk3399_miniloader_v1.19.bin >> $(@D)/idbloader.img
	$(MKIMAGE) -n rk3399 -T rkspi -d $(@D)/bin/rk33/rk3399_ddr_800MHz_v1.20.bin $(@D)/idbloader-spi.img
	cat $(@D)/bin/rk33/rk3399_miniloader_spinor_v1.14.bin >> $(@D)/idbloader-spi.img
	sed -e 's|PATH=|PATH=$(@D)/|' $(RK_FIRMWARE_PKGDIR)/trust.ini > $(@D)/trust.ini
	$(@D)/tools/trust_merger --size 1024 1 $(@D)/trust.ini
endef

define RK_FIRMWARE_INSTALL_IMAGES_CMDS
	$(INSTALL) -D -m 0644 $(@D)/idbloader.img $(BINARIES_DIR)/u-boot/idbloader.img
	$(INSTALL) -D -m 0644 $(@D)/idbloader-spi.img $(BINARIES_DIR)/u-boot/spi/idbloader-spi.img
	# these are probably not needed
	$(INSTALL) -D -m 0644 $(@D)/bin/rk33/rk3399_loader_v1.12.112.bin $(BINARIES_DIR)/u-boot/rk3399_loader_v1.12.112.bin
	$(INSTALL) -D -m 0644 $(@D)/bin/rk33/rk3399_loader_spinor_v1.15.114.bin $(BINARIES_DIR)/u-boot/spi/rk3399_loader_spinor_v1.15.114.bin
	# these are needed for SPI build
	$(INSTALL) -D -m 0644 $(@D)/bin/rk33/rk3399_ddr_800MHz_v1.20.bin $(BINARIES_DIR)/firmware/rk3399_ddr_800MHz_v1.20.bin
	$(INSTALL) -D -m 0644 $(@D)/bin/rk33/rk3399_miniloader_spinor_v1.14.bin $(BINARIES_DIR)/firmware/rk3399_miniloader_spinor_v1.14.bin
	$(INSTALL) -D -m 0644 $(@D)/trust.img $(BINARIES_DIR)/u-boot/trust.img
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
