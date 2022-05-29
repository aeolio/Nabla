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

# remove ifupdown scripts that interfere with 
# wpa_supplicant started from init script
define WPA_SUPPLICANT_REMOVE_IFUPDOWN_SCRIPTS
	rm -f $(TARGET_DIR)/etc/network/if-down.d/wpasupplicant
	rm -f $(TARGET_DIR)/etc/network/if-up.d/wpasupplicant
endef
WPA_SUPPLICANT_POST_INSTALL_TARGET_HOOKS += WPA_SUPPLICANT_REMOVE_IFUPDOWN_SCRIPTS
