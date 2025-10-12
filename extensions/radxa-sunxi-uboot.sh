#
# SPDX-License-Identifier: GPL-2.0
# This file is a part of the Armbian Build Framework https://github.com/armbian/build/

# This writes the uboot bootloader img to the image.
function post_umount_final_image__write_sunxi_uboot_to_image() {
	display_alert "Finding Radxa sunxi U-Boot" "from GitHub" "info"

	declare tested_version="2018.07-9"

	# Prepare the cache dir
	declare uboot_cache_dir="${SRC}/cache/sunxi-uboot"
	mkdir -p "${uboot_cache_dir}"

	declare uboot_img_filename="u-boot-aw2501_${tested_version}_all.deb"
	declare -g -r uboot_img_path="${uboot_cache_dir}/${uboot_img_filename}"
	display_alert "uboot image path" "${uboot_img_path}" "info"

	declare download_url="https://github.com/radxa-pkg/u-boot-aw2501/releases/download/${tested_version}/${uboot_img_filename}"

	# Download the image (with wget) if it doesn't exist; download to a temporary file first, then move to the final path.
	if [[ ! -f "${uboot_cache_dir}/usr/lib/u-boot/$BOARD/boot_package.fex" ]]; then
		display_alert "Downloading uboot image" "${download_url}" "info"
		declare tmp_uboot_img_path="${uboot_img_path}.tmp"
		run_host_command_logged wget -O "${tmp_uboot_img_path}" "${download_url}"
		run_host_command_logged mv -v "${tmp_uboot_img_path}" "${uboot_img_path}"
		display_alert " Decompressing uboot image to" "${uboot_img_path}/${uboot_BOARD_ID}" "info"
		mkdir -p ${uboot_cache_dir}/${uboot_BOARD_ID}
		run_host_command_logged dpkg -X ${uboot_img_path} ${uboot_cache_dir}
	else
		display_alert "uboot image already downloaded, using it" "${uboot_img_path}" "info"
	fi

	display_alert " Writing uboot image" "${uboot_img_path} to ${LOOP}" "info"
	dd conv=notrunc,fsync if="${uboot_cache_dir}/usr/lib/u-boot/$BOARD/boot0_sdcard.bin" of="${LOOP}" bs=512 seek=256
	dd conv=notrunc,fsync if="${uboot_cache_dir}/usr/lib/u-boot/$BOARD/boot0_ufs.bin" of="${LOOP}" bs=512 seek=2064
	dd conv=notrunc,fsync if="${uboot_cache_dir}/usr/lib/u-boot/$BOARD/boot_package.fex" of="${LOOP}" bs=512 seek=24576
}
