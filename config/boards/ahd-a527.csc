# Allwinner SoC USB3 USB-C GbE
BOARD_NAME="Embfly AHD-A527"
BOARDFAMILY="sun55iw3-vendor"
BOARD_MAINTAINER=""
KERNEL_TARGET="legacy,vendor"
BOOT_FDT_FILE="allwinner/sun55i-a527-ahd-a527.dtb"
SERIALCON="ttyAS0"
SRC_EXTLINUX="yes"
SRC_CMDLINE="earlycon=uart8250,mmio32,0x02500000 clk_ignore_unused initcall_debug=0 console=ttyAS0,115200 loglevel=8 rootwait cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 kasan=off init=/sbin/init"

function post_family_tweaks__ahd-a527() {
	display_alert "Applying boot blobs"
	cp -v "$SRC/packages/blobs/sunxi/sun55iw3-vendor/bcmdhd/brcm_patchram_plus" "$SDCARD/usr/bin/brcm_patchram_plus"
	cp -v $SRC/packages/blobs/sunxi/sun55iw3-vendor/bcmdhd/firmware/* $SDCARD/lib/firmware
}
