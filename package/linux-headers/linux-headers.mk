################################################################################
#
# Fragment file to exclude source code from extracting
#
################################################################################

# RT patch for Linux 4.14 contains also changes in sample code
ifeq ($(BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_4_14),y)
LINUX_HEADERS_EXCLUDES = configs *.bmp
else
LINUX_HEADERS_EXCLUDES = configs samples *.bmp
endif
