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
