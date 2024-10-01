################################################################################
#
# Fragment file for xenomai
#
################################################################################

# these resolve warnings treated as errors when compiling with a glibc toolchain
XENOMAI_CFLAGS += -Wno-stringop-overread
XENOMAI_CFLAGS += -Wno-incompatible-pointer-types
XENOMAI_CFLAGS += -Wno-deprecated-declarations
XENOMAI_CFLAGS += -DHAVE_PTHREAD_MUTEXATTR_SETROBUST_NP

XENOMAI_CONF_ENV = CFLAGS="$(TARGET_CFLAGS) $(XENOMAI_CFLAGS)"

# disable conflicting options in Linux kernel
ifeq ($(BR2_PACKAGE_XENOMAI),y)
define XENOMAI_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_DISABLE_OPT,CONFIG_PREEMPT_RT)
endef
# this is necessary because fragment files do not get processed by inner-generic-package
PACKAGES_LINUX_CONFIG_FIXUPS += $(XENOMAI_LINUX_CONFIG_FIXUPS)$(sep)
endif
