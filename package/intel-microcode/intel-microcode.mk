################################################################################
#
# (partially) override intel-microcode logic
#
################################################################################

# Intel J1800 N100
INTEL_MICROCODE_PROCESSOR_IDS = 306d4 b06e0
INTEL_MICROCODE_FIRMWARE_DIR = $(TARGET_DIR)/lib/firmware/intel-ucode

# override the /lib/firmware installation if CPUIDs were specified
ifeq ($(BR2_PACKAGE_INTEL_MICROCODE_INSTALL_TARGET),y)
# fall-back to the buildroot standard (install unconditionally)
ifneq ($(INTEL_MICROCODE_PROCESSOR_IDS),)
define INTEL_MICROCODE_INSTALL_TARGET_CMDS
	mkdir -p $(INTEL_MICROCODE_FIRMWARE_DIR)
	for i in $(INTEL_MICROCODE_PROCESSOR_IDS) ; do \
		f=$$($(BR2_EXTERNAL_NABLA_PATH)/scripts/cpuid2ucode.py $$i) ; \
		$(INSTALL) -m 0644 -t $(INTEL_MICROCODE_FIRMWARE_DIR) \
			$(@D)/intel-ucode/$$f || exit 1 ; \
	done
endef
endif
endif
