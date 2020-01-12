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

# initialization files names contain the SoC name
RK_FIRMWARE_CHIP_NAME = $(BR2_PACKAGE_RK_FIRMWARE_CHIP_NAME)

# get the correct firmware names from these files
# loader images for [IDB, SPI] and trusted firmware
RK_FIRMWARE_IDBLDR_INI = $(@D)/RKBOOT/$(RK_FIRMWARE_CHIP_NAME)MINIALL.ini
RK_FIRMWARE_SPILDR_INI = $(@D)/RKBOOT/$(RK_FIRMWARE_CHIP_NAME)MINIALL_SPINOR.ini
RK_FIRMWARE_TRUST_INI = $(@D)/RKTRUST/$(RK_FIRMWARE_CHIP_NAME)TRUST.ini

# Extract firmware file names from the config files distributed by Radxa /Rockchip.
#
# LOADER[12] defines an image variable
# The image variable references a file name
#
# $(1): full path to the configuration file
# $(2): index of the loader file name to be retrieved
#
define RK_FIRMWARE_GET_FW_FILENAME
	awk 'BEGIN{FS = "="} \
	/LOADER$(2)/ {ldr = $$2;} \
	{if($$1 == ldr) print $$2;}' \
	$(1) | sed 's|tools/rk_tools/||'
endef

# parse configuration files
RK_FIRMWARE_DDRFW = $(shell $(call RK_FIRMWARE_GET_FW_FILENAME,$(RK_FIRMWARE_IDBLDR_INI),1))
RK_FIRMWARE_IDBLDR = $(shell $(call RK_FIRMWARE_GET_FW_FILENAME,$(RK_FIRMWARE_IDBLDR_INI),2))
RK_FIRMWARE_SPILDR = $(shell $(call RK_FIRMWARE_GET_FW_FILENAME,$(RK_FIRMWARE_SPILDR_INI),2))

# install binary tools supplied by Rockchip for generating images (will also used by U-Boot)
define HOST_RK_FIRMWARE_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/tools/firmwareMerger $(HOST_DIR)/bin/firmwareMerger
	$(INSTALL) -D -m 0755 $(@D)/tools/loaderimage $(HOST_DIR)/bin/loaderimage
	$(INSTALL) -D -m 0755 $(@D)/tools/trust_merger $(HOST_DIR)/bin/trust_merger
endef

define RK_FIRMWARE_BUILD_CMDS
	$(MKIMAGE) -n rk3399 -T rksd -d $(@D)/$(RK_FIRMWARE_DDRFW) $(@D)/idbloader.img
	cat $(@D)/$(RK_FIRMWARE_IDBLDR) >> $(@D)/idbloader.img
	$(MKIMAGE) -n rk3399 -T rkspi -d $(@D)/$(RK_FIRMWARE_DDRFW) $(@D)/idbloader-spi.img
	cat $(@D)/$(RK_FIRMWARE_SPILDR) >> $(@D)/idbloader-spi.img
	sed -e 's|PATH=tools/rk_tools|PATH=$(@D)|g' $(RK_FIRMWARE_TRUST_INI) | \
		sed -e 's|PATH=trust.img|PATH=$(@D)/trust.img|' > $(@D)/trust.ini
	$(@D)/tools/trust_merger --size 1024 1 $(@D)/trust.ini
endef

define RK_FIRMWARE_INSTALL_IMAGES_CMDS
	$(INSTALL) -D -m 0644 $(@D)/idbloader.img $(BINARIES_DIR)/u-boot/idbloader.img
	$(INSTALL) -D -m 0644 $(@D)/idbloader-spi.img $(BINARIES_DIR)/u-boot/spi/idbloader-spi.img
	# next two are needed later for U-Boot build
	$(INSTALL) -D -m 0644 $(@D)/$(RK_FIRMWARE_DDRFW) $(BINARIES_DIR)/firmware/$(RK_FIRMWARE_DDRFW)
	$(INSTALL) -D -m 0644 $(@D)/$(RK_FIRMWARE_SPILDR) $(BINARIES_DIR)/firmware/$(RK_FIRMWARE_SPILDR)
	$(INSTALL) -D -m 0644 $(@D)/trust.img $(BINARIES_DIR)/u-boot/trust.img
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
