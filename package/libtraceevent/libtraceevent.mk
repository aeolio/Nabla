################################################################################
#
# libtraceevent
#
################################################################################

LIBTRACEEVENT_VERSION = 1.6.3
LIBTRACEEVENT_SITE = https://git.kernel.org/pub/scm/libs/libtrace/libtraceevent.git/snapshot
LIBTRACEEVENT_LICENSE = GPL-2.0, LGPL-2.1
LIBTRACEEVENT_LICENSE_FILES = LICENSES

LIBTRACEEVENT_INSTALL_STAGING = YES

LIBTRACEEVENT_MAKE_OPTS = \
	CROSS_COMPILE=$(TARGET_CROSS) \
	pkgconfig_dir=usr/lib/pkgconfig \
	prefix=/usr

# defining CROSS_COMPILE is not sufficient, define CC also
define LIBTRACEEVENT_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		$(LIBTRACEEVENT_MAKE_OPTS) \
		CC=$(TARGET_CC)
endef

# trailing slash in DESTDIR is mandatory
define LIBTRACEEVENT_INSTALL_STAGING_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		$(LIBTRACEEVENT_MAKE_OPTS) \
		DESTDIR=$(STAGING_DIR)/ \
		install
endef

# trailing slash in DESTDIR is mandatory
define LIBTRACEEVENT_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		$(LIBTRACEEVENT_MAKE_OPTS) \
		DESTDIR=$(TARGET_DIR)/ \
		install
endef

$(eval $(generic-package))
