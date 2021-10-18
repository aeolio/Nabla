#!/bin/sh
# post-build.sh for Raspberry Pi

BOOT_FILE=${BINARIES_DIR}/rpi-firmware/cmdline.txt
CONFIG_FILE=${BINARIES_DIR}/rpi-firmware/config.txt
TEMPLATE_TEXT="{.*}"

### modify cmdline.txt
# remove root parameter
if grep -q 'root=' "${BOOT_FILE}"; then
	sed -i 's/root=[a-z/0-9]* //' ${BOOT_FILE}
fi
# remove rootwait parameter
if grep -q 'rootwait' "${BOOT_FILE}"; then
	sed -i 's/rootwait //' ${BOOT_FILE}
fi
# append isolcpus parameter
if ! grep -q 'isolcpus=' "${BOOT_FILE}"; then
	sed -i 's/$/ isolcpus=3/' ${BOOT_FILE} 
fi
# append rcu_nocbs parameter
if ! grep -q 'rcu_nocbs=' "${BOOT_FILE}"; then
	sed -i 's/$/ rcu_nocbs=3/' ${BOOT_FILE} 
fi
# append nohz_full parameter
if ! grep -q 'nohz_full=' "${BOOT_FILE}"; then
	sed -i 's/$/ nohz_full=3/' ${BOOT_FILE} 
fi

### modify config.txt
# check if the config file contains template strings
if $(grep -q "${TEMPLATE_TEXT}" ${CONFIG_FILE}); then
	firmware_variant=$(grep BR2_PACKAGE_RPI_FIRMWARE_VARIANT_.*=y ${BR2_CONFIG})
	firmware_variant=${firmware_variant%%=*}
	firmware_variant=${firmware_variant##BR2_PACKAGE_RPI_FIRMWARE_VARIANT_}
	project_name="$(basename ${BASE_DIR})"
	build_date=$(date +"%Y-%m-%d")
	# replace placeholder strings
	sed -i 's/{project_name}/'${project_name}'/' ${CONFIG_FILE}
	sed -i 's/{build_date}/'${build_date}'/' ${CONFIG_FILE}
	sed -i 's/{buildroot_firmware}/'${firmware_variant}'/' ${CONFIG_FILE}
fi

### copy basic configuration files
config_dir=${BINARIES_DIR}/.config/etc
config_src=~/nabla/config/etc
mkdir -p ${config_dir}
if [ ! -f ${config_dir}/nabla.conf ]; then
	cp ${config_src}/nabla.conf ${config_dir}
fi
if [ ! -f ${config_dir}/mpd.conf ]; then
	cp ${config_src}/mpd.conf ${config_dir}
fi
