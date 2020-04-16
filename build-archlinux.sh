#!/bin/bash

# run following command to init pacman keyring:
# pacman-key --init
# pacman-key --populate archlinuxarm

[ "$EUID" != "0" ] && echo "please run as root" && exit 1

os="archlinux"
rootsize=1400
origin="latest"
target="catdrive-$(date +%Y-%m-%d)"

tmpdir="tmp"
output="output"
rootfs_mount_point="/mnt/${os}_rootfs"
qemu_static="./tools/qemu/qemu-aarch64-static"

cur_dir=$(pwd)
DTB=armada-3720-catdrive.dtb

chroot_prepare() {
	rm -rf $rootfs_mount_point/etc/resolv.conf
	if [ -z "$TRAVIS" ]; then
		echo 'Server = https://mirrors.163.com/archlinuxarm/$arch/$repo' > $rootfs_mount_point/etc/pacman.d/mirrorlist
		echo "nameserver 119.29.29.29" > $rootfs_mount_point/etc/resolv.conf
	else
		echo "nameserver 8.8.8.8" > $rootfs_mount_point/etc/resolv.conf
	fi
}

ext_init_param() {
	:
}

chroot_post() {
	ln -sf /run/systemd/resolve/resolv.conf $rootfs_mount_point/etc/resolv.conf
	if [ -n "$TRAVIS" ]; then
		echo 'Server = https://mirrors.163.com/archlinuxarm/$arch/$repo' > $rootfs_mount_point/etc/pacman.d/mirrorlist
	fi
}

add_services() {
	echo "add resize mmc script"
	cp ./tools/systemd/resizemmc.service $rootfs_mount_point/lib/systemd/system/
	cp ./tools/systemd/resizemmc.sh $rootfs_mount_point/sbin/
	mkdir -p $rootfs_mount_point/etc/systemd/system/basic.target.wants
	ln -sf /lib/systemd/system/resizemmc.service $rootfs_mount_point/etc/systemd/system/basic.target.wants/resizemmc.service
	touch $rootfs_mount_point/root/.need_resize
}

gen_new_name() {
	local rootfs=$1
	echo "`basename $rootfs | sed "s/${origin}/${target}/" | sed 's/.tar.gz$//'`"
}

source ./common.sh
