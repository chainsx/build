# Allwinner Cortex-A53 quad core 2/4GB RAM SoC USB2 USB-C GbE
BOARD_NAME="100ASK ROSx"
BOARDFAMILY="sun50iw10-syterkit"
BOARD_MAINTAINER="chainsx"
KERNEL_TARGET="legacy"
BOOT_FDT_FILE="allwinner/sun50i-r818-dongshanpai-rosx.dtb"
SRC_EXTLINUX="yes"
SRC_CMDLINE="earlycon=uart8250,mmio32,0x05000000 clk_ignore_unused initcall_debug=0 console=ttyAS0,115200 loglevel=8 cma=64M init=/sbin/init"
BOOTFS_TYPE="fat"
BOOTSIZE="256"
SERIALCON="ttyAS0"
#declare -g SYTERKIT_BOARD_ID="avaota-a1" # This _only_ used for syterkit-allwinner extension

function post_family_tweaks__avaota-a1() {
	display_alert "Applying boot blobs"
	cp -v "$SRC/packages/blobs/sunxi/sun50iw10/bl31.bin" "$SDCARD/boot/bl31.bin"

	display_alert "Applying wifi firmware"
	pushd "$SDCARD/lib/firmware"
	ln -s "aic8800/SDIO/aic8800D80" "aic8800d80" # use armbian-firmware
	popd
}
