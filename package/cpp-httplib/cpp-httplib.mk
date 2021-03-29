################################################################################
#
# CPP httplib
#
################################################################################

CPP_HTTPLIB_VERSION = 0.8.2
AES67_DAEMON_SITE = $(call github,yhirose,cpp-httplib,v$(CPP_HTTPLIB_VERSION))
CPP_HTTPLIB_LICENSE = MIT
CPP_HTTPLIB_LICENSE_FILES = LICENSE
CPP_HTTPLIB_INSTALL_STAGING = YES
CPP_HTTPLIB_INSTALL_TARGET = NO

define CPP_HTTPLIB_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 0644 $(@D)/httplib.h $(STAGING_DIR)/usr/include/
endef

$(eval $(generic-package))
