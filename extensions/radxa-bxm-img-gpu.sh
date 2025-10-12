function extension_finish_config__install_kernel_headers_for_aw-drivers-dkms_dkms() {

	if [[ "${KERNEL_HAS_WORKING_HEADERS}" != "yes" ]]; then
		display_alert "Kernel version has no working headers package" "skipping aw-drivers-dkms dkms for kernel v${KERNEL_MAJOR_MINOR}" "warn"
		return 0
	fi
	declare -g INSTALL_HEADERS="yes"
	display_alert "Forcing INSTALL_HEADERS=yes; for use with aw-drivers-dkms dkms" "${EXTENSION}" "debug"
}

function post_install_kernel_debs__install_aw-drivers-dkms_dkms_package() {

	[[ "${INSTALL_HEADERS}" != "yes" ]] || [[ "${KERNEL_HAS_WORKING_HEADERS}" != "yes" ]] && return 0
	api_url="https://api.github.com/repos/radxa-pkg/aw-drivers-dkms/releases/latest"
	latest_version=$(curl -s "${api_url}" | jq -r '.tag_name')
	aw_drivers_dkms_url="https://github.com/radxa-pkg/aw-drivers-dkms/releases/download/${latest_version}/img-bxm-dkms_${latest_version}_all.deb"
			
	use_clean_environment="yes" chroot_sdcard "wget ${aw_drivers_dkms_url} -P /tmp"
	display_alert "Install aw-drivers-dkms packages, will build kernel module in chroot" "${EXTENSION}" "info"
	declare -ag if_error_find_files_sdcard=("/var/lib/dkms/img-bxm-dkms*/*/build/*.log")
	use_clean_environment="yes" chroot_sdcard_apt_get_install "/tmp/img-bxm-dkms_${latest_version}_all.deb"
	use_clean_environment="yes" chroot_sdcard "rm -f /tmp/img-bxm-dkms_${latest_version}_all.deb"
}
