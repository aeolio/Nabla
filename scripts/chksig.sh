#!/bin/sh

'''
	This script handles mpd exclusively
'''

buildroot_dir=~/buildroot
external_dir=~/br2-external
package_dir=$buildroot_dir/package/mpd
download_dir=$buildroot_dir/dl/mpd
makefile=$package_dir/mpd.mk

# shellcheck source=/dev/null
. $external_dir/scripts/function_lib.sh

mpd_major=$(get_config_value $makefile MPD_VERSION_MAJOR)
mpd_minor=$(get_config_value $makefile MPD_VERSION)
mpd_minor=${mpd_minor##*.}
mpd_version=$mpd_major.$mpd_minor

archive_file=mpd-$mpd_version.tar.xz
signature_file=$archive_file.sig

# this does unfortunately not work
# key_id=0x236e8a58c6db4512
# key_server="https://sks.pgpkeys.eu"
# if ! gpg --with-colons --list-keys $key_id; then
# 	gpg --keyserver $key_server --recv-keys $key_id
# fi

cd $download_dir || exit 1

key_id=0x236e8a58c6db4512
# key_file="max kellermann pgp_mit_edu.asc"
key_file="max kellermann de_pgpkeys_eu.asc"
key_server="https://sks.pgpkeys.eu"
if ! gpg --with-colons --list-keys $key_id; then
	if [ ! -f "$key_file" ]; then
		wget --output-document="$key_file" "$key_server/pks/lookup?op=get&search=$key_id"
	fi
	gpg --import "$key_file"
fi

if [ ! -f "$signature_file" ]; then
	wget "https://musicpd.org/download/mpd/$mpd_major/$signature_file"
fi
gpg --verify "$signature_file" "$archive_file"
sha256sum "$archive_file"
