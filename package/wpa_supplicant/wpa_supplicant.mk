################################################################################
#
# additional wpa_supplicant logic
#
################################################################################

# remove default config file
define WPA_SUPPLICANT_REMOVE_CONFIG
	rm -f $(TARGET_DIR)/etc/wpa_supplicant.conf
endef
WPA_SUPPLICANT_POST_INSTALL_TARGET_HOOKS += WPA_SUPPLICANT_REMOVE_CONFIG
