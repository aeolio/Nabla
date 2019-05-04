################################################################################
#
# Fragment file for RockPi4 build
#
################################################################################

target = $(findstring rockpi4,$(BR2_DEFCONFIG))

# Compiling older releases of kernel sources with GCC 8 results in warnings that are treated 
# as errors. To be able to build the standard kernel for RockPi4 without modification, some 
# of these new compiler directives have to be removed. 
# Use for Radxa Rock Pi 4 vendor tree only
ifeq ($(target),rockpi4)
ifeq ($(BR2_TOOLCHAIN_GCC_AT_LEAST_8),y)
LINUX_MAKE_ENV += KCFLAGS='-Wno-packed-not-aligned \
 	-Wno-attribute-alias \
	-Wno-stringop-truncation \
	-Wno-array-bounds \
	-Wno-sizeof-pointer-memaccess \
	-Wno-stringop-overflow \
	-Wno-unused-function'
endif
endif

ifeq ($(BR2_LINUX_KERNEL_DTB_OVERLAY_SUPPORT),y)
define LINUX_INSTALL_OVERLAYS
	$(foreach d,$(wildcard $(@D)/arch/arm64/boot/dts/*), \
		$(foreach f,$(wildcard $(d)/overlays/*.dtbo), \
			$(INSTALL) -D -m 0644 $(f) $(BINARIES_DIR)/overlays/$(notdir $(f))
		)
	)

	$(foreach d,$(wildcard $(@D)/arch/arm64/boot/dts/*), \
		$(foreach f,$(wildcard $(d)/overlays/*.conf), \
			$(INSTALL) -D -m 0644 $(f) $(BINARIES_DIR)/overlays/$(notdir $(f))
		)
	)
endef
LINUX_POST_INSTALL_IMAGES_HOOKS += LINUX_INSTALL_OVERLAYS
endif
