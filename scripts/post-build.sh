#!/bin/sh
# common post-build script

### bind function library
_path="`dirname $0`"
if [ -z "$_path" ]; then
	_path="."
fi
. "$_path/function_lib.sh"

KERNEL_VERSION=$(grep BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE ${BR2_CONFIG})
KERNEL_VERSION=${KERNEL_VERSION##*=}
KERNEL_VERSION=$(echo ${KERNEL_VERSION} | sed 's/^"\(.*\)"$/\1/')
KERNEL_SOURCE=${BUILD_DIR}/linux-${KERNEL_VERSION}
KERNEL_CONFIG=${KERNEL_SOURCE}/.config

### Linux firmware is selected
### check out wireless.wiki.kernel.org for firmware version related to kernel version
if [ $(grep -c "BR2_PACKAGE_LINUX_FIRMWARE=y" $BR2_CONFIG) -gt 0 ]; then
	_SOURCE_DIR=$(ls -dt $BUILD_DIR/linux-firmware-* | awk '{ print $1; exit }')
	_TARGET_DIR="$TARGET_DIR/lib/firmware"
	FW_PKG_LIST=""

	### define firmware packages based on kernel configuration
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
			# entry is not present, use information from WHENCE
			else
				copy_firmware ${fw_pkg} ${_SOURCE_DIR} ${_TARGET_DIR} || exit 5
			fi
		done
	fi
fi

### patch sshd configuration files in /etc/ssh
### openssh 7.x changed default behaviour, but leave in place for documentation
### root login behaviour also changed, this is handled by patch in package folder
_ETC_SSH="$TARGET_DIR/etc/ssh"
SSHD_CONFIG=${_ETC_SSH}/sshd_config
if [ $(grep -c "^#HostKey /etc/ssh_host*_key$" $SSHD_CONFIG) -gt 0 ]; then
	echo "patching $SSHD_CONFIG"
	sed '/^#/ s/#HostKey \/etc\/ssh_host/HostKey \/etc\/ssh\/ssh_host/' < $SSHD_CONFIG > ${SSHD_CONFIG}_ 
	# cleaning up
	if [ $? -eq 0 ]; then
		rm $SSHD_CONFIG && mv ${SSHD_CONFIG}_ $SSHD_CONFIG
	else
		rm ${SSHD_CONFIG}_ 
	fi
fi

TARGET_HOSTNAME=$(grep BR2_TARGET_GENERIC_HOSTNAME ${BR2_CONFIG})
TARGET_HOSTNAME=${TARGET_HOSTNAME##*=}
TARGET_HOSTNAME=$(echo ${TARGET_HOSTNAME} | sed 's/^"\(.*\)"$/\1/')

### Avahi package selected
### modify avahi configuration file
if [ $(grep -c "BR2_PACKAGE_AVAHI=y" $BR2_CONFIG) -gt 0 ]; then
	_ETC_AVAHI="${TARGET_DIR}/etc/avahi"
	AVAHI_CONFIG=${_ETC_AVAHI}/avahi-daemon.conf
	if [ -f $AVAHI_CONFIG ] && [ $(grep -c "#host-name=" $AVAHI_CONFIG) -gt 0 ]; then
		echo "patching $AVAHI_CONFIG"
		sed -e 's/#host-name=.*/host-name='"$TARGET_HOSTNAME"'/' -i $AVAHI_CONFIG
	fi
fi

### nfs-utils selected
### modify init.d startup file
if [ $(grep -c "BR2_PACKAGE_NFS_UTILS=y" $BR2_CONFIG) -gt 0 ]; then
	_ETC_INIT_D="${TARGET_DIR}/etc/init.d"
	NFS_STARTUP=${_ETC_INIT_D}/S60nfs
	if [ -f $NFS_STARTUP ] && [ $(grep -c "daemon:daemon" $NFS_STARTUP) -lt 1 ]; then
		sed -e '/^mkdir.*sm.bak/a chown daemon:daemon \/run\/nfs\/sm*' -i $NFS_STARTUP
	fi
fi

### libfuse3 selected
### modify init.d startup file
if [ $(grep -c "BR2_PACKAGE_LIBFUSE3=y" $BR2_CONFIG) -gt 0 ]; then
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
if [ $(grep -c "BR2_PACKAGE_LINUXPTP=y" $BR2_CONFIG) -gt 0 ]; then
	_ETC="${TARGET_DIR}/etc"
	LINUXPTP_CONFIG=${_ETC}/linuxptp.cfg
	if [ -f $LINUXPTP_CONFIG ] && [ $(grep -c "^time_stamping.*hardware" $LINUXPTP_CONFIG) -gt 0 ]; then
		echo "patch $LINUXPTP_CONFIG"
		sed -e '/^time_stamping/ s/hardware/software/' \
			-e '/^slaveOnly/ s/1/0/' -i $LINUXPTP_CONFIG
	fi
	if [ -f $LINUXPTP_CONFIG ] && [ $(grep -c "^[lo]$" $LINUXPTP_CONFIG) -eq 0 ]; then
		echo "add loopback interface to $LINUXPTP_CONFIG"
		echo "" >> $LINUXPTP_CONFIG
		echo "[lo]" >> $LINUXPTP_CONFIG
	fi
fi

### remove unnecessary items from target filesystem
# empty directories
remove_directories="lib/udev/rules.d usr/lib/ntfs-3g"
for d in $remove_directories; do
	[ -d ${TARGET_DIR}/$d ] && rmdir -p ${TARGET_DIR}/$d
done
# unused directories or single programs
remove_files=""
# installed by gpg-error
remove_files="$remove_files usr/share/common-lisp"
# helper files for valgrind, installed by libglib2
remove_files="$remove_files usr/share/glib-2.0"
# installed by mpd
remove_files="$remove_files usr/share/icons usr/share/vala"
# installed by libgcrypt
remove_files="$remove_files usr/bin/dumpsexp usr/bin/hmac256 usr/bin/mpicalc"
for f in $remove_files; do
	rm -fr ${TARGET_DIR}/$f
done

### work around annoying ld.so.conf behaviour in buildroot make script
LD_CONF_FILE=$TARGET_DIR/etc/ld.so.conf
LD_CONF_DIR=$TARGET_DIR/etc/ld.so.conf.d
if test -f $LD_CONF_FILE; then rm -f $LD_CONF_FILE; fi
if test -d $LD_CONF_DIR; then rm -fR $LD_CONF_DIR; fi
