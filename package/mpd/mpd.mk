################################################################################
#
# additional mpd flags
#
################################################################################

# disable some standard features
MPD_CONF_OPTS += \
	-Dlibfuzzer=false \
	-Drecorder=false

# disable wave-encoder if streaming is not enabled
ifneq ($(BR2_PACKAGE_MPD_HTTPD_OUTPUT),y)
MPD_CONF_OPTS += -Dwave_encoder=false
endif

# Yan's realtime patch
MPD_CONF_OPTS += -Drtopt=true

# mpd user
define MPD_USERS
	mpd 101 audio -1 * /var/lib/mpd - - music player
endef

# this is necessary because fragment files do not get processed by inner-generic-package
PACKAGES_USERS += $(MPD_USERS)$(sep)

# modify init.d configuration
MPD_INIT_SCRIPT = $(TARGET_DIR)/etc/init.d/S95mpd
define MPD_MODIFY_INIT_SCRIPT
	if [ -f "$(MPD_INIT_SCRIPT)" ]; then \
		patch $(MPD_INIT_SCRIPT) \
			-i $(BR2_EXTERNAL)/package/mpd/0000-modify-startup-script.patch; \
	fi
endef
MPD_POST_INSTALL_TARGET_HOOKS += MPD_MODIFY_INIT_SCRIPT
