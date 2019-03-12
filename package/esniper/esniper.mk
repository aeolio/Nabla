################################################################################
#
# esniper
#
################################################################################

ESNIPER_VERSION = 2-35-0
ESNIPER_SOURCE = esniper-$(ESNIPER_VERSION).tgz
ESNIPER_SITE = https://sourceforge.net/projects/esniper/files/esniper/2.35.0
ESNIPER_DEPENDENCIES = libcurl libopenssl ca-certificates
ESNIPER_LICENSE = GPLv2+
ESNIPER_LICENSE_FILES = COPYING
ESNIPER_INSTALL_STAGING = NO
ESNIPER_INSTALL_TARGET = YES

ESNIPER_CONF_OPTS += --with-curl-config=$(STAGING_DIR)/usr/bin/curl-config

define ESNIPER_TARGET_CLEANUP_MANPAGES
	$(RM) -rf $(TARGET_DIR)/usr/share/man
endef
ESNIPER_POST_INSTALL_TARGET_HOOKS += ESNIPER_TARGET_CLEANUP_MANPAGES

$(eval $(autotools-package))
