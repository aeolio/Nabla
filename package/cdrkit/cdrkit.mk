################################################################################
#
# cdrkit - patch for latest version
#
################################################################################

CDRKIT_PATCH = cdrkit_$(CDRKIT_VERSION)-3.diff.gz

# fix host build, it seems to miss HOSTCC and HOSTCXX definitions
HOST_CDRKIT_CONF_OPTS = \
	-DCMAKE_C_COMPILER=""$(HOSTCC)"" \
	-DCMAKE_CXX_COMPILER=""$(HOSTCXX)""
