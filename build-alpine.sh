#!/bin/bash

[ "$EUID" != "0" ] && echo "please run as root" && exit 1

set -e
set -o pipefail

os="alpine"
rootsize=700
origin="minirootfs"
target="catdrive"

tmpdir="tmp"
output="output"
rootfs_mount_point="/mnt/${os}_rootfs"
qemu_static="./tools/qemu/qemu-aarch64-static"

cur_dir=$(pwd)
DTB=armada-3720-catdrive.dtb

chroot_prepare() {
	if [ -z "$TRAVIS" ]; then
		sed -i 's#http://dl-cdn.alpinelinux.org#https://mirrors.tuna.tsinghua.edu.cn#' $rootfs_mount_point/etc/apk/repositories
		echo "nameserver 119.29.29.29" > $rootfs_mount_point/etc/resolv.conf
	else
		echo "nameserver 8.8.8.8" > $rootfs_mount_point/etc/resolv.conf
	fi
}

ext_init_param() {
	if [ "$BUILD_RESCUE" = "y" ]; then
		echo "BUILD_RESCUE=y"
	fi
}

chroot_post() {
	if [ -n "$TRAVIS" ]; then
		sed -i 's#http://dl-cdn.alpinelinux.org#https://mirrors.tuna.tsinghua.edu.cn#' $rootfs_mount_point/etc/apk/repositories
	fi
}

add_resizemmc() {
	if [ "$BUILD_RESCUE" != "y" ]; then
		echo "add resize mmc script"
		cp ./tools/${os}/resizemmc.sh $rootfs_mount_point/sbin/resizemmc.sh
		cp ./tools/${os}/resizemmc $rootfs_mount_point/etc/init.d/resizemmc
		ln -sf /etc/init.d/resizemmc $rootfs_mount_point/etc/runlevels/default/resizemmc
		touch $rootfs_mount_point/root/.need_resize
	fi
}

gen_new_name() {
	local rootfs=$1
	echo "`basename $rootfs | sed "s/${origin}/${target}/" | sed 's/.tar.gz$//'`"
}

source ./common.sh
