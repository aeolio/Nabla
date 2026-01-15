################################################################################
#
# Fragment file to exclude source code from extracting
#
################################################################################

# RT patch for Linux versions from 4.19 contains also changes in sample code
LINUX_HEADERS_EXCLUDES = configs *.bmp
ifeq ($(BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_3_18),y)
LINUX_HEADERS_EXCLUDES += samples
endif
ifeq ($(BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_4_4),y)
LINUX_HEADERS_EXCLUDES += samples
endif

# remove stale build versions of linux and linux-headers
define LINUX_HEADERS_REMOVE_STALE
	find $(BUILD_DIR) -type d \
		-regex .*/linux-[aedhrs-]*[0-9]*\.[0-9]*\.[0-9]* \
		-prune \
		-exec sh -c \
			'f=$$(basename $$0); \
			if [ "$${f##linux*-}" != "$(LINUX_VERSION)" ]; then \
				rm -fr "$$0"; \
			fi' \
			"{}" \;
endef
LINUX_HEADERS_PRE_DOWNLOAD_HOOKS += LINUX_HEADERS_REMOVE_STALE
