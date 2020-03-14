#!/bin/sh
# post-build script for Generic i386-64

### bind function library
_path="`dirname $0`"
if [ -z "$_path" ]; then
	_path="."
fi
. "$_path/function_lib.sh"

### Linux firmware selected
### check out wireless.wiki.kernel.org for firmware version related to kernel version
if [ $(grep -c "BR2_PACKAGE_LINUX_FIRMWARE=y" $BR2_CONFIG) -gt 0 ]; then
	_SOURCE_DIR=$(ls -dt $BUILD_DIR/linux-firmware-* | awk '{ print $1; exit }')
	_TARGET_DIR="$TARGET_DIR/lib/firmware"
	FW_PKG_LIST=""

	### define firmware packages
	# Realtek firmware
	FW_PKG_LIST="$FW_PKG_LIST rtl_nic rtlwifi"
	# Ralink firmware
	FW_PKG_LIST="$FW_PKG_LIST rt2561.bin rt2561s.bin rt2661.bin rt2860.bin rt2870.bin rt3070.bin rt3071.bin rt3090.bin rt3290.bin rt73.bin"
	# Intel wireless firmware
	FW_PKG_LIST="$FW_PKG_LIST iwlwifi-6000g2a-6.ucode iwlwifi-6000g2b-6.ucode iwlwifi-7265-17.ucode iwlwifi-7265D-29.ucode"
	# Intel graphic driver for Minix Neo
	FW_PKG_LIST="$FW_PKG_LIST i915"
	# Ralink Mediatek MT7601U 802.11bgn USB
	FW_PKG_LIST="$FW_PKG_LIST mt7601u.bin"

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
### root login also changed, is handled by patch in package folder
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

### modify avahi configuration file
_ETC_AVAHI="$TARGET_DIR/etc/avahi"
AVAHI_CONFIG=${_ETC_AVAHI}/avahi-daemon.conf
if [ -f $AVAHI_CONFIG ] && [ $(grep -c "^#host-name=" $AVAHI_CONFIG) -gt 0 ]; then
	echo "patching $AVAHI_CONFIG"
	sed '/^#/ s/#host-name=.*/host-name='"$BR2_TARGET_GENERIC_HOSTNAME"'/' < $AVAHI_CONFIG > ${AVAHI_CONFIG}_ 
	# cleaning up
	if [ $? -eq 0 ]; then
		rm $AVAHI_CONFIG && mv ${AVAHI_CONFIG}_ $AVAHI_CONFIG
	else
		rm ${AVAHI_CONFIG}_ 
	fi
fi

### add mpd:audio user and group
add_group "audio" "29" 
add_user "mpd" "x" "101" "29" "music player demon" "/var/lib/mpd" "/bin/sh" 

### remove additional wpa_supplicant.conf
WPA_SUPPLICANT_CONF="$TARGET_DIR/etc/wpa_supplicant/wpa_supplicant.conf"
WPA_SUPPLICANT_EXTRA="$TARGET_DIR/etc/wpa_supplicant.conf"
if [ -f $WPA_SUPPLICANT_CONF -a -f $WPA_SUPPLICANT_EXTRA ]; then
	rm $WPA_SUPPLICANT_EXTRA || exit 1
fi

### fix annoying ld.so.conf behaviour in buildroot make script
LD_CONF_FILE=$TARGET_DIR/etc/ld.so.conf
LD_CONF_DIR=$TARGET_DIR/etc/ld.so.conf.d
if test -f $LD_CONF_FILE; then rm -f $LD_CONF_FILE; fi
if test -d $LD_CONF_DIR; then rm -fR $LD_CONF_DIR; fi
