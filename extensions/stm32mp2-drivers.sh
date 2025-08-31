function extension_finish_config__install_kernel_headers_for_stm32mp2-drivers-dkms_dkms() {

	if [[ "${KERNEL_HAS_WORKING_HEADERS}" != "yes" ]]; then
		display_alert "Kernel version has no working headers package" "skipping stm32mp2-drivers-dkms dkms for kernel v${KERNEL_MAJOR_MINOR}" "warn"
		return 0
	fi
	declare -g INSTALL_HEADERS="yes"
	display_alert "Forcing INSTALL_HEADERS=yes; for use with stm32mp2-drivers-dkms dkms" "${EXTENSION}" "debug"
}

function post_install_kernel_debs__install_stm32mp2-drivers-dkms_dkms_package() {

	[[ "${INSTALL_HEADERS}" != "yes" ]] || [[ "${KERNEL_HAS_WORKING_HEADERS}" != "yes" ]] && return 0
			
	use_clean_environment="yes" chroot_sdcard "curl -fsSL https://chainsx.github.io/stm32mp2-gpu-dkms/KEY.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/stm32mp2-gpu-archive-keyring.gpg >/dev/null"
	use_clean_environment="yes" chroot_sdcard "curl -fsSL https://chainsx.github.io/stm32mp2-tsn-dkms/KEY.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/stm32mp2-tsn-archive-keyring.gpg >/dev/null"
	
	use_clean_environment="yes" chroot_sdcard "wget https://github.com/chainsx/stm32mp2-gpu-dkms/raw/refs/heads/main/stm32mp2-gpu.sources -O /etc/apt/sources.list.d/stm32mp2-gpu.sources"
	use_clean_environment="yes" chroot_sdcard "wget https://github.com/chainsx/stm32mp2-tsn-dkms/raw/refs/heads/main/stm32mp2-tsn.sources -O /etc/apt/sources.list.d/stm32mp2-tsn.sources"
	
	display_alert "Install stm32mp2-drivers-dkms packages, will build kernel module in chroot" "${EXTENSION}" "info"
	
	use_clean_environment="yes" chroot_sdcard "apt update"
	use_clean_environment="yes" chroot_sdcard "apt install -y stm32mp2-gpu-full stm32mp2-gpu-driver"
	#use_clean_environment="yes" chroot_sdcard "apt install -y stm32mp2-gpu-full stm32mp2-gpu-driver stm32mp2-tsn*"
}
