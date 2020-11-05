################################################################################
#
# additional e2fsprogs flags
#
################################################################################

# some of the packages in e2fsprogs can be disabled
E2FSPROGS_CONF_OPTS += \
  --without-crond-dir \
  --without-udev-rules-dir \
  --without-systemd-unit-dir \
  --with-doc=no \
  --with-ext2ed=no \
  --with-intl=no \
  --with-misc=no \
  --with-po=no \
  --with-tests=no \
  --with-util=no

E2FSPROGS_MAKE_OPTS += DESTDIR=$(TARGET_DIR)

# Override installation script to force installation of e2fsck only
define E2FSPROGS_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(E2FSPROGS_MAKE_OPTS) -C $(@D)/lib/et install-shlibs 
	$(TARGET_MAKE_ENV) $(MAKE) $(E2FSPROGS_MAKE_OPTS) -C $(@D)/lib/ext2fs install-shlibs 
	$(TARGET_MAKE_ENV) $(MAKE) $(E2FSPROGS_MAKE_OPTS) -C $(@D)/lib/e2p install-shlibs 
	$(TARGET_MAKE_ENV) $(MAKE) $(E2FSPROGS_MAKE_OPTS) -C $(@D)/e2fsck install 
endef
