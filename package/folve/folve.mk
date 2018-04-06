################################################################################
#
# folve
#
################################################################################

FOLVE_VERSION = master
FOLVE_SITE = https://github.com/hzeller/folve
FOLVE_SITE_METHOD = git
FOLVE_INSTALL_STAGING = YES
FOLVE_DEPENDENCIES = flac libfuse libmicrohttpd libsndfile zita-convolver
FOLVE_LICENSE = GPL3
FOLVE_LICENSE_FILES = COPYING

#FOLVE_MAKE_ENV += " DESTDIR=$SYSROOT_PREFIX"
#FOLVE_MAKE_ENV += " FFTW_PATH=$SYSROOT_PREFIX/usr"

define FOLVE_BUILD_CMDS
	$(MAKE) CXX="$(TARGET_CXX)" LD="$(TARGET_LD)" -C $(@D)
endef

define FOLVE_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/usr/bin
	$(INSTALL) -m 0755 $(@D)/folve $(TARGET_DIR)/usr/bin
endef

$(eval $(generic-package))
