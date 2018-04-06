################################################################################
#
# zita-convolver
#
################################################################################

ZITA_CONVOLVER_VERSION = 3.1.0
ZITA_CONVOLVER_SOURCE = zita-convolver-$(ZITA_CONVOLVER_VERSION).tar.bz2
ZITA_CONVOLVER_SITE = http://kokkinizita.linuxaudio.org/linuxaudio/downloads
ZITA_CONVOLVER_INSTALL_STAGING = YES
ZITA_CONVOLVER_DEPENDENCIES = fftw
ZITA_CONVOLVER_LICENSE = GPL3
ZITA_CONVOLVER_LICENSE_FILES = COPYING

ZITA_CONVOLVER_MAKE_ENV = FFTW_PATH=$(TARGET_DIR)/usr

define ZITA_CONVOLVER_BUILD_CMDS
	$(ZITA_CONVOLVER_MAKE_ENV) $(MAKE) $(TARGET_CONFIGURE_OPTS) \
		$(ZITA_CONVOLVER_MAKE_OPTS) -C $(@D)/libs
endef

define ZITA_CONVOLVER_INSTALL_STAGING_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(TARGET_CONFIGURE_OPTS) \
		$(ZITA_CONVOLVER_MAKE_OPTS) DESTDIR=$(STAGING_DIR) -C $(@D)/libs install
endef

define ZITA_CONVOLVER_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(TARGET_CONFIGURE_OPTS) \
		$(ZITA_CONVOLVER_MAKE_OPTS) DESTDIR=$(TARGET_DIR) -C $(@D)/libs install
endef

$(eval $(generic-package))
