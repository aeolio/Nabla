################################################################################
#
# brutefir
#
################################################################################

BRUTEFIR_VERSION = 1.1.2
BRUTEFIR_SITE = https://www.torger.se/anders/files
BRUTEFIR_LICENSE = GPLv2+
BRUTEFIR_LICENSE_FILES = COPYING
BRUTEFIR_DEPENDENCIES = alsa-lib fftw-single fftw-double

BRUTEFIR_MAKE_ENV = \
	$(TARGET_MAKE_ENV) \
	DESTDIR=$(TARGET_DIR) \
	FFTW_PATH=$(STAGING_DIR)/usr

BRUTEFIR_CFLAGS = \
	$(TARGET_CFLAGS) \
	-D_SVID_SOURCE

BRUTEFIR_MAKE_OPTS = \
	$(TARGET_MAKE_OPTS) \
	CC=$(TARGET_CC) \
	LD=$(TARGET_LD) \
	CFLAGS="$(BRUTEFIR_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)"

define BRUTEFIR_BUILD_CMDS
	$(BRUTEFIR_MAKE_ENV) $(MAKE) $(BRUTEFIR_MAKE_OPTS) -C $(@D) all
endef

BRUTEFIR_CONFIG = "$(BRUTEFIR_PKGDIR)/defaults"

define BRUTEFIR_INSTALL_CONFIG_FILES
	$(INSTALL) -D -m 0755 $(BRUTEFIR_CONFIG)/S95brutefir $(TARGET_DIR)/etc/init.d
	chmod 0755 $(TARGET_DIR)/etc/init.d/S95brutefir
	$(INSTALL) -D -m 0644 $(BRUTEFIR_CONFIG)/asound.conf $(TARGET_DIR)/etc/asound.conf
endef

define BRUTEFIR_INSTALL_TARGET_CMDS
	$(BRUTEFIR_MAKE_ENV) $(MAKE) $(BRUTEFIR_MAKE_OPTS) -C $(@D) install
	$(BRUTEFIR_INSTALL_CONFIG_FILES)
endef

$(eval $(generic-package))
