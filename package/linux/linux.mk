################################################################################
#
# Fragment file mainly for RockPi4 build
#
################################################################################

# Compiling older releases of kernel sources with GCC 8 results in warnings that
# are treated as errors. To be able to build the standard kernel for RockPi4
# without modification, some of these new compiler directives have to be removed.
# Use for Radxa Rock Pi 4 vendor tree only
target = $(findstring rockpi4,$(BR2_DEFCONFIG))
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
endif # rockpi4 && GCC 8

# if patch directory exists, symbolic link should also be present
# the 'custom' version must be explicitly excluded from this logic
define LINUX_PATCH_ASSURANCE
	patch_dirs=$(BR2_GLOBAL_PATCH_DIR); \
	linux_version=$(BR2_LINUX_KERNEL_VERSION); \
	linux_series=$${linux_version%.*}; \
	if [ $${linux_version} != $${linux_series} ]; then \
		for p in $${patch_dirs}; do \
			if [ -d "$$p/linux/$${linux_series}" ] && [ ! -h "$$p/linux/$${linux_version}" ]; then \
				echo "patch directory link missing"; \
				exit -1; \
			fi \
		done \
	fi
endef
LINUX_PRE_PATCH_HOOKS += LINUX_PATCH_ASSURANCE

# install dtb overlays
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
