################################################################################
#
# CPP httplib
#
################################################################################

CPP_HTTPLIB_VERSION = v0.8.2
CPP_HTTPLIB_SOURCE = cpp-httplib-$(CPP_HTTPLIB_VERSION).tar.gz
CPP_HTTPLIB_SITE = https://github.com/yhirose/cpp-httplib.git
CPP_HTTPLIB_SITE_METHOD = git
CPP_HTTPLIB_LICENSE = MIT
CPP_HTTPLIB_LICENSE_FILES = LICENSE
CPP_HTTPLIB_INSTALL_STAGING = YES
CPP_HTTPLIB_INSTALL_TARGET = NO

define CPP_HTTPLIB_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 0644 $(@D)/httplib.h $(STAGING_DIR)/usr/include/
endef

$(eval $(generic-package))
