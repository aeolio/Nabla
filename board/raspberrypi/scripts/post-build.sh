#!/bin/sh
# post-build.sh for Raspberry Pi

### bind function library
_path=$BR2_EXTERNAL_NABLA_PATH/scripts
[ -x "$_path/function_lib.sh" ] && . "$_path/function_lib.sh"

BOOT_FILE=${BINARIES_DIR}/rpi-firmware/cmdline.txt

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
	sed -i 's/$/ isolcpus=nohz,domain,managed_irq,3/' ${BOOT_FILE} 
fi
# append nohz_full parameter
if ! grep -q 'nohz_full=' "${BOOT_FILE}"; then
	sed -i 's/$/ nohz_full=3/' ${BOOT_FILE} 
fi

### modify config.txt
CONFIG_FILE=${BINARIES_DIR}/rpi-firmware/config.txt
replace_symbols $CONFIG_FILE

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
