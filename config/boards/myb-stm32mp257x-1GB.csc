# MYiR MYB-STM32MP257X: STM32MP257F, dual Cortex-A35, 1GB LPDDR4
# 3x GbE (2x YT8531S + internal switch), LT9611 HDMI, ES8388 audio,
# OV5640 camera, Broadcom SDIO WiFi, USB3, USB-C
BOARD_NAME="MYB-STM32MP257X 1GB"
BOARDFAMILY="stm32mp2-st"
BOARD_MAINTAINER="chainsx <chainsx@users.noreply.github.com>"
KERNEL_TARGET="vendor"
BOOTCONFIG="myb_stm32mp257x_1g_defconfig"
BOOT_FDT_FILE="st/myb-stm32mp257x-1GB.dtb"
SRC_EXTLINUX="yes"
SRC_CMDLINE="earlycon nosplash loglevel=7 console=ttySTM0,115200"
SERIALCON="ttySTM0"
