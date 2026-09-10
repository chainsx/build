# Allwinner Cortex-A55 octa core 2/4GB RAM SoC USB3 USB-C 2x GbE LCD
BOARD_NAME="Avaota A1"
BOARDFAMILY="sun55iw3-vendor"
BOARD_MAINTAINER="chainsx"
KERNEL_TARGET="vendor"
BOOT_FDT_FILE="allwinner/sun55i-t527-avaota-a1.dtb"
SERIALCON="ttyAS0"
BOOTCONFIG="sun55iw3_defconfig"
SRC_EXTLINUX="yes"
SRC_CMDLINE="earlycon=uart8250,mmio32,0x02500000 clk_ignore_unused initcall_debug=0 console=ttyAS0,115200 loglevel=8 rootwait cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 kasan=off init=/sbin/init"

function post_family_config__uboot_config() {
	display_alert "$BOARD" "BSP U-Boot overrides for $BOARD - $BRANCH" "info"
	UBOOT_TARGET_MAP="boot-package-t527;;boot0_sdcard.fex boot_package.fex"
}

function post_family_tweaks__avaota-a1() {
	display_alert "Applying wifi firmware"
	pushd "$SDCARD/lib/firmware"
	ln -s "aic8800/SDIO/aic8800D80" "aic8800d80" # use armbian-firmware
	popd
}
