################################################################################
#
# additional initscripts logic
#
################################################################################

INITSCRIPTS_DIRECTORY = $(TARGET_DIR)/etc/init.d
INITSCRIPTS_STARTUP_FILE = $(INITSCRIPTS_DIRECTORY)/rcS

# initscripts should not install S11modules unless BR2_SYSTEM_CONNECT_WIFI is set
ifneq ($(BR2_SYSTEM_CONNECT_WIFI),y)
define INITSCRIPTS_MODULES
	rm -f $(INITSCRIPTS_DIRECTORY)/S11modules
endef
INITSCRIPTS_POST_INSTALL_TARGET_HOOKS += INITSCRIPTS_MODULES
endif # BR2_SYSTEM_CONNECT_WIFI

# modify central startup script
define INITSCRIPTS_BOOTLOG
	if [ -f "$(INITSCRIPTS_STARTUP_FILE)" ]; then \
		patch $(INITSCRIPTS_STARTUP_FILE) \
			$(BR2_EXTERNAL)/package/initscripts/0000-redirect-output-to-boot-log.patch; \
	fi
endef
INITSCRIPTS_POST_INSTALL_TARGET_HOOKS += INITSCRIPTS_BOOTLOG
