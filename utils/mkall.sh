#!/bin/sh

highlight="\33[38;5;0;48;5;214m"
blackonwhite="\33[30;47m"
reset="\33[m"

_do_clean=0
_do_deploy=0
_do_make=0
_do_purge=0
_do_saveconfig=0

linux_config=~/br2-external/Config.in.linux

# remove duplicate packages from build directory
# precondition: current directory == project directory
purge_build_directory() {
	for d in build/*; do
		if [ -d $d ]; then
			# strip package name
			package_name=$(basename $d)
			package_name=${package_name%-[0-9]*}
			builds=$(echo build/${package_name}-[0-9]*)
			if [ "$builds" != "build/${package_name}-[0-9]*" ]; then
				current_version="19700101000000"
				i=0
				# identify most recent version
				for b in $builds; do
					# may have been removed already
					if [ ! -d $b ]; then continue; fi
					ts=$(ls -ld --time-style="+%Y%m%d%H%M%S" $b | awk '{print $6}')
					if [ $ts -gt $current_version ]; then
						current_version=$ts
					fi
					i=$(expr $i + 1)
				done
				if [ $i -gt 1 ]; then
					for b in $builds; do
						if [ ! -d $b ]; then continue; fi
						ts=$(ls -ld --time-style="+%Y%m%d%H%M%S" $b | awk '{print $6}')
						if [ $ts -ne $current_version ]; then
							rm -fr $b && echo "$b removed"
						fi
					done
				fi
			fi
		fi
	done
}

# copy image file(s) to target system
# precondition: current directory == project directory
deploy_image_files() {
	local rsync_options="--checksum --stats --times --verbose"
	local transferred_files="Number of regular files transferred"
	local mrw="mount -o remount,rw /media/boot"
	local mro="mount -o remount,ro /media/boot"
	local cfgfile=system.conf
	if [ -e $cfgfile ]; then
		. ./$cfgfile
		local logfile=/tmp/$HOSTNAME.log
		if ssh -o ConnectTimeout=2 -q root@$HOSTNAME true; then
			printf "${blackonwhite}>>>   Image deployment to %s${reset}\n" $HOSTNAME
			ssh root@$HOSTNAME $mrw
			rsync $rsync_options $IMAGEFILES root@$HOSTNAME:$TARGETDIR 2>&1 > $logfile || exit 1
			changes=$(awk 'BEGIN{FS=":"} /'"$transferred_files"'/ {gsub(/ /, "", $2); print $2}' $logfile)
			if [ $changes -gt 0 ]; then
				awk '{if ($0=="") exit; print $0}' $logfile
				ssh root@$HOSTNAME "sync && reboot"
			else
				ssh root@$HOSTNAME $mro
			fi
			rm -f $logfile
		fi
	fi
	}

print_usage() {
	echo "  use: $0 [option] { --exec=<command> | --exclude=<project> | --include=<project> }"
	echo "  option ::= { --[build|clean|deploy|purge|saveconfig] }"
}

if [ -z "$1" ]; then
	print_usage && exit 1;
fi

# TODO: projets with their own buildroot instance will update .config every time
# use buildroot revision to determine if config file needs update
revision=$(git -C ~/buildroot describe)
# return to the current directory afterwards
current_dir=$(pwd)
# excluded projects
exclusion_list=""
# included projects
targets=""

for arg in "$@"
do
	case $arg in

		--clean)
		_do_clean=1
		;;

		--exec=*)
		command=${arg#*=}
		;;

		--build)
		_do_make=1
		;;

		--purge)
		_do_purge=1
		;;

		--deploy)
		_do_deploy=1
		;;

		--save*)
		_do_saveconfig=1
		;;

		--include=*)
		targets="$targets $(ls ~/${arg#*=}/.config)"
		exclusion_list=
		;;

		--exclude=*)
		exclusion_list="$exclusion_list ${arg#*=}"
		;;

		*)
		print_usage
		exit 1;
		;;

	esac
done

[ -n "$targets" ] || targets=$(ls ~/*/.config)
for t in $targets; do
	p=$(dirname $t)	# project directory
	pn=${p#$HOME\/}	# project name
	# ignore clean build directories
	if ! [ -d $p/build ]; then continue; fi
	# ignore specified projects
	if (echo ${exclusion_list} | grep -q "$pn"); then continue; fi
	printf "\t${highlight}### %s ###${reset}\n" $pn
	cd $p
	# exclusively execute make target if specified
	if [ -n "$command" ]; then
		make $command
		continue;
	fi
	# update .config if revision changed or modification /status change is newer
	if	[ $(grep -c $revision .config) -ne 1 ] ||
		[ $(stat -c%Y .config) -lt $(stat -c%Y $linux_config) ] ||
		[ $(stat -c%Z .config) -lt $(stat -c%Z $linux_config) ]; then
		make olddefconfig || exit $?
	fi
	# update buildroot and kernel configurations
	if [ ${_do_saveconfig} -eq 1 ]; then
		make savedefconfig
		# make linux-update-defconfig
		continue;
	fi
	# clear out target build folder
	if [ ${_do_clean} -eq 1 ]; then
		make clean
	fi
	# rebuild target
	if [ ${_do_make} -eq 1 ]; then
		make || exit $?
		# rm +([0-9]) ## works with /bin/bash only
	fi
	# purge outdated package versions from build directory
	if [ ${_do_purge} -eq 1 ]; then
		purge_build_directory || exit $?
	fi
	# deploy image files
	if [ ${_do_deploy} -eq 1 ]; then
		deploy_image_files || exit $?
	fi
done
cd ${current_dir}
