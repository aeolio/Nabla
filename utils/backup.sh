#!/bin/sh

archive_dir="_backup/$(date +%Y)"
archive_file="$archive_dir/br2-external_config_$(date +%Y%m%d-%H%M).tar.bz2"

source=" \
	board/ \
	configs/ \
	package/ \
	patches/ \
	scripts/ \
	skeleton/ \
	utils/ \
\
	Config.in \
	Config.in.linux \
	external.* \
	LICENSE \
	local.mk \
	README \
\
	_backup/s87localopt/ \
"

mkdir -p "$archive_dir"
# shellcheck disable=SC2086 # need separate parameters for tar
tar cjf "$archive_file" $source
echo "Created $(basename "$archive_file") in $archive_dir"
