#!/bin/sh
# function library to be used in setup scripts

# 2016-06-15 replaced BUILDROOT_TARGET with the predefined TARGET_DIR

### add user
add_user() { 
	# Usage: add_user "username" "password" "userid" "groupid" "description" "home" "shell" 
	mkdir -p ${TARGET_DIR}/etc 
	touch ${TARGET_DIR}/etc/passwd 
	if [ -z "`grep "$1:" ${TARGET_DIR}/etc/passwd`" ]; then 
		echo "$1:$2:$3:$4:$5:$6:$7" >> ${TARGET_DIR}/etc/passwd 
	fi 
} 

### add_user_to_group
add_user_to_group() { 
	# Usage: add_user_to_group "groupname" "username"
	GRP_FILE=${TARGET_DIR}/etc/group
	USR_LIST=$(awk -F ":" '/$1/ {print $4}' $GRP_FILE)
	# user not in user list
	if [ ! "$USR_LIST" = "*\<$2\>*" ]; then 
		# append to existing list
		if [ -n "$USR_LIST" ]; then 
			USR_LIST="$USR_LIST,$2"
		# replace empty list
		else
			USR_LIST="$2"
		fi
	# replace user list
	sed -i.old '/^'"$1"'/ s/:[a-z]*$/'":$USR_LIST"'/' $GRP_FILE && rm $GRP_FILE.old
	fi
}

### add group
add_group() { 
	# Usage: add_group "groupname" "groupid" "username"
	mkdir -p ${TARGET_DIR}/etc 
	touch ${TARGET_DIR}/etc/group 
	if [ -z "`grep "$1:" ${TARGET_DIR}/etc/group`" ]; then 
		echo "$1:x:$2:$3" >> ${TARGET_DIR}/etc/group 
	else
		add_user_to_group $1 $3
	fi 
}

### add mount point
add_mountpoint() { 
	# Usage: add_mountpoint <file system> <mount pt> <type> <options>
	mkdir -p ${TARGET_DIR}/etc 
	touch ${TARGET_DIR}/etc/fstab 
	if [ -z "`grep "$1" ${TARGET_DIR}/etc/fstab`" ]; then 
		echo "$1	$2	$3	$4	0	0" >> ${TARGET_DIR}/etc/fstab 
	fi 
} 


