#!/bin/sh

# function library to be used in setup scripts

# 2016-06-15 replaced BUILDROOT_TARGET with the predefined TARGET_DIR
# 2020-04-05 remove user/group functions and replace with standard buildroot functionality
# 2025-08-07 make get_config_value() compatible with make files
# 2025-10-02 fix shellcheck warnings

### add mount point
add_mountpoint() { 
	# Usage: add_mountpoint <file system> <mount pt> <type> <options>
	_etc="$TARGET_DIR/etc" 
	_etc_fstab="$_etc/fstab" 
	mkdir -p "$_etc" 
	touch "$_etc_fstab" 
	# $1 can appear multiple times, so add $2 to the search pattern
	if ! grep -qE "$1[[:blank:]]+$2" "$_etc_fstab"; then
		printf "%s\t\t%s\t\t%s\t%s\t0\t0\n" "$1" "$2" "$3" "$4" >> "$_etc_fstab" 
	fi 
} 

### dereference firmware file names using WHENCE file from firmware directory
### Usage:  install_firmware <relative path> <source directory> <target directory>
# $1 = filename relative to firmware directory 
# $2 = source firmware directory 
# $3 = target firmware directory 
install_firmware() {
	fw_file=$1
	fw_source=$2
	fw_target=$3
	# installation target 
	fw_file=$(awk -v f="$fw_file" '/File:/ { if ($2 ~ f) {print $2} }' "$fw_source/WHENCE")
	fw_link=$(awk -v f="$fw_file" '/Link:/ { if ($4 == f) {print $2} }' "$fw_source/WHENCE")
	# copy target file (create directory if necessary)
	if [ -n "$fw_file" ]; then
		fw_dir=$(dirname "$fw_file")
		( [ -n "$fw_dir" ] && mkdir -p "$fw_target/$fw_dir" ) || exit 1
		cp -f "$fw_source/$fw_file" "$fw_target/$fw_file" || exit 1
	fi
	# create target link, if specified
	if [ -n "$fw_link" ]; then
		ln -frs "$fw_target/$fw_file" "$fw_target/$fw_link" || exit 1
	fi
}

### check setting of buildroot config boolean value
### Usage:  is_config_selected <key>
# $1 = config variable
is_config_selected() {
	config_setting="$1=y"
	result=$(grep -c "$config_setting" "$BR2_CONFIG") || true
	echo "$result"
}

### get configuration value from file
### Usage:  get_config_value <file> <key>
# $1 = file name
# $2 = variable name
get_config_value() {
	config_pattern="$2[[:blank:]]?=[[:blank:]]?\"?.*?\"?"
	config_value=$(grep -E "$config_pattern" "$1")
	config_value=${config_value##*=}	# everything after equal sign
	config_value=$(echo "$config_value" | xargs)	# strip
	echo "$config_value"
}

### get configuration value from buildroot config
### Usage:  get_buildroot_config_value <key>
# $1 = config variable
get_buildroot_config_value() {
	get_config_value "$BR2_CONFIG" "$1"
}

### The current Linux kernel version
### Usage:  get_kernel_version
get_kernel_version() {
	get_buildroot_config_value "NABLA_LINUX_VERSION"
}

### The Linux kernel configuration file
### Usage:  get_kernel_configfile
get_kernel_config() {
	kernel_version=$(get_kernel_version)
	kernel_source=$BUILD_DIR/linux-$kernel_version
	kernel_config=$kernel_source/.config
	echo "$kernel_config"
}

### extract project (build) name from Buildroot directory
### Usage:  get_project_name
get_project_name() {
	basename "$BASE_DIR"
}

### replace template strings in target file
### Usage:  replace_symbols <filename>
# $1 = path to filename
replace_symbols() {
	target_file=$1
	template_text="{.*}"
	if grep -q "$template_text" "$target_file"; then
		arch=$(get_buildroot_config_value "BR2_ARCH")
		build_date=$(date +"%Y-%m-%d")
		# wildcards cannot be handled by get_config_value()
		firmware_variant=$(grep "BR2_PACKAGE_RPI_FIRMWARE_VARIANT_.*=y" "$BR2_CONFIG")
		firmware_variant=${firmware_variant%%=*}
		firmware_variant=${firmware_variant##BR2_PACKAGE_RPI_FIRMWARE_VARIANT_}
		kernel_version=$(get_kernel_version)
		project_name=$(get_project_name)
		software_version=$(git -C "$BR2_EXTERNAL_NABLA_PATH" log -n 1 --format=%as-%h)
		version_id=$(printf '%d.%d' \
			"$(git -C ~/buildroot rev-list --count master)" \
			"$(git -C ~/br2-external rev-list --count master)")
		# replace symbol strings
		sed -i 's/{arch}/'"$arch"'/' "$target_file"
		sed -i 's/{build_date}/'"$build_date"'/' "$target_file"
		sed -i 's/{buildroot_version}/'"$BR2_VERSION"'/' "$target_file"
		sed -i 's/{firmware_variant}/'"$firmware_variant"'/' "$target_file"
		sed -i 's/{kernel_version}/'"$kernel_version"'/' "$target_file"
		sed -i 's/{project_name}/'"$project_name"'/' "$target_file"
		sed -i 's/{software_version}/'"$software_version"'/' "$target_file"
		sed -i 's/{version_id}/'"$version_id"'/' "$target_file"
	fi
}
