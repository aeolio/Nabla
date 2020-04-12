#!/bin/sh
# post-build.sh for Raspberry Pi

BOOT_FILE=${BINARIES_DIR}/rpi-firmware/cmdline.txt
CONFIG_FILE=${BINARIES_DIR}/rpi-firmware/config.txt

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

### modify config.txt
# enable initramfs
if grep -q '^#initramfs' "${CONFIG_FILE}"; then
	sed -i 's/#initramfs/initramfs/' ${CONFIG_FILE}
fi
# add optional interfaces
if ! grep -q 'device tree' "${CONFIG_FILE}"; then
	cat  >> "${CONFIG_FILE}" << EOF

# device tree
dtparam=i2c_arm=on
dtparam=i2s=on
dtparam=spi=on
EOF
fi

### create missing nvram file for Raspberry Pi 4
_TARGET_DIR="${TARGET_DIR}/lib/firmware"
src_file=brcm/brcmfmac43455-sdio.txt
dst_file=brcm/brcmfmac43455-sdio.raspberrypi,4-model-b.txt
if [ -f ${_TARGET_DIR}/${src_file} ] && ! [ -h ${_TARGET_DIR}/${dst_file} ]; then
	ln -rs ${_TARGET_DIR}/${src_file} ${_TARGET_DIR}/${dst_file}
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
