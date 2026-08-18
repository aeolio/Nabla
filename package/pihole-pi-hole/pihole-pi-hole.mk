################################################################################
#
# pihole-pi-hole
#
################################################################################

PIHOLE_PI_HOLE_VERSION = 6.4.3
PIHOLE_PI_HOLE_SITE = $(call github,pi-hole,pi-hole,v$(PIHOLE_PI_HOLE_VERSION))
PIHOLE_PI_HOLE_LICENSE = EUPL-1.2
PIHOLE_PI_HOLE_LICENSE_FILES = LICENSE

# target directory
PIHOLE_PI_HOLE_TARGET_DIR = $(TARGET_DIR)/var/lib/pihole
# template directory
PIHOLE_PI_HOLE_TEMPLATE_DIR = advanced/Templates
# database scripts
PIHOLE_PI_HOLE_DB_INIT_SQL = $(PIHOLE_PI_HOLE_TEMPLATE_DIR)/gravity.db.sql
PIHOLE_PI_HOLE_DB_COPY_SQL = $(PIHOLE_PI_HOLE_TEMPLATE_DIR)/gravity_copy.sql

define PIHOLE_PI_HOLE_INSTALL_TARGET_CMDS
	$(INSTALL) -m 755 -d $(PIHOLE_PI_HOLE_TARGET_DIR)/$(PIHOLE_PI_HOLE_TEMPLATE_DIR)
	$(INSTALL) -m 0644 -D $(@D)/$(PIHOLE_PI_HOLE_DB_INIT_SQL) \
		$(PIHOLE_PI_HOLE_TARGET_DIR)/$(PIHOLE_PI_HOLE_DB_INIT_SQL)
	$(INSTALL) -m 0644 -D $(@D)/$(PIHOLE_PI_HOLE_DB_COPY_SQL) \
		$(PIHOLE_PI_HOLE_TARGET_DIR)/$(PIHOLE_PI_HOLE_DB_COPY_SQL)
endef

$(eval $(generic-package))
