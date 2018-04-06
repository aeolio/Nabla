################################################################################
#
# fftwf -- needed by brutefir
#
################################################################################

FFTWF_VERSION = $(FFTW_VERSION)
FFTWF_SOURCE = fftw-$(FFTW_VERSION).tar.gz
FFTWF_SITE = $(FFTW_SITE)
FFTWF_INSTALL_STAGING = YES
FFTWF_LICENSE = GPLv2+
FFTWF_LICENSE_FILES = COPYING
FFTWF_DEPENDENCIES = fftw

# this is the single precision library exclusively for brutefir
FFTWF_CONF_OPTS = --disable-fortran
FFTWF_CONF_OPTS += --enable-float

FFTWF_CFLAGS = $(TARGET_CFLAGS)
ifeq ($(BR2_PACKAGE_FFTW_FAST),y)
FFTWF_CFLAGS += -O3 -ffast-math
endif

# x86 optimisations
FFTWF_CONF_OPTS += $(if $(BR2_PACKAGE_FFTW_USE_SSE),--enable,--disable)-sse
FFTWF_CONF_OPTS += $(if $(BR2_PACKAGE_FFTW_USE_SSE2),--enable,--disable)-sse2

# ARM optimisations
FFTWF_CONF_OPTS += $(if $(BR2_PACKAGE_FFTW_USE_NEON),--enable,--disable)-neon
FFTWF_CFLAGS += $(if $(BR2_PACKAGE_FFTW_USE_NEON),-mfpu=neon)

# Generic optimisations, different from HEAD
ifeq ($(BR2_GCC_ENABLE_OPENMP),y)
FFTWF_CONF_OPTS += --enable-openmp
else ifeq ($(BR2_TOOLCHAIN_HAS_THREADS),y)
FFTWF_CONF_OPTS += --enable-threads --with-combined-threads
else
FFTWF_CONF_OPTS += --disable-threads --disable-openmp
endif

FFTWF_CONF_OPTS += CFLAGS="$(FFTWF_CFLAGS)"

$(eval $(autotools-package))
