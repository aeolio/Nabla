################################################################################
#
# additional openssh logic
#
################################################################################

OPENSSH_INIT_SCRIPT = $(TARGET_DIR)/etc/init.d/S50sshd

# modify init.d configuration
define OPENSSH_MODIFY_INIT_SCRIPT
	if [ -f "$(OPENSSH_INIT_SCRIPT)" ]; then \
		patch $(OPENSSH_INIT_SCRIPT) \
			$(BR2_EXTERNAL)/package/openssh/0000-modify-startup-script.patch; \
	fi
endef
OPENSSH_POST_INSTALL_TARGET_HOOKS += OPENSSH_MODIFY_INIT_SCRIPT
