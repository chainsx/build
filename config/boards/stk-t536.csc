# Allwinner SoC USB3 USB-C GbE
BOARD_NAME="Embfly STK-T536"
BOARDFAMILY="sun55iw6"
BOARD_MAINTAINER=""
KERNEL_TARGET="legacy,vendor"
BOOT_FDT_FILE="allwinner/sun55i-t536-stk-t536.dtb"
SRC_EXTLINUX="yes"
SRC_CMDLINE="earlyprintk=sunxi-uart,0x02600000 clk_ignore_unused mac_addr=b2:27:e1:c8:92:0c mac_addr1=b2:27:e1:c8:92:0d initcall_debug=0 console=ttyAS0,115200 loglevel=8 rootwait cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 kasan=off init=/sbin/init"
