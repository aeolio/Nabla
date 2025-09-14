#!/bin/sh
# common post-build script

### bind function library
_path=$BR2_EXTERNAL_NABLA_PATH/scripts
[ -x "$_path/function_lib.sh" ] && . "$_path/function_lib.sh"

KERNEL_CONFIG=$(get_kernel_config)

### Linux firmware is selected
### check out wireless.wiki.kernel.org for firmware version related to kernel version
if [ $(is_config_selected "BR2_PACKAGE_LINUX_FIRMWARE") -gt 0 ]; then
	_SOURCE_DIR=$(ls -dt $BUILD_DIR/linux-firmware-* | awk '{ print $1; exit }')
	_TARGET_DIR="$TARGET_DIR/lib/firmware"
	FW_PKG_LIST=""

	### define firmware packages based on kernel configuration
	# AMD microcode -- only one file as function test
	if [ $(grep -c "CONFIG_MICROCODE_AMD=y" $KERNEL_CONFIG) -gt 0 ]; then
		FW_PKG_LIST="$FW_PKG_LIST amd-ucode/microcode_amd.bin"
	fi
	# Broadcom ethernet firmware (tigon3)
	if [ $(grep -c "CONFIG_NET_VENDOR_BROADCOM=[my]" $KERNEL_CONFIG) -gt 0 ]; then
		FW_PKG_LIST="$FW_PKG_LIST tigon"
	fi
	# Realtek ethernet firmware
	if [ $(grep -c "CONFIG_NET_VENDOR_REALTEK=[my]" $KERNEL_CONFIG) -gt 0 ]; then
		FW_PKG_LIST="$FW_PKG_LIST rtl_nic"
	fi
	# Realtek wireless firmware
	if [ $(grep -c "CONFIG_WLAN_VENDOR_REALTEK=[my]" $KERNEL_CONFIG) -gt 0 ] || \
		[ $(grep -c "CONFIG_RTL_CARDS=[my]" $KERNEL_CONFIG) -gt 0 ]; then
		FW_PKG_LIST="$FW_PKG_LIST rtlwifi"
	fi
	# Ralink wireless firmware
	if [ $(grep -c "CONFIG_WLAN_VENDOR_RALINK=[my]" $KERNEL_CONFIG) -gt 0 ] || \
		[ $(grep -c "CONFIG_RT_2X00=[my]" $KERNEL_CONFIG) -gt 0 ]; then
		FW_PKG_LIST="$FW_PKG_LIST rt2561.bin rt2561s.bin rt2661.bin rt2860.bin rt2870.bin rt3070.bin rt3071.bin rt3090.bin rt3290.bin rt73.bin"
	fi
	# Intel wireless firmware 
	if [ $(grep -c "CONFIG_WLAN_VENDOR_INTEL=[my]" $KERNEL_CONFIG) -gt 0 ] || \
		[ $(grep -c "CONFIG_IWLWIFI=[my]" $KERNEL_CONFIG) -gt 0 ]; then
		FW_PKG_LIST="$FW_PKG_LIST iwlwifi-6000g2a-6.ucode iwlwifi-6000g2b-6.ucode iwlwifi-7265-17.ucode iwlwifi-7265D-29.ucode"
	fi
	# Intel graphic driver for UEFI boot (CONFIG_DRM -> CONFIG_DRM_I915)
	if [ $(grep -c "CONFIG_DRM_I915=[my]" $KERNEL_CONFIG) -gt 0 ]; then
		FW_PKG_LIST="$FW_PKG_LIST i915"
	fi
	# Ralink Mediatek MT7601U 802.11bgn USB (CONFIG_WLAN_VENDOR_MEDIATEK -> CONFIG_MT7601U)
	if [ $(grep -c "CONFIG_MT7601U=[my]" $KERNEL_CONFIG) -gt 0 ]; then
		FW_PKG_LIST="$FW_PKG_LIST mt7601u.bin"
	fi

	### copy firmware packages
	if [ -n "$FW_PKG_LIST" ]; then
		mkdir -p ${_TARGET_DIR} || exit 1
		for fw_pkg in $FW_PKG_LIST; do
			# entry corresponds to a file
			if [ -f ${_SOURCE_DIR}/$fw_pkg ]; then
				cp -f ${_SOURCE_DIR}/$fw_pkg ${_TARGET_DIR} || exit 2
			# entry corresponds to a directory
			elif [ -d ${_SOURCE_DIR}/$fw_pkg ]; then
				mkdir -p ${_TARGET_DIR}/$fw_pkg || exit 3
				cp -rf ${_SOURCE_DIR}/$fw_pkg/* ${_TARGET_DIR}/$fw_pkg || exit 4
			# locate the file using WHENCE from the firmware package
			else
				install_firmware ${fw_pkg} ${_SOURCE_DIR} ${_TARGET_DIR} || exit 5
			fi
		done
	fi
fi

### patch sshd configuration files in /etc/ssh
### openssh 7.x changed default behaviour, but leave in place for documentation
### root login behaviour also changed, this is handled by patch in package folder
if [ $(is_config_selected "BR2_PACKAGE_OPENSSH_SERVER") -gt 0 ]; then
	_ETC_SSH="$TARGET_DIR/etc/ssh"
	SSHD_CONFIG=${_ETC_SSH}/sshd_config
	if [ $(grep -c "^#HostKey /etc/ssh_host*_key$" $SSHD_CONFIG) -gt 0 ]; then
		echo "patching $SSHD_CONFIG"
		sed -e '/^#/ s/#HostKey \/etc\/ssh_host/HostKey \/etc\/ssh\/ssh_host/' -i $SSHD_CONFIG
	fi
fi

TARGET_HOSTNAME=$(get_buildroot_config_value "BR2_TARGET_GENERIC_HOSTNAME")

### Avahi package selected
### modify avahi configuration file
if [ $(is_config_selected "BR2_PACKAGE_AVAHI") -gt 0 ]; then
	_ETC_AVAHI="${TARGET_DIR}/etc/avahi"
	AVAHI_CONFIG=${_ETC_AVAHI}/avahi-daemon.conf
	if [ -f $AVAHI_CONFIG ] && [ $(grep -c "#host-name=" $AVAHI_CONFIG) -gt 0 ]; then
		echo "patching $AVAHI_CONFIG"
		sed -e 's/#host-name=.*/host-name='"$TARGET_HOSTNAME"'/' -i $AVAHI_CONFIG
	fi
fi

### nfs-utils in server mode 
### modify init.d startup file
if [ $(is_config_selected "BR2_PACKAGE_NFS_UTILS_RPC_NFSD") -gt 0 ]; then
	_ETC_INIT_D="${TARGET_DIR}/etc/init.d"
	NFS_STARTUP=${_ETC_INIT_D}/S60nfs
	if [ -f $NFS_STARTUP ] && [ $(grep -c "daemon:daemon" $NFS_STARTUP) -lt 1 ]; then
		sed -e '/^mkdir.*sm.bak/a chown daemon:daemon \/run\/nfs\/sm*' -i $NFS_STARTUP
	fi
fi

### libfuse3 selected
### modify init.d startup file
if [ $(is_config_selected "BR2_PACKAGE_LIBFUSE3") -gt 0 ]; then
	_ETC_INIT_D="${TARGET_DIR}/etc/init.d"
	FUSE3_PROVIDED=${_ETC_INIT_D}/fuse3
	FUSE3_STARTUP=${_ETC_INIT_D}/S22fuse3
	if [ -f ${FUSE3_PROVIDED} ]; then
		sed -i '/^# Define LSB log_\* functions.$/,+2d' $FUSE3_PROVIDED
		mv ${FUSE3_PROVIDED} ${FUSE3_STARTUP}
	fi
fi

### linuxptp selected
### modify configuration
if [ $(is_config_selected "BR2_PACKAGE_LINUXPTP") -gt 0 ]; then
	_ETC="${TARGET_DIR}/etc"
	LINUXPTP_CONFIG=${_ETC}/linuxptp.cfg
	if [ -f $LINUXPTP_CONFIG ] && [ $(grep -c "^time_stamping.*hardware" $LINUXPTP_CONFIG) -gt 0 ]; then
		echo "patch $LINUXPTP_CONFIG"
		sed -e '/^time_stamping/ s/hardware/software/' \
			-e '/^slaveOnly/ s/1/0/' -i $LINUXPTP_CONFIG
	fi
	if [ -f $LINUXPTP_CONFIG ] && [ $(grep -c "^\[lo\]$" $LINUXPTP_CONFIG) -eq 0 ]; then
		echo "add loopback interface to $LINUXPTP_CONFIG"
		echo "" >> $LINUXPTP_CONFIG
		echo "[lo]" >> $LINUXPTP_CONFIG
	fi
fi

### move /etc/init.d/S01seedrng to S20seedrng to enable persistence of seed file
_ETC_INITD="${TARGET_DIR}/etc/init.d"
[ -f $_ETC_INITD/S01seedrng ] && mv $_ETC_INITD/S01seedrng $_ETC_INITD/S20seedrng

### modify os-release
RELEASE_FILE="$TARGET_DIR/usr/lib/os-release"
replace_symbols $RELEASE_FILE

### remove unnecessary items from target filesystem
# empty directories
remove_directories="lib/udev/rules.d usr/lib/udev/rules.d usr/lib/ntfs-3g"
for d in $remove_directories; do
	[ -d ${TARGET_DIR}/$d ] && rmdir -p ${TARGET_DIR}/$d
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
	rm -fr ${TARGET_DIR}/$f
done
