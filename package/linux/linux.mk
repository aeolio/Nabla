################################################################################
#
# additional linux logic
#
################################################################################

# if a base version patch directory exists, a directory 
# for the current version should also be present
define LINUX_PATCH_ASSURANCE
	patch_dirs=$(BR2_GLOBAL_PATCH_DIR); \
	pkg_name=linux; \
	pkg_version=$(BR2_LINUX_KERNEL_VERSION); \
	base_version=$$(expr match $$pkg_version '\([0-9]\+.[0-9]\+\)'); \
	if [ $${pkg_version} != $${base_version} ]; then \
		for p in $${patch_dirs}; do \
			if	[ -d "$$p/$$pkg_name/$${base_version}" ] && \
				[ ! -d "$$p/$$pkg_name/$${pkg_version}" ]; then \
				echo "Patch directory missing for $${pkg_version}"; \
				exit -1; \
			fi \
		done \
	fi
endef
LINUX_PRE_PATCH_HOOKS += LINUX_PATCH_ASSURANCE

# remove old versions of kernel modules immediately before target installation
define LINUX_CLEAN_LIB_MODULES
	module_dir=$(TARGET_DIR)/lib/modules; \
	version_info=$(@D)/include/config/kernel.release; \
	linux_version=$$(cat $$version_info); \
	for d in $$(ls $$module_dir); do \
		if [ $$d != $$linux_version ]; then \
			rm -fr $$module_dir/$$d; \
		fi \
	done
endef
LINUX_PRE_INSTALL_TARGET_HOOKS += LINUX_CLEAN_LIB_MODULES

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
