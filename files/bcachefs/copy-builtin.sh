#!/bin/sh
set -ef

usage()
{
	echo "usage: $0 <kernel source tree>" >&2
	exit 1
}

if ! [ -d "$1" ] ; then
	usage
fi
KERNEL_DIR="$(realpath "$1")"

cp -r fs/bcachefs "$KERNEL_DIR"/fs/bcachefs

sed -i '/source "fs\/ext2\/Kconfig\"/i\source "fs/bcachefs/Kconfig"' "$KERNEL_DIR/fs/Kconfig"
echo 'obj-$(CONFIG_BCACHEFS_FS) += bcachefs/' >> "$KERNEL_DIR/fs/Makefile"
