################################################################################
#
# folve
#
################################################################################

FOLVE_VERSION = 2022.08
FOLVE_SITE = $(call github,hzeller,folve,master)
FOLVE_INSTALL_STAGING = YES
FOLVE_DEPENDENCIES = host-pkgconf flac libfuse3 libmicrohttpd libsndfile zita-convolver
FOLVE_LICENSE = GPL3
FOLVE_LICENSE_FILES = COPYING

FOLVE_MAKE_ENV = \
	SNDFILE_INC= \
	SNDFILE_LIB=-lsndfile \
	FUSE_INC=-I$(STAGING_DIR)/usr/include/fuse3 \
	FUSE_LIB=-lfuse3

FOLVE_MAKE_OPTS = \
	CXX="$(TARGET_CXX)" \
	LD="$(TARGET_LD)"

define FOLVE_BUILD_CMDS
	$(FOLVE_MAKE_ENV) $(MAKE) $(FOLVE_MAKE_OPTS) -C $(@D)
endef

define FOLVE_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/usr/bin
	$(INSTALL) -m 0755 $(@D)/folve $(TARGET_DIR)/usr/bin
endef

$(eval $(generic-package))
