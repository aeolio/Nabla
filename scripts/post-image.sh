#!/bin/sh
# common post-image script

set -e

### bind function library
_path=$BR2_EXTERNAL_NABLA_PATH/scripts
# shellcheck source=/dev/null
[ -x "$_path/function_lib.sh" ] && . "$_path/function_lib.sh"

###
### backup project image files
###

BACKUP_DIR=$BR2_EXTERNAL_NABLA_PATH/_backup/images
PROJECT_NAME=$(get_project_name)
GENERATIONS=7
_SOURCE_DIR=$BINARIES_DIR
_TARGET_DIR=$BACKUP_DIR/$PROJECT_NAME/$(date +%Y%m%d%H%M%S)
_EXCLUDE_PATTERN="--exclude=*.vfat --exclude=*.cpio --exclude=*.img"

project_backup_list() {
	find "$BACKUP_DIR/$PROJECT_NAME" -type d -regex ".*/[0-9]+" | sort "$1"
}

delete_backup_directories() {
	n="$1"
	for d in $(project_backup_list "$2"); do
		n=$((n+1))
		if [ "$n" -gt "$GENERATIONS" ]; then
			rm -fr "$d"
		fi
	done
}

# LIFO environment variable controls if the oldest or newest entry
# is deleted first if the number of generations is exceeded. Default
# is to delete the oldest entry.

if [ -n "$LIFO" ] && [ "$LIFO" -eq 1 ]; then
	delete_backup_directories 1 -g
fi

mkdir -p "$_TARGET_DIR"
rsync -qrlt "$_EXCLUDE_PATTERN" --delete "$_SOURCE_DIR/" "$_TARGET_DIR/"

if [ -z "$LIFO" ] || [ "$LIFO" -eq 0 ]; then
	delete_backup_directories 0 -r
fi
