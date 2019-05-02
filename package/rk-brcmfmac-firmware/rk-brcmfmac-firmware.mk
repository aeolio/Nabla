################################################################################
#
# Broadcom Wifi and Bluetooth firmware for Radxa Rock Pi 4
#
################################################################################

RK_BRCMFMAC_FIRMWARE_VERSION = fe584970a1f8e718540a3cec4838e7a4cad5f263
RK_BRCMFMAC_FIRMWARE_SITE = $(call github,armbian,firmware,$(RK_BRCMFMAC_FIRMWARE_VERSION))
RK_BRCMFMAC_FIRMWARE_LICENSE = PROPRIETARY
RK_BRCMFMAC_FIRMWARE_LICENSE_FILES = 

define RK_BRCMFMAC_FIRMWARE_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/lib/firmware/brcm
	$(INSTALL) -m 0644 $(@D)/rkwifi/config.txt $(TARGET_DIR)/lib/firmware/brcm
	$(INSTALL) -m 0644 $(@D)/rkwifi/nvram_ap6256.txt $(TARGET_DIR)/lib/firmware/brcm
	$(INSTALL) -m 0644 $(@D)/rkwifi/fw_bcm43456c5_ag.bin $(TARGET_DIR)/lib/firmware/brcm
endef

$(eval $(generic-package))
