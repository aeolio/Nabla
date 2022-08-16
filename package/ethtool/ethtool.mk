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
endif
