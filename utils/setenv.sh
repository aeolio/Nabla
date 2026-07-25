#!/bin/sh

_filename(){
	echo ${1##*/}
}
alias filename='_filename'

_pwd=$(pwd)
_pkg=$(filename "$_pwd")
[ "$_pwd" = "$HOME" ] && return 1
while [ $(dirname "$_pwd") != "$HOME" ]; do
	_pwd=$(dirname "$_pwd")
done

_prj=$(filename "$_pwd")
_dir="$HOME"/"$_prj"

export PATH="$_dir/host/bin:$_dir/host/sbin:$PATH"

case $_pkg in

  # rhis is for host packages
  host-*)
	printf "Host package\n"

	export PKG_CONFIG="$_dir/host/bin/pkg-config"
	export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
	export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
	export PKG_CONFIG_LIBDIR="$_dir/host/lib/pkgconfig:$_dir/host/share/pkgconfig"
	export PKG_CONFIG_PATH="$_dir/host/lib/pkgconfig:$_dir/host/share/pkgconfig"
	export PKG_CONFIG_SYSROOT_DIR="/"

	export AR="/usr/bin/ar"
	export AS="/usr/bin/as"
	export LD="/usr/bin/ld"
	export NM="/usr/bin/nm"
	export CC="/usr/bin/gcc"
	export GCC="/usr/bin/gcc"
	export CXX="/usr/bin/g++"
	export CPP="/usr/bin/cpp"
	export OBJCOPY="/usr/bin/objcopy"
	export RANLIB="/usr/bin/ranlib"
	export CPPFLAGS="-I$_dir/host/include"
	export CFLAGS="-O2 -I$_dir/host/include"
	export CXXFLAGS="-O2 -I$_dir/host/include"
	export LDFLAGS="-L$_dir/host/lib -Wl,-rpath,$_dir/host/lib"
	export INTLTOOL_PERL=/usr/bin/perl
	export CONFIG_SITE=/dev/null
	;;

  # this is for target packages
  *)
	printf "Iarget package\n"
	export ARCH=x86_64
	export CROSS_COMPILE="$_dir/host/bin/x86_64-linux-"
	export CROSS_PREFIX="$_dir/host/bin/x86_64-linux-gcc"

	export CC="${CROSS_COMPILE}gcc"
	export CFLAGS="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64  -O2 -g0"
	export CONFIG_PREFIX="$_dir/target"
	export NM="$CROSS_PREFIX-nm"
	export PKG_CONFIG="$_dir/host/bin/pkg-config"
	export PKG_CONFIG_PATH="$_dir/staging/usr/lib/pkgconfig"
	export PREFIX="$_dir/target"
	export RANLIB="$CROSS_PREFIX-ranlib"
	;;
esac
