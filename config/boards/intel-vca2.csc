# SPDX-License-Identifier: GPL-2.0
#
# Intel Visual Compute Accelerator 2 (VCA2) node.
#
# This is a card-side node profile. It inherits Armbian's generic x86_64
# UEFI/GRUB family and installs only the VCA node DKMS package into the image
# rootfs. Do not use this board profile for the PCIe host OS.

declare -g BOARD_NAME="Intel VCA2 node"
declare -g BOARD_VENDOR="Intel"
declare -g BOARDFAMILY="uefi-x86"
declare -g BOARD_MAINTAINER="chainsx"
declare -g INTRODUCED="2018"

# Keep the board on the normal UEFI x86 kernel track. The node extension
# explicitly verifies the installed target headers before invoking DKMS.
declare -g KERNEL_TARGET="current"
declare -g KERNEL_TEST_TARGET="current"

# VCA2 node images use the card serial console during early boot.
declare -g SERIALCON="ttyS0,115200n8"
declare -g DEFAULT_CONSOLE="serial"
declare -g HAS_VIDEO_OUTPUT="no"
declare -g UEFI_GRUB_TERMINAL="serial console"
declare -g BOOT_LOGO=""

# The extension is executed only after the target kernel .deb files have been
# installed into the image rootfs.
enable_extension "intel-vca2-node-dkms"
