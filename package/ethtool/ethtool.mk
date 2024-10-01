################################################################################
#
# additional ethtool logic
#
################################################################################

# linux kernel needs netlink interface, if ethtool is selected
ifeq ($(BR2_PACKAGE_ETHTOOL),y)
define ETHTOOL_LINUX_CONFIG_FIXUPS
	$(call KCONFIG_ENABLE_OPT,CONFIG_ETHTOOL_NETLINK)
endef
# this is necessary because fragment files do not get processed by inner-generic-package
PACKAGES_LINUX_CONFIG_FIXUPS += $(ETHTOOL_LINUX_CONFIG_FIXUPS)$(sep)
endif

# _GNU_SOURCE is needed for musl sys/types.h to define u_int32_t
ifeq ($(BR2_TOOLCHAIN_USES_MUSL),y)
ETHTOOL_CONF_ENV += CFLAGS="$(TARGET_CFLAGS) -D_GNU_SOURCE"
endif
