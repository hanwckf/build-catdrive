#!/bin/bash
# note: rootfs is mount point

[ "$EUID" != "0" ] && echo "please run as root" && exit 1

set -e
set -o pipefail

os="debian"
os_ver="buster"
rootsize=1000

tmpdir="tmp"
output="output"
rootfs_mount_point="/mnt/${os}_rootfs"
qemu_static="./tools/qemu/qemu-aarch64-static"

cur_dir=$(pwd)
DTB=armada-3720-catdrive.dtb

chroot_prepare() {
	if [ -z "$TRAVIS" ]; then
		echo "deb https://mirrors.huaweicloud.com/debian/ ${os_ver} main contrib non-free" > $rootfs_mount_point/etc/apt/sources.list
		echo "nameserver 119.29.29.29" > $rootfs_mount_point/etc/resolv.conf
	else
		echo "deb http://httpredir.debian.org/debian/ ${os_ver} main contrib non-free" > $rootfs_mount_point/etc/apt/sources.list
		echo "nameserver 8.8.8.8" > $rootfs_mount_point/etc/resolv.conf
	fi
}

ext_init_param() {
	:
}

chroot_post() {
	rm -f $rootfs_mount_point/etc/resolv.conf
	cat <<-EOF > $rootfs_mount_point/etc/apt/sources.list
deb https://mirrors.huaweicloud.com/debian/ ${os_ver} main contrib non-free
deb https://mirrors.huaweicloud.com/debian/ ${os_ver}-updates main contrib non-free
deb https://mirrors.huaweicloud.com/debian-security ${os_ver}/updates main contrib non-free
deb https://mirrors.huaweicloud.com/debian/ ${os_ver}-backports main contrib non-free

	EOF
}

generate_rootfs() {
	local rootfs=$1
	mirrorurl="https://mirrors.huaweicloud.com/debian"
	if [ -n "$TRAVIS" ]; then
		mirrorurl="http://httpredir.debian.org/debian"
	fi
	echo "generate debian rootfs to $rootfs by debootstrap..."
	debootstrap --components=main,contrib,non-free --no-check-certificate --no-check-gpg \
		--include=apt-utils --arch=arm64 --variant=minbase --foreign --verbose $os_ver $rootfs $mirrorurl
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
	echo "$os-$os_ver-catdrive-`date +%Y-%m-%d`"
}

source ./common.sh
