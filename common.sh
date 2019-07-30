#!/bin/bash

DISK="rootfs.img"

func_generate() {
	local rootfs=$1
	local kdir=$2

	[ "$os" != "debian" ] && [ ! -f "$rootfs" ] && echo "${os} rootfs file not found!" && return 1
	[ ! -d "$kdir" ] && echo "kernel dir not found!" && return 1

	# create rootfs mbr img
	mkdir -p ${tmpdir}
	echo "create mbr rootfs, size: ${rootsize}M"
	dd if=/dev/zero bs=1M status=none conv=fsync count=$rootsize of=$tmpdir/$DISK
	parted -s $tmpdir/$DISK -- mktable msdos
	parted -s $tmpdir/$DISK -- mkpart p ext4 8192s -1s

	# get PTUUID
	eval `blkid -o export -s PTUUID $tmpdir/$DISK`

	# mkfs.ext4
	echo "mount loopdev to format ext4 rootfs"
	modprobe loop
	lodev=$(losetup -f)
	losetup -P $lodev $tmpdir/$DISK
	mkfs.ext4 -q -m 2 ${lodev}"p1"

	# mount rootfs
	echo "mount rootfs"
	mkdir -p $rootfs_mount_point
	mount  ${lodev}"p1" $rootfs_mount_point

	# extract rootfs
	if [ "$os" = "debian" ]; then
		generate_rootfs $rootfs_mount_point
	else
		echo "extract ${os} rootfs($rootfs) to $rootfs_mount_point"
		if [ "$os" = "archlinux" ]; then
			tarbin="bsdtar"
		else
			tarbin="tar"
		fi
		$tarbin -xpf $rootfs -C $rootfs_mount_point
	fi

	# configure binfmt
	echo "configure binfmt to chroot"
	modprobe binfmt_misc
	if [ -e /proc/sys/fs/binfmt_misc/register ]; then
		echo -1 > /proc/sys/fs/binfmt_misc/status
		echo ":arm64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:OC" > /proc/sys/fs/binfmt_misc/register
		echo "copy $qemu_static to $rootfs_mount_point/usr/bin/"
		cp $qemu_static $rootfs_mount_point/usr/bin/qemu-aarch64-static
	else
		echo "Could not configure binfmt for qemu!" && exit 1
	fi

	cp ./tools/${os}/init.sh $rootfs_mount_point/init.sh

	# prepare for chroot
	chroot_prepare

	# chroot
	echo "chroot to ${os} rootfs"
	eval $(ext_init_param) LANG=C LC_ALL=C chroot $rootfs_mount_point /init.sh

	# clean rootfs
	rm -f $rootfs_mount_point/init.sh
	[ -n "$qemu" ] && rm -f $rootfs_mount_point/$qemu || rm -f $rootfs_mount_point/usr/bin/qemu-aarch64-static

	# add resize script
	add_resizemmc

	# add /boot
	echo "add /boot"
	mkdir -p $rootfs_mount_point/boot
	cp -f $kdir/Image $rootfs_mount_point/boot
	cp -f $kdir/$DTB $rootfs_mount_point/boot
	cp -f ./tools/boot/uEnv.txt $rootfs_mount_point/boot
	if [ "$BUILD_RESCUE" != "y" ]; then
		echo "rootdev=PARTUUID=${PTUUID}-01" >> $rootfs_mount_point/boot/uEnv.txt
	fi
	cp -f ./tools/boot/boot.cmd $rootfs_mount_point/boot
	mkimage -C none -A arm -T script -d $rootfs_mount_point/boot/boot.cmd $rootfs_mount_point/boot/boot.scr

	# add /lib/modules
	echo "add /lib/modules"
	tar --no-same-owner -xf $kdir/modules.tar.xz --strip-components 1 -C $rootfs_mount_point/lib

	# chroot post
	chroot_post

	umount -l $rootfs_mount_point
	losetup -d $lodev

	echo "generate ${os} rootfs done"

}

func_release() {
	local rootfs=$1
	local kdir=$2
	local rootfs_rescue=$3

	# generate tmp/rootfs.img
	func_generate $rootfs $kdir

	img_name=$(gen_new_name $rootfs)

	if [ "$BUILD_RESCUE" = "y" ]; then
		offset=$(sfdisk -J $tmpdir/$DISK |jq .partitiontable.partitions[0].start)
		mkdir -p $rootfs_mount_point
		mount -o loop,offset=$((offset*512)) $tmpdir/$DISK $rootfs_mount_point
		tar -cJpf ./tools/rescue/rescue-${img_name}.tar.xz -C $rootfs_mount_point .
		umount -l $rootfs_mount_point
	else
		[ ! -f $rootfs_rescue ] && echo "rescue rootfs not found!" && return 1

		# calc size
		img_size=$((`stat $tmpdir/$DISK -c %s`/1024/1024))
		img_size=$((img_size+300))

		echo "create mbr rescue img, size: ${img_size}M"
		dd if=/dev/zero bs=1M status=none conv=fsync count=$img_size of=$tmpdir/${img_name}.img
		parted -s $tmpdir/${img_name}.img -- mktable msdos
		parted -s $tmpdir/${img_name}.img -- mkpart p ext4 8192s -1s

		# get PTUUID
		eval `blkid -o export -s PTUUID $tmpdir/${img_name}.img`

		# mkfs.ext4
		echo "mount loopdev to format ext4 rescue img"
		modprobe loop
		lodev=$(losetup -f)
		losetup -P $lodev $tmpdir/${img_name}.img
		mkfs.ext4 -q -m 2 ${lodev}"p1"

		# mount rescue rootfs
		echo "mount rescue rootfs"
		mkdir -p $rootfs_mount_point
		mount ${lodev}"p1" $rootfs_mount_point

		# extract rescue rootfs
		echo "extract rescue rootfs($rootfs_rescue) to $rootfs_mount_point"
		tar -xpf $rootfs_rescue -C $rootfs_mount_point
		cp -f ./tools/rescue/emmc-install.sh $rootfs_mount_point/sbin
		echo "rootdev=PARTUUID=${PTUUID}-01" >> $rootfs_mount_point/boot/uEnv.txt

		echo "add ${os} img to rescue rootfs"
		mv -f $tmpdir/$DISK $rootfs_mount_point/root

		umount -l $rootfs_mount_point
		losetup -d $lodev

		mkdir -p $output/${os}
		mv -f $tmpdir/${img_name}.img $output/$os

		if [ -n "$TRAVIS_TAG" ]; then
			mkdir -p $output/release
			xz -T0 -v -f $output/$os/${img_name}.img
			mv $output/$os/${img_name}.img.xz $output/release
		fi
	fi

	rm -rf $tmpdir

	echo "release ${os} image done"
}

case "$1" in
generate)
	func_generate "$2" "$3"
	;;
release)
	func_release "$2" "$3" "$4"
	;;
*)
	echo "Usage: $0 { generate [rootfs] [KDIR] | release [rootfs] [KDIR] [RESCUE_ROOTFS] }"
	exit 1
	;;
esac
