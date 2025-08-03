################################################################################
#
# pihole-ftl
#
################################################################################

PIHOLE_FTL_VERSION = 6.1.4
PIHOLE_FTL_SITE = $(call github,aeolio,pihole-ftl,e3b0ecb)
#PIHOLE_FTL_SITE = /home/iago/staging/pi-hole/pihole-ftl
#PIHOLE_FTL_SITE_METHOD = local
PIHOLE_FTL_LICENSE = EUPL-1.2
PIHOLE_FTL_LICENSE_FILES = LICENSE

PIHOLE_FTL_DEPENDENCIES += nettle \
	libcurl \
	libidn2 \
	libunistring

ifeq ($(BR2_PACKAGE_PIHOLE_FTL_READLINE),y)
PIHOLE_FTL_DEPENDENCIES += readline
endif

ifeq ($(BR2_PACKAGE_PIHOLE_FTL_TLS),y)
PIHOLE_FTL_DEPENDENCIES += mbedtls
endif

# build locations
PIHOLE_FTL_CMAKEFILE = $(@D)/src/CMakeLists.txt
# target locations
PIHOLE_FTL_CONFIGDIR = etc/pihole
# template directory
PIHOLE_FTL_TEMPLATE_DIR = advanced/Templates
# database scripts
PIHOLE_FTL_DB_INIT_SQL = $(PIHOLE_FTL_TEMPLATE_DIR)/gravity.db.sql
PIHOLE_FTL_DB_COPY_SQL = $(PIHOLE_FTL_TEMPLATE_DIR)/gravity_copy.sql

# build with gravity support
PIHOLE_FTL_CONF_OPTS += -DGRAVITY=ON

# sql scripts from github.com/pi-hole/pi-hole
PIHOLE_FTL_SCRIPTS = https://raw.githubusercontent.com/pi-hole/pi-hole/refs/heads/master
define PIHOLE_FTL_DOWNLOAD_SQL_SCRIPTS
	mkdir -p "$(@D)/$(PIHOLE_FTL_TEMPLATE_DIR)"
	wget "$(PIHOLE_FTL_SCRIPTS)/$(PIHOLE_FTL_DB_INIT_SQL)" -O "$(@D)/$(PIHOLE_FTL_DB_INIT_SQL)"
	wget "$(PIHOLE_FTL_SCRIPTS)/$(PIHOLE_FTL_DB_COPY_SQL)" -O "$(@D)/$(PIHOLE_FTL_DB_COPY_SQL)"
	$(SED) 's/.timeout/PRAGMA busy_timeout =/' $(@D)/$(PIHOLE_FTL_DB_COPY_SQL)
endef
PIHOLE_FTL_POST_EXTRACT_HOOKS += PIHOLE_FTL_DOWNLOAD_SQL_SCRIPTS

# pi-hole unconditionally defines stack-protector-strong, which
# leads to linker errors in toolchains without this feature
ifeq ($(BR2_TOOLCHAIN_HAS_SSP),)
define PIHOLE_FTL_DISABLE_STACK_PROTECTOR
	$(SED) '/HARDENING_FLAGS/ s/-fstack-protector[-a-z]*//' $(PIHOLE_FTL_CMAKEFILE)
endef
PIHOLE_FTL_PRE_CONFIGURE_HOOKS += PIHOLE_FTL_DISABLE_STACK_PROTECTOR
endif

# development workaround
define PIHOLE_FTL_GRAVITY
	ln -fs $(PIHOLE_FTL_PKGDIR)/extrafiles/gravity.c $(@D)/src/gravity.c
	ln -fs $(PIHOLE_FTL_PKGDIR)/extrafiles/gravity.h $(@D)/src/gravity.h
endef
PIHOLE_FTL_PRE_CONFIGURE_HOOKS += PIHOLE_FTL_GRAVITY

# install configuration file, default log directory, templates
define PIHOLE_FTL_INSTALL_EXTRA_FILES
	$(INSTALL) -m 755 -d $(TARGET_DIR)/$(PIHOLE_FTL_CONFIGDIR)
	$(INSTALL) -m 0644 -D $(PIHOLE_FTL_PKGDIR)/pihole.toml \
		$(TARGET_DIR)/$(PIHOLE_FTL_CONFIGDIR)/pihole.toml
	$(INSTALL) -m 755 -d $(TARGET_DIR)/var/log/pihole
	$(INSTALL) -m 755 -d $(TARGET_DIR)/var/lib/pihole/$(PIHOLE_FTL_TEMPLATE_DIR)
	$(INSTALL) -m 0644 -D $(@D)/$(PIHOLE_FTL_DB_INIT_SQL) \
		$(TARGET_DIR)/var/lib/pihole/$(PIHOLE_FTL_DB_INIT_SQL)
	$(INSTALL) -m 0644 -D $(@D)/$(PIHOLE_FTL_DB_COPY_SQL) \
		$(TARGET_DIR)/var/lib/pihole/$(PIHOLE_FTL_DB_COPY_SQL)
endef
PIHOLE_FTL_POST_INSTALL_TARGET_HOOKS += PIHOLE_FTL_INSTALL_EXTRA_FILES

define PIHOLE_FTL_INSTALL_INIT_SYSV
	$(INSTALL) -m 0755 -D $(PIHOLE_FTL_PKGDIR)/S50pihole-FTL \
		$(TARGET_DIR)/etc/init.d/S50pihole-FTL
endef

# ftldns user
define PIHOLE_FTL_USERS
	pihole -1 pihole -1 * - - - ftldns daemon
endef

$(eval $(cmake-package))
