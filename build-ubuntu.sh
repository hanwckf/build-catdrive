#!/bin/bash

[ "$EUID" != "0" ] && echo "please run as root" && exit 1

set -e
set -o pipefail

os="ubuntu"
rootsize=850
origin="base-arm64"
target="catdrive"

tmpdir="tmp"
output="output"
rootfs_mount_point="/mnt/${os}_rootfs"
qemu_static="./tools/qemu/qemu-aarch64-static"

cur_dir=$(pwd)
DTB=armada-3720-catdrive.dtb

chroot_prepare() {
	if [ -z "$TRAVIS" ]; then
		sed -i 's#http://ports.ubuntu.com#http://mirrors.huaweicloud.com#' $rootfs_mount_point/etc/apt/sources.list
		echo "nameserver 119.29.29.29" > $rootfs_mount_point/etc/resolv.conf
	else
		echo "nameserver 8.8.8.8" > $rootfs_mount_point/etc/resolv.conf
	fi
}

ext_init_param() {
	echo "BUILD_MINIMAL=y"
}

chroot_post() {
	if [ -z "$TRAVIS" ]; then
		sed -i 's#http://#https://#' $rootfs_mount_point/etc/apt/sources.list
	else
		sed -i 's#http://ports.ubuntu.com#https://mirrors.huaweicloud.com#' $rootfs_mount_point/etc/apt/sources.list
	fi
}

add_services() {
	mkdir -p $rootfs_mount_point/etc/systemd/system/basic.target.wants

	echo "add resize mmc script"
	cp ./tools/systemd/resizemmc.service $rootfs_mount_point/lib/systemd/system/
	cp ./tools/systemd/resizemmc.sh $rootfs_mount_point/sbin/
	ln -sf /lib/systemd/system/resizemmc.service $rootfs_mount_point/etc/systemd/system/basic.target.wants/resizemmc.service
	touch $rootfs_mount_point/root/.need_resize

	echo "add sshd keygen service"
	cp ./tools/systemd/sshdgenkeys.service $rootfs_mount_point/lib/systemd/system/
	ln -sf /lib/systemd/system/sshdgenkeys.service $rootfs_mount_point/etc/systemd/system/basic.target.wants/sshdgenkeys.service
}

gen_new_name() {
	local rootfs=$1
	echo "`basename $rootfs | sed "s/${origin}/${target}/" | sed 's/.tar.gz$//'`"
}

source ./common.sh
