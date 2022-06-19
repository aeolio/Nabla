################################################################################
#
# additional initscripts logic
#
################################################################################

INITSCRIPTS_STARTUP_FILE = $(TARGET_DIR)/etc/init.d/rcS

# modify central startup script
define INISCRIPTS_BOOTLOG
	echo $(INITSCRIPTS_STARTUP_FILE)
	if [ -f "$(INITSCRIPTS_STARTUP_FILE)" ]; then \
		patch $(INITSCRIPTS_STARTUP_FILE) \
			$(BR2_EXTERNAL)/package/initscripts/0000-redirect-output-to-boot-log.patch; \
	fi
endef
INITSCRIPTS_POST_INSTALL_TARGET_HOOKS += INISCRIPTS_BOOTLOG
