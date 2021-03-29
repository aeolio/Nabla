################################################################################
#
# AES67 Daemon
#
################################################################################

AES67_DAEMON_VERSION = 1.1
AES67_DAEMON_SITE = $(call github,bondagit,aes67-linux-daemon,v$(AES67_DAEMON_VERSION))
AES67_DAEMON_LICENSE = GPLv3
AES67_DAEMON_LICENSE_FILES = LICENSE
AES67_DAEMON_INSTALL_STAGING = NO
AES67_DAEMON_INSTALL_TARGET = YES
AES67_DAEMON_DEPENDENCIES = avahi cpp-httplib boost ravenna-alsa

AES67_DAEMON_SUBDIR = daemon

AES67_DAEMON_CONF_OPTS += -DCMAKE_PREFIX_PATH="$(STAGING_DIR);$(STAGING_DIR)/usr"
AES67_DAEMON_CONF_OPTS += -DRAVENNA_ALSA_LKM_DIR="$(BUILD_DIR)/ravenna-alsa-$(RAVENNA_ALSA_VERSION)"

define AES67_DAEMON_MODIFY_CONFIG
	sed -e '/http_base_dir/ s/\.\.\//\/var\/lib\/ravenna\//' \
		-e '/log_severity/ s/[0-9]/2/' \
		-e '/tic_frame_size_at_1fs/ s/[0-9]*,/192,/' \
		-e '/syslog_proto/ s/none/local/' \
		-e '/status_file/ s/\.\/status.json/\/var\/lib\/ravenna\/status.json/' \
		-i $(@D)/$(AES67_DAEMON_SUBDIR)/daemon.conf
endef

AES67_DAEMON_POST_BUILD_HOOKS += AES67_DAEMON_MODIFY_CONFIG

# there is no install target in this makefile
define AES67_DAEMON_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/$(AES67_DAEMON_SUBDIR)/aes67-daemon $(TARGET_DIR)/usr/sbin
	$(INSTALL) -D -m 0644 $(@D)/$(AES67_DAEMON_SUBDIR)/daemon.conf $(TARGET_DIR)/etc/aes67-daemon.conf
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/var/lib/ravenna
	$(INSTALL) -D -m 0644 $(@D)/test/status.json $(TARGET_DIR)/var/lib/ravenna
endef

define AES67_DAEMON_INSTALL_INIT_SYSV
	$(INSTALL) -m 0755 -D $(BR2_EXTERNAL)/package/aes67-daemon/S95aes67-daemon \
		$(TARGET_DIR)/etc/init.d/S95aes67-daemon
endef

$(eval $(cmake-package))
