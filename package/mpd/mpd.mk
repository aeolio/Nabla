################################################################################
#
# additional mpd flags
#
################################################################################

# Yan's realtime patch
MPD_CONF_OPTS += -Drtopt=true

# mpd user
define MPD_USERS
	mpd 101 audio -1 * /var/lib/mpd - - music player
endef

# this is necessary because fragment files do not get processed by inner-generic-package
PACKAGES_USERS += $(MPD_USERS)$(sep)

MPD_INIT_SCRIPT = $(TARGET_DIR)/etc/init.d/S95mpd

# modify init.d configuration
define MPD_MODIFY_INIT_SCRIPT
	if [ -f "$(MPD_INIT_SCRIPT)" ]; then \
		patch $(MPD_INIT_SCRIPT) \
			$(BR2_EXTERNAL)/package/mpd/0000-modify-startup-script.patch; \
	fi
endef
MPD_POST_INSTALL_TARGET_HOOKS += MPD_MODIFY_INIT_SCRIPT

# if a base version patch directory exists,
# a directory for the current version must also be present
define MPD_PATCH_ASSURANCE
	patch_dirs=$(BR2_GLOBAL_PATCH_DIR); \
	pkg_name=mpd; \
	pkg_version=$(MPD_VERSION); \
	base_version=$$(expr match $$pkg_version '\([0-9]\+.[0-9]\+\)'); \
	if [ $${pkg_version} != $${base_version} ]; then \
		for p in $${patch_dirs}; do \
			if	[ -d "$$p/$$pkg_name/$${base_version}" ] && \
				[ ! -h "$$p/$$pkg_name/$${pkg_version}" ]; then \
				echo "patch directory link missing for $${pkg_version}"; \
				exit -1; \
			fi \
		done \
	fi
endef
MPD_PRE_PATCH_HOOKS += MPD_PATCH_ASSURANCE
