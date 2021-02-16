################################################################################
#
# Merging Technologies Ravenna ALSA
#
################################################################################

RAVENNA_ALSA_VERSION = 6ecdbc3bf4e6
RAVENNA_ALSA_SOURCE = ravenna-alsa-$(RAVENNA_ALSA_VERSION).tar.gz
RAVENNA_ALSA_SITE = https://bitbucket.org/MergingTechnologies/ravenna-alsa-lkm.git
RAVENNA_ALSA_SITE_METHOD = git
RAVENNA_ALSA_LICENSE = GPLv3
RAVENNA_ALSA_LICENSE_FILES = gpl-3.0.txt
RAVENNA_ALSA_INSTALL_STAGING = NO
RAVENNA_ALSA_INSTALL_TARGET = YES

RAVENNA_ALSA_MODULE_SUBDIRS = driver

# Ravenna needs CONFIG_NETFILTER and CONFIG_NETLINK_DIAG enabled in the kernel config
RAVENNA_ALSA_MODULE_MAKE_OPTS = \
	KVER=$(LINUX_VERSION_PROBED) \
	KSRC=$(LINUX_DIR)

define RAVENNA_ALSA_INSTALL_INIT_SYSV
	$(INSTALL) -m 0755 -D $(BR2_EXTERNAL)/package/ravenna-alsa/S85ravenna \
		$(TARGET_DIR)/etc/init.d/S85ravenna
endef

$(eval $(kernel-module))
$(eval $(generic-package))
