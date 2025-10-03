#!/bin/sh
# common post-build script

set -e

### bind function library
_path=$BR2_EXTERNAL_NABLA_PATH/scripts
# shellcheck source=/dev/null
[ -x "$_path/function_lib.sh" ] && . "$_path/function_lib.sh"

KERNEL_CONFIG=$(get_kernel_config)
TARGET_HOSTNAME=$(get_buildroot_config_value "BR2_TARGET_GENERIC_HOSTNAME")

### Linux firmware is selected
### check out wireless.wiki.kernel.org for firmware version related to kernel version
if [ "$(is_config_selected "BR2_PACKAGE_LINUX_FIRMWARE")" -gt 0 ]; then
	# shellcheck disable=SC2012 # find is too slow!
	_source_dir=$(ls -dt "$BUILD_DIR"/linux-firmware-* | awk '{ print $1; exit }')
	_target_dir="$TARGET_DIR/lib/firmware"
	fw_pkg_list=""

	### define firmware packages based on kernel configuration
	# AMD microcode -- only one file as function test
	if [ "$(grep -c "CONFIG_MICROCODE_AMD=y" "$KERNEL_CONFIG")" -gt 0 ]; then
		fw_pkg_list="$fw_pkg_list amd-ucode/microcode_amd.bin"
	fi
	# Broadcom ethernet firmware (tigon3)
	if [ "$(grep -c "CONFIG_NET_VENDOR_BROADCOM=[my]" "$KERNEL_CONFIG")" -gt 0 ]; then
		fw_pkg_list="$fw_pkg_list tigon"
	fi
	# Realtek ethernet firmware
	if [ "$(grep -c "CONFIG_NET_VENDOR_REALTEK=[my]" "$KERNEL_CONFIG")" -gt 0 ]; then
		fw_pkg_list="$fw_pkg_list rtl_nic"
	fi
	# Realtek wireless firmware
	if [ "$(grep -c "CONFIG_WLAN_VENDOR_REALTEK=[my]" "$KERNEL_CONFIG")" -gt 0 ] || \
		[ "$(grep -c "CONFIG_RTL_CARDS=[my]" "$KERNEL_CONFIG")" -gt 0 ]; then
		fw_pkg_list="$fw_pkg_list rtlwifi"
	fi
	# Ralink wireless firmware
	if [ "$(grep -c "CONFIG_WLAN_VENDOR_RALINK=[my]" "$KERNEL_CONFIG")" -gt 0 ] || \
		[ "$(grep -c "CONFIG_RT_2X00=[my]" "$KERNEL_CONFIG")" -gt 0 ]; then
		fw_pkg_list="$fw_pkg_list rt2561.bin rt2561s.bin rt2661.bin rt2860.bin rt2870.bin rt3070.bin rt3071.bin rt3090.bin rt3290.bin rt73.bin"
	fi
	# Intel wireless firmware
	if [ "$(grep -c "CONFIG_WLAN_VENDOR_INTEL=[my]" "$KERNEL_CONFIG")" -gt 0 ] || \
		[ "$(grep -c "CONFIG_IWLWIFI=[my]" "$KERNEL_CONFIG")" -gt 0 ]; then
		fw_pkg_list="$fw_pkg_list iwlwifi-6000g2a-6.ucode iwlwifi-6000g2b-6.ucode iwlwifi-7265-17.ucode iwlwifi-7265D-29.ucode"
	fi
	# Intel graphic driver for UEFI boot (CONFIG_DRM -> CONFIG_DRM_I915)
	if [ "$(grep -c "CONFIG_DRM_I915=[my]" "$KERNEL_CONFIG")" -gt 0 ]; then
		fw_pkg_list="$fw_pkg_list i915"
	fi
	# Ralink Mediatek MT7601U 802.11bgn USB (CONFIG_WLAN_VENDOR_MEDIATEK -> CONFIG_MT7601U)
	if [ "$(grep -c "CONFIG_MT7601U=[my]" "$KERNEL_CONFIG")" -gt 0 ]; then
		fw_pkg_list="$fw_pkg_list mt7601u.bin"
	fi

	### copy firmware packages
	if [ -n "$fw_pkg_list" ]; then
		mkdir -p "$_target_dir" || exit 1
		for fw_pkg in $fw_pkg_list; do
			# entry corresponds to a file
			if [ -f "$_source_dir/$fw_pkg" ]; then
				cp -f "$_source_dir/$fw_pkg" "$_target_dir" || exit 2
			# entry corresponds to a directory
			elif [ -d "$_source_dir/$fw_pkg" ]; then
				mkdir -p "$_target_dir/$fw_pkg" || exit 3
				cp -f "$_source_dir/$fw_pkg"/* "$_target_dir/$fw_pkg" || exit 4
			# locate the file using WHENCE from the firmware package
			else
				install_firmware "$fw_pkg" "$_source_dir" "$_target_dir" || exit 5
			fi
		done
	fi
fi

### patch sshd configuration files in /etc/ssh
### openssh 7.x changed default behaviour, but leave in place for documentation
### root login behaviour also changed, this is handled by patch in package folder
if [ "$(is_config_selected "BR2_PACKAGE_OPENSSH_SERVER")" -gt 0 ]; then
	_etc_ssh="$TARGET_DIR/etc/ssh"
	sshd_config="$_etc_ssh/sshd_config"
	if [ "$(grep -c "^#HostKey /etc/ssh_host*_key$" "$sshd_config")" -gt 0 ]; then
		echo "patching $sshd_config"
		sed -e '/^#/ s/#HostKey \/etc\/ssh_host/HostKey \/etc\/ssh\/ssh_host/' -i "$sshd_config"
	fi
fi

### Avahi package selected
### modify avahi configuration file
if [ "$(is_config_selected "BR2_PACKAGE_AVAHI")" -gt 0 ]; then
	_etc_avahi="$TARGET_DIR/etc/avahi"
	avahi_config="$_etc_avahi/avahi-daemon.conf"
	if [ -f "$avahi_config" ] && [ "$(grep -c "#host-name=" "$avahi_config")" -gt 0 ]; then
		echo "patching $avahi_config"
		sed -e 's/#host-name=.*/host-name='"$TARGET_HOSTNAME"'/' -i "$avahi_config"
	fi
fi

### nfs-utils in server mode
### modify init.d startup file
if [ "$(is_config_selected "BR2_PACKAGE_NFS_UTILS_RPC_NFSD")" -gt 0 ]; then
	_etc_init_d="${TARGET_DIR}/etc/init.d"
	nfs_startup="$_etc_init_d/S60nfs"
	if [ -f "$nfs_startup" ] && [ "$(grep -c "daemon:daemon" "$nfs_startup")" -lt 1 ]; then
		sed -e '/^mkdir.*sm.bak/a chown daemon:daemon \/run\/nfs\/sm*' -i "$nfs_startup"
	fi
fi

### libfuse3 selected
### modify init.d startup file
if [ "$(is_config_selected "BR2_PACKAGE_LIBFUSE3")" -gt 0 ]; then
	_etc_init_d="${TARGET_DIR}/etc/init.d"
	fuse3_default="$_etc_init_d/fuse3"
	fuse3_startup="$_etc_init_d/S22fuse3"
	if [ -f "$fuse3_default" ]; then
		sed -i '/^# Define LSB log_\* functions.$/,+2d' "$fuse3_default"
		mv "$fuse3_default" "$fuse3_startup"
	fi
fi

### linuxptp selected
### modify configuration
if [ "$(is_config_selected "BR2_PACKAGE_LINUXPTP")" -gt 0 ]; then
	_etc="${TARGET_DIR}/etc"
	linuxptp_config="$_etc/linuxptp.cfg"
	if	[ -f "$linuxptp_config" ] && \
		[ "$(grep -c "^time_stamping.*hardware" "$linuxptp_config")" -gt 0 ]; then
		echo "patch $linuxptp_config"
		sed -e '/^time_stamping/ s/hardware/software/' \
			-e '/^slaveOnly/ s/1/0/' -i "$linuxptp_config"
	fi
	if	[ -f "$linuxptp_config" ] && \
		[ "$(grep -c "^\[lo\]$" "$linuxptp_config")" -eq 0 ]; then
		echo "add loopback interface to $linuxptp_config"
		echo "" >> "$linuxptp_config"
		echo "[lo]" >> "$linuxptp_config"
	fi
fi

### move /etc/init.d/S01seedrng to S20seedrng to enable persistence of seed file
_etc_init_d="${TARGET_DIR}/etc/init.d"
[ -f "$_etc_init_d/S01seedrng" ] && mv "$_etc_init_d/S01seedrng" "$_etc_init_d/S20seedrng"

### modify os-release
(
	# execute in a subshell with exit-on-error reset, 
	# otherwise grep will abort the script
	set +e
	release_file="$TARGET_DIR/usr/lib/os-release"
	replace_symbols "$release_file"
)

### remove unnecessary items from target filesystem
# empty directories
remove_directories="lib/udev/rules.d usr/lib/udev/rules.d usr/lib/ntfs-3g"
for d in $remove_directories; do
	[ -d "${TARGET_DIR:?}/$d" ] && rmdir -p "${TARGET_DIR:?}/$d"
done
# unused directories or single files
remove_files=""
# installed by gpg-error
remove_files="$remove_files usr/share/common-lisp"
# helper files for valgrind, installed by libglib2
remove_files="$remove_files usr/share/glib-2.0"
# installed by ffmpeg
remove_files="$remove_files usr/share/ffmpeg"
# installed by mpd
remove_files="$remove_files usr/share/icons usr/share/vala"
# installed by libgcrypt
remove_files="$remove_files usr/bin/dumpsexp usr/bin/hmac256 usr/bin/mpicalc"
# generated by ldconfig
remove_files="$remove_files etc/ld.so.conf etc/ld.so.conf.d"
# copied by initscripts and not needed with mdev
remove_files="$remove_files etc/init.d/S11modules"
for f in $remove_files; do
	rm -fr "${TARGET_DIR:?}/$f"
done
