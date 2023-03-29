#!/bin/sh
# function library to be used in setup scripts

# 2016-06-15 replaced BUILDROOT_TARGET with the predefined TARGET_DIR
# 2020-04-05 remove user/group functions and replace with standard buildroot functionality

### add mount point
add_mountpoint() { 
	# Usage: add_mountpoint <file system> <mount pt> <type> <options>
	mkdir -p ${TARGET_DIR}/etc 
	touch ${TARGET_DIR}/etc/fstab 
	if [ -z "`grep "$1" ${TARGET_DIR}/etc/fstab`" ]; then 
		echo "$1	$2	$3	$4	0	0" >> ${TARGET_DIR}/etc/fstab 
	fi 
} 

### dereference firmware file names using WHENCE file from firmware directory
### Usage:  copy_firmware <relative path> <source directory> <target directory>
# $1 = filename relative to firmware directory 
# $2 = source firmware directory 
# $3 = target firmware directory 
copy_firmware() {
	# installation target 
	fw_dest=`awk -v f=$1 '/Link:/ { if ($2 == f) {print $4} }' $2/WHENCE`
	# if installation target is link, copy target file first, then create link 
	if [ -n "$fw_dest" ]; then
		cp -f $2/${fw_dest} $3/${fw_dest} || exit 1
		ln -frs $3/${fw_dest} $3/$1 || exit 1
	# otherwise plain file copy
	else
		cp -f $2/$1 $3/$1 || exit 1
	fi
}

### check setting of buildroot config boolean value
### Usage:  is_config_selected <key>
# $1 = config variable
is_config_selected() {
	CONFIG_SETTING="$1=y"
	result=$(grep -c $CONFIG_SETTING $BR2_CONFIG)
	echo $result
}

### get configuration value from buildroot config
### Usage:  get_config_value <key>
# $1 = config variable
get_config_value() {
	CONFIG_SETTING="$1=\".*\""
	CONFIG_VALUE=$(grep $CONFIG_SETTING $BR2_CONFIG)
	CONFIG_VALUE=${CONFIG_VALUE##*=}
	CONFIG_VALUE=$(echo ${CONFIG_VALUE} | sed 's/^"\(.*\)"$/\1/')
	echo $CONFIG_VALUE
}

### replace template strings in target file
### Usage:  replace_symbols <filename>
# $1 = path to filename
replace_symbols() {
	TARGET_FILE=$1
	TEMPLATE_TEXT="{.*}"
	if $(grep -q "${TEMPLATE_TEXT}" ${TARGET_FILE}); then
		arch=$(get_config_value "BR2_ARCH")
		build_date=$(date +"%Y-%m-%d")
		firmware_variant=$(grep BR2_PACKAGE_RPI_FIRMWARE_VARIANT_.*=y ${BR2_CONFIG})
		firmware_variant=${firmware_variant%%=*}
		firmware_variant=${firmware_variant##BR2_PACKAGE_RPI_FIRMWARE_VARIANT_}
		kernel_version=$(get_config_value "BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE")
		project_name="$(basename ${BASE_DIR})"
		software_version="$(git -C $BR2_EXTERNAL_NABLA_PATH log -n 1 --format=%ai)"
		# replace symbol strings
		sed -i 's/{arch}/'${arch}'/' ${TARGET_FILE}
		sed -i 's/{build_date}/'${build_date}'/' ${TARGET_FILE}
		sed -i 's/{buildroot_version}/'$BR2_VERSION'/' ${TARGET_FILE}
		sed -i 's/{firmware_variant}/'${firmware_variant}'/' ${TARGET_FILE}
		sed -i 's/{kernel_version}/'$KERNEL_VERSION'/' ${TARGET_FILE}
		sed -i 's/{project_name}/'${project_name}'/' ${TARGET_FILE}
		sed -i 's/{software_version}/'"${software_version}"'/' ${TARGET_FILE}
	fi
}
