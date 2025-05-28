################################################################################
#
# pihole-ftl
#
################################################################################

PIHOLE_WEB_VERSION = 6.1
PIHOLE_WEB_SITE = $(call github,pi-hole,web,v$(PIHOLE_WEB_VERSION))
PIHOLE_WEB_LICENSE = EUPL-1.2
PIHOLE_WEB_LICENSE_FILES = LICENSE

define PIHOLE_WEB_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/var/www/html/admin
	rsync -lprtv --chmod=a=r,u+w,Da+x --delete \
		--exclude=.* --exclude=*.md --exclude=package*.json \
		$(@D)/ $(TARGET_DIR)/var/www/html/admin/
endef

$(eval $(generic-package))
