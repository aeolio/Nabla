#!/bin/sh

set -e

target_dir=/tmp
pkg_name=mpd
pkg_version="0.24.6"
dl_dir=/home/iago/buildroot/dl/$pkg_name
pkg_dir=/home/iago/buildroot/package/$pkg_name
external_dir=/home/iago/br2-external/patches/$pkg_name/$pkg_version

_pwd=$(pwd)
cd $target_dir

mkdir -p buildroot
mkdir -p br2-external

# prepare source directories
archive="$dl_dir/$pkg_name-$pkg_version.tar.xz"
mkdir $pkg_name-$pkg_version-a
xzcat "$archive" | tar --strip-components=1 -C "$pkg_name-$pkg_version-a" -xf -
mkdir $pkg_name-$pkg_version-b
xzcat "$archive" | tar --strip-components=1 -C "$pkg_name-$pkg_version-b" -xf -

# apply buildroot patches
for f in $pkg_dir/*.patch; do
	p=$(basename "$f")
	patch -d "$pkg_name-$pkg_version-b" -p 1 -i "$f"
	[ $? -gt 1 ] && exit 2
	find "$pkg_name-$pkg_version-b" -name '*.orig' -exec rm "{}" \;
	diff -Naur "$pkg_name-$pkg_version-a" "$pkg_name-$pkg_version-b" > buildroot/"$p" || true
	patch -d "$pkg_name-$pkg_version-a" -p 1 -i "$f"
done

# apply package patches
for f in $external_dir/*.patch; do
	p=$(basename "$f")
	patch -d "$pkg_name-$pkg_version-b" -p 1 -i "$f"
	[ $? -gt 1 ] && exit 2
	find "$pkg_name-$pkg_version-b" -name '*.orig' -exec rm "{}" \;
	diff -Naur "$pkg_name-$pkg_version-a" "$pkg_name-$pkg_version-b" > br2-external/"$p" || true
	patch -d "$pkg_name-$pkg_version-a" -p 1 -i "$f"
done

# clean up
rm -fr $pkg_name-$pkg_version-a
rm -fr $pkg_name-$pkg_version-b

cd $_pwd
