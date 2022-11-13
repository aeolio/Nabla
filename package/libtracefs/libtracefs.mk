################################################################################
#
# libtracefs
#
################################################################################

LIBTRACEFS_VERSION = 1.5.0
LIBTRACEFS_SITE = https://git.kernel.org/pub/scm/libs/libtrace/libtracefs.git/snapshot
LIBTRACEFS_LICENSE = GPL-2.0, LGPL-2.1
LIBTRACEFS_LICENSE_FILES = LICENSES

LIBTRACEFS_INSTALL_STAGING = YES
LIBTRACEFS_DEPENDENCIES = libtraceevent

LIBTRACEFS_MAKE_OPTS = \
	CROSS_COMPILE=$(TARGET_CROSS) \
	pkgconfig_dir=usr/lib/pkgconfig \
	prefix=/usr

# defining CROSS_COMPILE is not sufficient, define CC also
define LIBTRACEFS_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		$(LIBTRACEFS_MAKE_OPTS) \
		CC=$(TARGET_CC)
endef

# trailing slash in DESTDIR is mandatory
define LIBTRACEFS_INSTALL_STAGING_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		$(LIBTRACEFS_MAKE_OPTS) \
		DESTDIR=$(STAGING_DIR)/ \
		install
endef

# trailing slash in DESTDIR is mandatory
define LIBTRACEFS_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		$(LIBTRACEFS_MAKE_OPTS) \
		DESTDIR=$(TARGET_DIR)/ \
		install
endef

$(eval $(generic-package))
