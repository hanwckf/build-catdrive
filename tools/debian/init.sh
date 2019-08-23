#!/bin/sh

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

export DEBIAN_FRONTEND=noninteractive
apt_arg='-q -y -o Dpkg::Progress-Fancy="0"'

cat <<EOF > ./usr/sbin/policy-rc.d
#!/bin/sh
exit 101

EOF
chmod +x ./usr/sbin/policy-rc.d

/debootstrap/debootstrap --second-stage
apt clean

mount -t devpts none /dev/pts

apt $apt_arg update && \
	apt $apt_arg install aptitude openssh-server haveged net-tools network-manager parted u-boot-tools
apt clean

aptitude search ~pstandard ~prequired ~pimportant -F "%p" |xargs apt $apt_arg install
apt clean

systemctl set-default multi-user.target
systemctl disable networking
systemctl enable network-manager

cat <<EOF > ./etc/udev/rules.d/99-hdparm.rules
ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd*",ENV{ID_BUS}=="ata", ENV{DEVTYPE}=="disk", RUN+="/sbin/hdparm -S 120 \$env{DEVNAME}"

EOF

echo "en_US.UTF-8 UTF-8" > ./etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > ./etc/default/locale
ln -sf /usr/share/zoneinfo/Asia/Shanghai ./etc/localtime
sed -i '/^#PermitRootLogin/cPermitRootLogin yes' ./etc/ssh/sshd_config
sed -i '/^#NTP/cNTP=time1.aliyun.com 2001:470:0:50::2' ./etc/systemd/timesyncd.conf
ln -sf /lib/systemd/system/getty@.service ./etc/systemd/system/getty.target.wantsgetty@ttyMV0.service
echo "ttyMV0" >> ./etc/securetty
echo "/dev/mmcblk0p1 / ext4 defaults,noatime,nodiratime,errors=remount-ro 0 1" >> ./etc/fstab
echo "vm.zone_reclaim_mode=1" > ./etc/sysctl.d/99-vm-reclaim.conf
echo "/dev/mtd1 0x0000 0x10000 0x10000" > ./etc/fw_env.config
echo "catdrive" > ./etc/hostname
echo "root:admin" |chpasswd

rm -rf ./var/cache
rm -rf ./var/lib/apt/*
rm -f ./usr/sbin/policy-rc.d

umount /dev/pts
