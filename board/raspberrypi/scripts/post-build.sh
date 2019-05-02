#!/bin/sh
# post-build.sh for Raspberry Pi

BOOT_FILE=${BINARIES_DIR}/rpi-firmware/cmdline.txt
CONFIG_FILE=${BINARIES_DIR}/rpi-firmware/config.txt

### modify cmdline.txt
# remove root parameter
if grep -q 'root=' "${BOOT_FILE}"; then
	sed 's/root=[a-z/0-9]* //' ${BOOT_FILE}
	sed -i 's/root=[a-z/0-9]* //' ${BOOT_FILE}
fi
# remove rootwait parameter
if grep -q 'rootwait' "${BOOT_FILE}"; then
	sed -i 's/rootwait //' ${BOOT_FILE}
fi

### modify config.txt
# enable initramfs
if grep -q '^#initramfs' "${CONFIG_FILE}"; then
	sed -i 's/#initramfs/initramfs/' ${CONFIG_FILE}
fi
# add optional interfaces
if ! grep -q 'device tree' "${CONFIG_FILE}"; then
	cat  >> "${CONFIG_FILE}" << EOF

#device tree
dtparam=i2c_arm=on
dtparam=i2s=on
dtparam=spi=on
EOF
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
