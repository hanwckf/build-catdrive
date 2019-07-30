setenv rootdev "/dev/mmcblk0p1"
setenv verbosity "1"
setenv rootfstype "ext4"

load ${boot_interface} ${devnum}:1 ${scriptaddr} ${prefix}uEnv.txt
env import -t ${scriptaddr} ${filesize}

setenv bootargs "$console root=${rootdev} rootfstype=${rootfstype} rootwait loglevel=${verbosity} usb-storage.quirks=${usbstoragequirks} ${extraargs}"

setenv fdt_name_a armada-3720-catdrive.dtb

ext4load $boot_interface 0:1 $kernel_addr ${prefix}$image_name
ext4load $boot_interface 0:1 $fdt_addr ${prefix}$fdt_name_a

booti $kernel_addr - $fdt_addr
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr
