#!/bin/sh
# post-image.sh for generic x86-64

### bind function library
_path="`dirname $0`"
if [ -z "$_path" ]; then
	_path="."
fi
. "$_path/function_lib.sh"

### remove directory left over from this build
_dir=[0-9]*TARGET_DIR
if [ ! "$_dir" = "$(echo $_dir)" ]; then
	rmdir $_dir
fi
