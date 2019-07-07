#!/bin/bash

set -u # unbound variables

BOARD_DIR="$(dirname $0)"
BOARD_NAME="$(basename ${BOARD_DIR})"
DTB_NAME="$(basename $(awk -F '=' '/BR2_LINUX_KERNEL_INTREE_DTS_NAME/ {print $2}' ${BR2_CONFIG} | tr -d \").dtb)"
BUILD_ROOTFS=$(grep -c BR2_TARGET_ROOTFS_EXT2=y ${BR2_CONFIG})

###
### partition sizes. copied from
### https://github.com/rockchip-linux/build/blob/debian/partitions.sh
###

LOADER1_SIZE=8000
RESERVED1_SIZE=128
RESERVED2_SIZE=8192
LOADER2_SIZE=8192
ATF_SIZE=8192
BOOT_SIZE=1048576 # <- check if this may be decreased

SYSTEM_START=0
LOADER1_START=64
RESERVED1_START=$(expr ${LOADER1_START} + ${LOADER1_SIZE})
RESERVED2_START=$(expr ${RESERVED1_START} + ${RESERVED1_SIZE})
LOADER2_START=$(expr ${RESERVED2_START} + ${RESERVED2_SIZE})
ATF_START=$(expr ${LOADER2_START} + ${LOADER2_SIZE})
BOOT_START=$(expr ${ATF_START} + ${ATF_SIZE})
ROOTFS_START=$(expr ${BOOT_START} + ${BOOT_SIZE})

#image names
BOOT_IMAGE_NAME=boot.img
CONFIG_IMAGE_NAME=nabla.img
ROOT_FS_NAME=rootfs.ext4
SYSTEM_IMAGE_NAME=sdcard.img

###
### build boot file system
###

generate_boot_image() {
	BOOT_IMAGE=${BINARIES_DIR}/$1
	rm -rf ${BOOT_IMAGE}

	echo -e "\e[36m Generate boot image : ${BOOT_IMAGE} start \e[0m"

	# size 100 MB
	mkfs.vfat -n "boot" -S 512 -C ${BOOT_IMAGE} $((100 * 1024))

	mmd -i ${BOOT_IMAGE} ::/boot
	mcopy -i ${BOOT_IMAGE} -s ${BINARIES_DIR}/extlinux ::
	mcopy -i ${BOOT_IMAGE} -s ${BINARIES_DIR}/Image ::/boot/Image
	mcopy -i ${BOOT_IMAGE} -s ${BINARIES_DIR}/${DTB_NAME} ::/boot/${DTB_NAME}
	mcopy -i ${BOOT_IMAGE} -s ${BINARIES_DIR}/overlays ::
	mcopy -i ${BOOT_IMAGE} -s ${BINARIES_DIR}/hw_intfc.conf ::

	echo -e "\e[36m Generate boot image : ${BOOT_IMAGE} finished \e[0m"
}

###
### build config file system
###

generate_config_image() {
	NABLA_IMAGE=${BINARIES_DIR}/$1
	rm -rf ${NABLA_IMAGE}

	echo -e "\e[36m Generate NABLA image : ${NABLA_IMAGE} start \e[0m"

	# size 100 MB
	mkfs.vfat -n "NABLA" -S 512 -C ${NABLA_IMAGE} $((100 * 1024))

	mmd -i ${NABLA_IMAGE} ::/.config

	echo -e "\e[36m Generate boot image : ${NABLA_IMAGE} finished \e[0m"
}

###
### build root file system
###

generate_system_image() {
	ROOTFS_IMAGE=${BINARIES_DIR}/$2
	SYSTEM_IMAGE=${BINARIES_DIR}/$1
	rm -rf ${SYSTEM_IMAGE}

	echo -e "\e[36m Generate system image : ${SYSTEM_IMAGE} start \e[0m"

	# last dd rootfs will extend gpt image to fit the size,
	# but this will overrite the backup table of GPT
	# will cause corruption error for GPT
	IMG_ROOTFS_SIZE=$(stat -L --format="%s" ${ROOTFS_IMAGE})
	GPTIMG_MIN_SIZE=$(expr $IMG_ROOTFS_SIZE + \( ${LOADER1_SIZE} + ${RESERVED1_SIZE} + ${RESERVED2_SIZE} + ${LOADER2_SIZE} + ${ATF_SIZE} + ${BOOT_SIZE} + 35 \) \* 512)
	GPT_IMAGE_SIZE=$(expr $GPTIMG_MIN_SIZE \/ 1024 \/ 1024 + 2)

	dd if=/dev/zero of=${SYSTEM_IMAGE} bs=1M count=0 seek=$GPT_IMAGE_SIZE

	parted -s ${SYSTEM_IMAGE} mklabel gpt
	parted -s ${SYSTEM_IMAGE} unit s mkpart loader1 ${LOADER1_START} $(expr ${RESERVED1_START} - 1)
	# parted -s ${SYSTEM_IMAGE} unit s mkpart reserved1 ${RESERVED1_START} $(expr ${RESERVED2_START} - 1)
	# parted -s ${SYSTEM_IMAGE} unit s mkpart reserved2 ${RESERVED2_START} $(expr ${LOADER2_START} - 1)
	parted -s ${SYSTEM_IMAGE} unit s mkpart loader2 ${LOADER2_START} $(expr ${ATF_START} - 1)
	parted -s ${SYSTEM_IMAGE} unit s mkpart trust ${ATF_START} $(expr ${BOOT_START} - 1)
	parted -s ${SYSTEM_IMAGE} unit s mkpart boot ${BOOT_START} $(expr ${ROOTFS_START} - 1)
	parted -s ${SYSTEM_IMAGE} set 4 boot on
	parted -s ${SYSTEM_IMAGE} -- unit s mkpart rootfs ${ROOTFS_START} -34s

	# for magic values see
	# https://www.freedesktop.org/software/systemd/man/systemd-gpt-auto-generator.html
	if [ "$__ARCH" = "64" ]; then
		ROOT_UUID="B921B045-1DF0-41C3-AF44-4C6F280D3FAE"
	else
		ROOT_UUID="69DAD710-2CE4-4E3C-B16C-21A1D49ABED3"
	fi

	gdisk ${SYSTEM_IMAGE} <<EOF
x
c
5
${ROOT_UUID}
w
y
EOF

	# burn u-boot
	dd if=${BINARIES_DIR}/u-boot/idbloader.img of=${SYSTEM_IMAGE} seek=${LOADER1_START} conv=notrunc
	dd if=${BINARIES_DIR}/u-boot/uboot.img of=${SYSTEM_IMAGE} seek=${LOADER2_START} conv=notrunc
	dd if=${BINARIES_DIR}/u-boot/trust.img of=${SYSTEM_IMAGE} seek=${ATF_START} conv=notrunc

	# burn boot image
	dd if=${BINARIES_DIR}/${BOOT_IMAGE_NAME} of=${SYSTEM_IMAGE} conv=notrunc seek=${BOOT_START}

	# burn rootfs image
	if [ -f ${ROOTFS_IMAGE} ]; then
		dd if=${ROOTFS_IMAGE} of=${SYSTEM_IMAGE} conv=notrunc,fsync seek=${ROOTFS_START}
	fi

	echo -e "\e[36m Generate system image : ${SYSTEM_IMAGE} finished \e[0m"
}

# default architecture is 64 bit
__ARCH=64
for arg in "$@"
do
	case "${arg}" in
		--aarch64)
		__ARCH=64
		;;
		--arm)
		__ARCH=32
		;;
	esac
done

# which payload to use in generating system image
if [ $BUILD_ROOTFS eq 1 ]; then
	payload=${ROOT_FS_NAME}
else
	payload=${CONFIG_IMAGE_NAME}
fi

generate_boot_image ${BOOT_IMAGE_NAME} || exit $?;
generate_config_image ${CONFIG_IMAGE_NAME} || exit $?;
generate_system_image ${SYSTEM_IMAGE_NAME} ${payload} || exit $?;

exit 0
