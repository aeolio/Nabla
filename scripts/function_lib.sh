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
