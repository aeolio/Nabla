#!/bin/sh

set -eu # treat warnings as errors

BOARD_DIR="$(dirname $0)"
CONFIG_NAME=hw_intfc.conf
DTB_NAME="$(basename $(awk -F '=' '/BR2_LINUX_KERNEL_INTREE_DTS_NAME/ {print $2}' ${BR2_CONFIG} | tr -d \").dtb)"
LINUX_PATH="linux-$(awk -F '=' '/BR2_LINUX_KERNEL_VERSION/ {print $2}' ${BR2_CONFIG} | tr -d \")"
OVERLAY_PATH=arch/arm64/boot/dts/rockchip/overlays-rockpi4

#
# copy extlinux to BINARIES_DIR and replace devicetree line
#
mkdir -p ${BINARIES_DIR}/extlinux
sed -e "s|devicetree .*|devicetree /boot/${DTB_NAME}|" ${BOARD_DIR}/extlinux.conf > ${BINARIES_DIR}/extlinux/extlinux.conf

#
	# copy device tree overlays
#
if [ -d ${BUILD_DIR}/${LINUX_PATH}/${OVERLAY_PATH} ]; then
	mkdir -p ${BINARIES_DIR}/overlays
	cp ${BUILD_DIR}/${LINUX_PATH}/${OVERLAY_PATH}/*.dtbo ${BINARIES_DIR}/overlays/
	cp ${BUILD_DIR}/${LINUX_PATH}/${OVERLAY_PATH}/hw_intfc.conf ${BINARIES_DIR}/overlays/
fi

#
# Previous step has placed the hardware configuration file in ${BINARIES_DIR}/overlays,
# now transfer this file to ${BINARIES_DIR} and enable the ttyS2 overlay
#
if [ -f ${BINARIES_DIR}/overlays/${CONFIG_NAME} ]; then
	sed -e 's|#.*=console-on-ttyS2|intfc:dtoverlay=console-on-ttyS2/|' \
		${BINARIES_DIR}/overlays/${CONFIG_NAME} > ${BINARIES_DIR}/${CONFIG_NAME}
fi
