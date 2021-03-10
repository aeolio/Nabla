################################################################################
#
# Fragment file to exclude source code from extracting
#
################################################################################

# RT patch for newer Linux versions contains also changes in sample code
LINUX_HEADERS_EXCLUDES = configs *.bmp
ifeq ($(BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_4_4),y)
LINUX_HEADERS_EXCLUDES += samples
endif
ifeq ($(BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_3_18),y)
LINUX_HEADERS_EXCLUDES += samples
endif
# RT patch for 4.19 kernel has patches in arm/configs
ifeq ($(BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_4_19),y)
LINUX_HEADERS_EXCLUDES = *.bmp
endif
