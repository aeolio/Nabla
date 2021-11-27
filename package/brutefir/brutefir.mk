################################################################################
#
# brutefir
#
################################################################################

BRUTEFIR_VERSION = 1.0o
BRUTEFIR_SITE = https://www.torger.se/anders/files
BRUTEFIR_LICENSE = GPLv2+
BRUTEFIR_LICENSE_FILES = COPYING
BRUTEFIR_DEPENDENCIES = fftw-single fftw-double

BRUTEFIR_MAKE_ENV += " DESTDIR=$STAGING_DIR"
BRUTEFIR_MAKE_ENV += " FFTW_PATH=$STAGING_DIR/usr"

BRUTEFIR_DEFAULTS_DIR += "$(BR2_EXTERNAL_NABLA_PATH)/package/brutefir/defaults"

define BRUTEFIR_BUILD_CMDS
	$(MAKE) CC="$(TARGET_CC)" LD="$(TARGET_LD)" $(BRUTEFIR_MAKE_ENV) -C $(@D) all
endef

define BRUTEFIR_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/usr/lib/brutefir
	$(INSTALL) -m 0755 $(@D)/brutefir $(TARGET_DIR)/usr/bin
	$(INSTALL) -m 0755 $(@D)/*.bfio $(TARGET_DIR)/usr/lib/brutefir
	$(INSTALL) -m 0755 $(@D)/*.bflogic $(TARGET_DIR)/usr/lib/brutefir
	$(INSTALL) -m 0755 $(BRUTEFIR_DEFAULTS_DIR)/S95brutefir $(TARGET_DIR)/etc/init.d
	$(INSTALL) -m 0644 -D $(BRUTEFIR_DEFAULTS_DIR)/asound.conf $(TARGET_DIR)/etc/asound.conf
endef

$(eval $(generic-package))
