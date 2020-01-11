################################################################################
#
# Broadcom Wifi and Bluetooth firmware for Radxa Rock Pi 4
#
################################################################################

ifeq ($(BR2_PACKAGE_ARMBIAN_FIRMWARE_AP6256),y)

define ARMBIAN_FIRMWARE_INSTALL_TARGET_AP6256
	$(INSTALL) -d $(TARGET_DIR)/lib/firmware/brcm
	$(INSTALL) -m 0644 $(@D)/rkwifi/config.txt $(TARGET_DIR)/lib/firmware/brcm
	$(INSTALL) -m 0644 $(@D)/rkwifi/nvram_ap6256.txt $(TARGET_DIR)/lib/firmware/brcm/brcmfmac43456-sdio.txt
	$(INSTALL) -m 0644 $(@D)/rkwifi/fw_bcm43456c5_ag.bin $(TARGET_DIR)/lib/firmware/brcm/brcmfmac43456-sdio.bin
endef

ARMBIAN_FIRMWARE_POST_INSTALL_TARGET_HOOKS += ARMBIAN_FIRMWARE_INSTALL_TARGET_AP6256

endif
