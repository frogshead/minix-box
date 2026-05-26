# minix-box U-Boot boot script (compiled to boot.scr by Buildroot).
# Loads the kernel + DTB from the first FAT/boot partition of the microSD and boots.
#
# Load addresses are in the suniv DRAM window (base 0x80000000).
setenv bootargs console=ttyS0,115200 earlyprintk root=/dev/mmcblk0p2 rootwait rootfstype=ext4

setenv kernel_addr_r 0x80008000
setenv fdt_addr_r    0x80c08000

load mmc 0:1 ${kernel_addr_r} zImage
load mmc 0:1 ${fdt_addr_r} suniv-f1c200s-minix-box.dtb
bootz ${kernel_addr_r} - ${fdt_addr_r}
