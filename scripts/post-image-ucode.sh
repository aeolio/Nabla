#!/bin/sh
# post-image script to prepend initrd with ucode image
#	see: kernel.org/doc/html/next/x86/microcode.html
#	within buildroot this cannot be used, since the script woulf have to be 
#	executed between root fs generation and kernel rebuild, where no hook exists

set -e

### bind function library
_path=$BR2_EXTERNAL_NABLA_PATH/scripts
# shellcheck source=/dev/null
[ -x "$_path/function_lib.sh" ] && . "$_path/function_lib.sh"

INITRD=$BINARIES_DIR/rootfs.cpio
SRCDIR=$TARGET_DIR/lib/firmware
DSTDIR=kernel/x86/microcode
TMPDIR=$BUILD_DIR/initrd

rm -fr "$TMPDIR"

mkdir "$TMPDIR"
cd "$TMPDIR"
mkdir -p "$DSTDIR"

if [ -d "$SRCDIR/amd-ucode" ]; then
	cat "$SRCDIR"/amd-ucode/microcode_amd*.bin > "$DSTDIR/AuthenticAMD.bin"
fi

if [ -d "$SRCDIR/intel-ucode" ]; then
	cat "$SRCDIR"/intel-ucode/* > "$DSTDIR/GenuineIntel.bin"
fi

find . | cpio -o -H newc > ../ucode.cpio
cd ..
mv "$INITRD" "$INITRD.orig"
cat ucode.cpio "$INITRD.orig" > "$INITRD"

rm -fr "$TMPDIR"
