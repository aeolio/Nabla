# BR2_EXTERNAL_NABLA_PATH is enclosed in double quotes
path = $(strip $(subst ",,$(BR2_EXTERNAL_NABLA_PATH)))
#"))
include $(sort $(wildcard $(path)/package/*/*.mk))
