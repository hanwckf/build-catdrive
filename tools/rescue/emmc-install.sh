#!/bin/sh

img="/root/rootfs.img"
disk="/dev/mmcblk0"

[ ! -f $img ] && echo "$img not found!" && exit 1
[ ! -e $disk ] && echo "emmc not found!" && exit 1

echo "flash emmc..."
echo 2 > /sys/class/leds/red/blink

pv -pterb $img | dd of=$disk conv=fsync bs=2M

[ "$?" = "0" ] && echo "flash done, please unplug USB drive and reboot now!" || echo "flash fail!"
echo 0 > /sys/class/leds/red/blink
