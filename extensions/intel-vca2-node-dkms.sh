# SPDX-License-Identifier: GPL-2.0
#
# Install the Intel VCA2 card-side node DKMS package into an Ubuntu 24.04
# image. This extension must never be enabled for a VCA PCIe host image.

function extension_finish_config__intel_vca2_node_dkms_requirements() {
	if [[ "${ARCH}" != "amd64" ]]; then
		display_alert "Intel VCA2 node DKMS requires amd64" "ARCH=${ARCH}" "error"
		return 1
	fi

	if [[ "${RELEASE}" != "noble" ]]; then
		display_alert "Intel VCA2 node DKMS is pinned to Ubuntu 24.04" "RELEASE=${RELEASE}" "error"
		return 1
	fi

	if [[ "${KERNEL_HAS_WORKING_HEADERS}" != "yes" ]]; then
		display_alert "Kernel headers are required for Intel VCA2 node DKMS" "kernel v${KERNEL_MAJOR_MINOR}" "error"
		return 1
	fi

	# The VCA package compiles against the kernel installed in the image rootfs.
	# This makes Armbian install its matching kernel headers before this hook.
	declare -g INSTALL_HEADERS="yes"
	display_alert "Forcing INSTALL_HEADERS=yes for Intel VCA2 node DKMS" "${EXTENSION}" "debug"
}

function post_install_kernel_debs__install_intel_vca2_node_dkms_package() {
	if [[ "${INSTALL_HEADERS}" != "yes" || "${KERNEL_HAS_WORKING_HEADERS}" != "yes" ]]; then
		return 0
	fi

	local package_name="vca2-vcass-node-modules-dkms"
	local package_version="2.3.26+ubuntu24.04.9"
	local package_file="${package_name}_${package_version}_all.deb"
	local package_path="/tmp/${package_file}"
	local package_url="${VCA2_NODE_DKMS_DEB_URL:-https://github.com/chainsx/intel-vca2-dkms/releases/download/v0.0.4/${package_file}}"
	local package_repack_dir="/tmp/vca2-vcass-node-repack"
	local package_repack_postinst="${SDCARD}${package_repack_dir}/DEBIAN/postinst"
	local expected_kver="${IMAGE_INSTALLED_KERNEL_VERSION}-${BRANCH}-${LINUXFAMILY}"
	local target_kver=""
	local initrd_path=""
	local module=""
	local kernel_gcc_version=""
	local kernel_gcc_major=""
	local dkms_cc_package=""
	local dkms_cc=""
	local -a discovered_kvers=()

	# This is the upstream node initramfs-hook module list. Modules not produced
	# by a particular kernel build are skipped when the local modules file is
	# written; the package's own initramfs hook uses the same tolerant approach.
	local -a early_modules=(
		vop_bus
		vca_csm_bus
		vca_mgr_bus
		vca_mgr_extd_bus
		vca_csa_bus
		vca_virtio
		vca_virtio_ring
		vca_vringh
		vca_virtio_net
		vca_csa
		vop
		vcablkfe
		vcablk_bckend
		plx87xx_dma
		plx87xx
	)

	# These are required for a VCA BlockIO root device; fail the image build if
	# they are missing from the installed target-kernel module tree or initramfs.
	local -a required_modules=(
		vop_bus
		vca_csa_bus
		vca_virtio
		vca_virtio_ring
		vca_vringh
		vca_virtio_net
		vca_csa
		vop
		vcablkfe
		plx87xx_dma
		plx87xx
	)

	if [[ "${ARCH}" != "amd64" || "${RELEASE}" != "noble" ]]; then
		display_alert "Refusing Intel VCA2 node DKMS install outside amd64/Noble" "ARCH=${ARCH}, RELEASE=${RELEASE}" "error"
		return 1
	fi

	# Do not use uname -r in a build chroot: it identifies the build container
	# kernel, not the kernel packaged in the generated image. Prefer Armbian's
	# expected name and otherwise accept the sole real module directory.
	if [[ -n "${IMAGE_INSTALLED_KERNEL_VERSION:-}" && -d "${SDCARD}/lib/modules/${expected_kver}" ]]; then
		target_kver="${expected_kver}"
	else
		mapfile -t discovered_kvers < <(
			find "${SDCARD}/lib/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -V
		)

		if (( ${#discovered_kvers[@]} == 1 )); then
			target_kver="${discovered_kvers[0]}"
		else
			display_alert "Cannot determine target kernel for Intel VCA2 node DKMS" \
				"expected=${expected_kver}; found=${discovered_kvers[*]:-none}" "error"
			return 1
		fi
	fi

	initrd_path="/boot/initrd.img-${target_kver}"

	# The build link is normally absolute:
	# /lib/modules/<release>/build -> /usr/src/linux-headers-<release>.
	# Test it inside the target rootfs rather than from the build host.
	if ! use_clean_environment="yes" chroot_sdcard \
		"test -d '/lib/modules/${target_kver}/build' && test -f '/lib/modules/${target_kver}/build/Makefile'"; then
		display_alert "Cannot locate usable target kernel headers for Intel VCA2 node DKMS" "${target_kver}" "error"
		use_clean_environment="yes" chroot_sdcard \
			"ls -ld '/lib/modules/${target_kver}' '/lib/modules/${target_kver}/build' 2>/dev/null || true; \
			 readlink '/lib/modules/${target_kver}/build' 2>/dev/null || true; \
			 ls -ld /usr/src/linux-headers-* 2>/dev/null || true"
		return 1
	fi

	# A module must be compiled by a compiler that supports the target kernel's
	# recorded Kbuild flags. Armbian's x86 current 6.18 package is built with
	# GCC 14, whereas a Noble rootfs defaults to GCC 13. Kbuild consequently
	# passes GCC-14-only flags such as -fmin-function-alignment=16 to DKMS.
	#
	# Do not read ${SDCARD}/lib/modules/<release>/build from the build host.
	# Armbian's build link is normally absolute and therefore resolves to the
	# build host's /usr/src instead of the image rootfs. Query all kernel metadata
	# from inside the target rootfs. VCA2_NODE_DKMS_GCC_MAJOR is an explicit
	# escape hatch for an unusual kernel/compiler combination.
	kernel_gcc_major="${VCA2_NODE_DKMS_GCC_MAJOR:-}"

	if ! [[ "${kernel_gcc_major}" =~ ^[1-9][0-9]*$ ]]; then
		kernel_gcc_version="$(use_clean_environment="yes" chroot_sdcard "
			for kernel_config in \\
				'/boot/config-${target_kver}' \\
				'/lib/modules/${target_kver}/build/.config' \\
				'/lib/modules/${target_kver}/build/include/config/auto.conf' \\
				'/lib/modules/${target_kver}/build/include/generated/autoconf.h'; do
				test -r \"\${kernel_config}\" || continue
				kernel_gcc_metadata=\$(grep -m 1 -E '^(CONFIG_GCC_VERSION=|#define CONFIG_GCC_VERSION )' \"\${kernel_config}\" 2>/dev/null | tr -cd '0-9')
				if test -n \"\${kernel_gcc_metadata}\"; then
					printf '%s\\n' \"\${kernel_gcc_metadata}\"
					exit 0
				fi
			done
			exit 0
		" 2>/dev/null || true)"

		if [[ "${kernel_gcc_version}" =~ ^[0-9]{5,}$ ]]; then
			kernel_gcc_major="$((10#${kernel_gcc_version} / 10000))"
		fi
	fi

	# Header packages can omit .config and generated autoconf data. Fall back to
	# the recorded compiler string, for example:
	# x86_64-linux-gnu-gcc (Debian 14.2.0-19) 14.2.0.
	if ! [[ "${kernel_gcc_major}" =~ ^[1-9][0-9]*$ ]]; then
		kernel_gcc_major="$(use_clean_environment="yes" chroot_sdcard "
			for compiler_header in \\
				'/lib/modules/${target_kver}/build/include/generated/compile.h' \\
				'/lib/modules/${target_kver}/build/include/linux/compiler-version.h'; do
				test -r \"\${compiler_header}\" || continue
				compiler_version=\$(grep -E 'LINUX_COMPILER|GCC:' \"\${compiler_header}\" 2>/dev/null | \\
					grep -oE '[0-9]+\\.[0-9]+(\\.[0-9]+)?' | tail -n 1 | cut -d. -f1)
				if test -n \"\${compiler_version}\"; then
					printf '%s\\n' \"\${compiler_version}\"
					exit 0
				fi
			done
			exit 0
		" 2>/dev/null || true)"
	fi

	# linux-headers-current-x86 6.18.37 is known to have been built with GCC 14.
	# Keep this fallback scoped to the VCA2 DKMS compiler selection rather than
	# replacing the rootfs default compiler. It may be overridden at build time:
	# VCA2_NODE_DKMS_GCC_MAJOR=<N> ./compile.sh ...
	if ! [[ "${kernel_gcc_major}" =~ ^[1-9][0-9]*$ ]]; then
		kernel_gcc_major="14"
		display_alert "Target kernel GCC metadata unavailable; using VCA2 fallback" \
			"gcc-${kernel_gcc_major}; set VCA2_NODE_DKMS_GCC_MAJOR to override" "info"
	fi
	dkms_cc_package="gcc-${kernel_gcc_major}"
	dkms_cc="/usr/bin/${dkms_cc_package}"

	display_alert "Installing Intel VCA2 node DKMS package" \
		"kernel ${target_kver}; compiler ${dkms_cc_package}" "info"

	# Install only user-space build prerequisites. The target kernel and headers
	# were already installed from the Armbian kernel .deb files.
	use_clean_environment="yes" chroot_sdcard_apt_get_install \
		ca-certificates \
		wget \
		dkms \
		build-essential \
		initramfs-tools \
		isc-dhcp-client \
		"${dkms_cc_package}"

	if ! use_clean_environment="yes" chroot_sdcard \
		"test -x '${dkms_cc}' && '${dkms_cc}' -dumpfullversion | grep -Eq '^${kernel_gcc_major}\\.'"; then
		display_alert "Target-compatible GCC is unavailable in the rootfs" \
			"required=${dkms_cc_package}; kernel=${target_kver}" "error"
		return 1
	fi

	use_clean_environment="yes" chroot_sdcard \
		"rm -rf '${package_repack_dir}' '${package_path}'"

	use_clean_environment="yes" chroot_sdcard \
		"wget --https-only --no-verbose --output-document='${package_path}' '${package_url}'"

	# Reject an HTML error response, a redirect to an unrelated asset, or the
	# VCA host-side package before altering the target rootfs.
	use_clean_environment="yes" chroot_sdcard \
		"test \"\$(dpkg-deb -f '${package_path}' Package)\" = '${package_name}' && \
		 test \"\$(dpkg-deb -f '${package_path}' Version)\" = '${package_version}'"

	# Upstream's postinst invokes dkms build/install without -k. In Armbian's
	# image-build chroot this targets uname -r from the builder and fails before
	# the extension can run dkms autoinstall for the image kernel. The package's
	# DKMS MAKE entry also starts with plain `make`, which uses Noble's GCC 13.
	# Repack only the downloaded local .deb: pin the kernel in postinst and add
	# CC=<target compiler> to every DKMS MAKE[] command.
	use_clean_environment="yes" chroot_sdcard \
		"dpkg-deb -R '${package_path}' '${package_repack_dir}'"

    # The Debian package version alone is insufficient: reject an artifact that
    # does not contain the known Linux 6.18 BlockIO disk-minor-range fix.
    if ! use_clean_environment="yes" chroot_sdcard \
        "vcablk_disk=\"\$(find '${package_repack_dir}' -type f -path '*vcablk/vcablk_disk.c' -print -quit)\"; \\
         test -n \"\$vcablk_disk\"; \\
         grep -Eq '^[[:space:]]*disk->minors[[:space:]]*=[[:space:]]*VCA_BLK_MINORS;' \"\$vcablk_disk\""; then
        display_alert "VCA2 node DKMS artifact lacks Linux 6.18 BlockIO fix" \
            "disk->minors = VCA_BLK_MINORS" "error"
        return 1
    fi

	if ! use_clean_environment="yes" chroot_sdcard \
		"dkms_conf=\"\$(find '${package_repack_dir}' -type f -name dkms.conf -print -quit)\"; \
		 test -n \"\$dkms_conf\"; \
		 sed -i 's#^MAKE\\(\\[[0-9][0-9]*\\]\\)=\"make #MAKE\\1=\"make CC=${dkms_cc} #' \"\$dkms_conf\"; \
		 grep -qF 'CC=${dkms_cc}' \"\$dkms_conf\""; then
		display_alert "Cannot rewrite VCA2 DKMS compiler command" "${package_name}" "error"
		return 1
	fi

	cat > "${package_repack_postinst}" <<EOF_POSTINST
#!/bin/sh
set -eu

NAME="vca2-vcass-node"
VERSION="${package_version}"
TARGET_KERNEL="${target_kver}"
DKMS_CC="${dkms_cc}"

case "\${1:-}" in
configure)
	if command -v dkms >/dev/null 2>&1; then
		test -x "\$DKMS_CC"
		export CC="\$DKMS_CC"
		if ! dkms status -m "\$NAME" -v "\$VERSION" 2>/dev/null | grep -q "^\$NAME/\$VERSION"; then
			dkms add -m "\$NAME" -v "\$VERSION"
		fi

		dkms build -m "\$NAME" -v "\$VERSION" -k "\$TARGET_KERNEL"
		dkms install -m "\$NAME" -v "\$VERSION" -k "\$TARGET_KERNEL" --force
	fi

	depmod -a "\$TARGET_KERNEL"
	update-initramfs -u -k "\$TARGET_KERNEL"
	systemctl daemon-reload >/dev/null 2>&1 || true
	systemctl enable vca_agent.service >/dev/null 2>&1 || true
	;;
esac

exit 0
EOF_POSTINST

	chmod 0755 "${package_repack_postinst}"

	use_clean_environment="yes" chroot_sdcard \
		"dpkg-deb -b '${package_repack_dir}' '${package_path}' >/dev/null"

	# Preserve real compiler errors in Armbian's error bundle. Current DKMS may
	# use either <version>/<kernel>/log or <version>/<kernel>/<arch>/log.
	declare -ag if_error_find_files_sdcard=(
		"/var/lib/dkms/vca2-vcass-node*/*/*/log/make.log"
		"/var/lib/dkms/vca2-vcass-node*/*/*/*/log/make.log"
	)

	if ! use_clean_environment="yes" chroot_sdcard \
		"DEBIAN_FRONTEND=noninteractive apt-get --yes --no-install-recommends install '${package_path}'"; then
		display_alert "Intel VCA2 node DKMS package postinst failed" "kernel ${target_kver}" "error"
		use_clean_environment="yes" chroot_sdcard \
			"dkms status -m 'vca2-vcass-node' -v '${package_version}' || true; \
			 find /var/lib/dkms/vca2-vcass-node* -type f -name make.log -print -exec tail -n 160 {} \; 2>/dev/null || true"
		return 1
	fi

	# Repeat the image-kernel lifecycle after dpkg configuration. This makes the
	# desired target explicit and protects the image if a future package release
	# changes its maintainer scripts.
	use_clean_environment="yes" chroot_sdcard "CC='${dkms_cc}' dkms autoinstall -k '${target_kver}'"
	use_clean_environment="yes" chroot_sdcard "depmod -a '${target_kver}'"
	use_clean_environment="yes" chroot_sdcard "update-initramfs -u -k '${target_kver}'"
    # vca_agent.sh uses dhclient. Its packaged unit also contains
    # Requires=default.target; clear that reverse dependency and wait for VCA
    # sysfs before the agent is allowed to start.
    install -d -m 0755 \
        "${SDCARD}/usr/local/sbin" \
        "${SDCARD}/etc/systemd/system/vca_agent.service.d"

    cat > "${SDCARD}/usr/local/sbin/vca-wait-sysfs" <<'EOF_VCA2_WAIT_SYSFS'
#!/bin/sh
set -eu

i=0
while [ "${i}" -lt 30 ]; do
    if [ -e /sys/class/vca/vca/state ] && \
       [ -e /sys/class/vca/vca/csa_mem ] && \
       [ -e /sys/class/vca/vca/sys_config ]; then
        exit 0
    fi
    i=$((i + 1))
    sleep 1
done

exit 1
EOF_VCA2_WAIT_SYSFS
    chmod 0755 "${SDCARD}/usr/local/sbin/vca-wait-sysfs"

    cat > "${SDCARD}/etc/systemd/system/vca_agent.service.d/10-vca-runtime.conf" <<'EOF_VCA2_AGENT_DROPIN'
[Unit]
# Reset the Requires=default.target dependency shipped by the package.
Requires=
After=systemd-modules-load.service
Wants=systemd-modules-load.service

[Service]
ExecStartPre=/usr/local/sbin/vca-wait-sysfs
Restart=on-failure
RestartSec=3
EOF_VCA2_AGENT_DROPIN

    if ! grep -qxF 'ExecStartPre=/usr/local/sbin/vca-wait-sysfs' \
        "${SDCARD}/etc/systemd/system/vca_agent.service.d/10-vca-runtime.conf"; then
        display_alert "Cannot create VCA2 agent runtime drop-in" "missing ExecStartPre" "error"
        return 1
    fi

	use_clean_environment="yes" chroot_sdcard "systemctl enable vca_agent.service"

	# Include every module known to the package hook whenever it was built.
	use_clean_environment="yes" chroot_sdcard "touch /etc/initramfs-tools/modules"
	for module in "${early_modules[@]}"; do
		if use_clean_environment="yes" chroot_sdcard \
			"modinfo -k '${target_kver}' '${module}' >/dev/null 2>&1"; then
			use_clean_environment="yes" chroot_sdcard \
				"grep -qxF '${module}' /etc/initramfs-tools/modules 2>/dev/null || printf '%s\\n' '${module}' >> /etc/initramfs-tools/modules"
		fi
	done

	# Regenerate after extending /etc/initramfs-tools/modules.
	use_clean_environment="yes" chroot_sdcard "update-initramfs -u -k '${target_kver}'"

	if ! use_clean_environment="yes" chroot_sdcard "test -r '${initrd_path}'"; then
		display_alert "Target initramfs was not created" "${initrd_path}" "error"
		return 1
	fi

	for module in "${required_modules[@]}"; do
		if ! use_clean_environment="yes" chroot_sdcard \
			"modinfo -k '${target_kver}' '${module}' >/dev/null 2>&1"; then
			display_alert "Required VCA2 node module was not built" "${module} for ${target_kver}" "error"
			return 1
		fi

		if ! use_clean_environment="yes" chroot_sdcard \
			"initramfs_list=\$(mktemp); \
			 trap 'rm -f \"\$initramfs_list\"' EXIT HUP INT TERM; \
			 lsinitramfs '${initrd_path}' >\"\$initramfs_list\" && \
			 grep -Fq -- '/${module}.ko' \"\$initramfs_list\""; then
			display_alert "Required VCA2 node module is missing from initramfs" "${module} in ${initrd_path}" "error"
			return 1
		fi
	done

	use_clean_environment="yes" chroot_sdcard \
		"rm -rf '${package_repack_dir}' '${package_path}'"
}

# This runs after Armbian has created the final partition table and written
# the real root/EFI entries to ${SDCARD}/etc/fstab.
function format_partitions__harden_intel_vca2_node_efi_mount() {
    local fstab="${SDCARD}/etc/fstab"
    local efi_mount="${UEFI_MOUNT_POINT:-/boot/efi}"
    local tmp="${fstab}.vca2.tmp"

    [[ "${ARCH}" == "amd64" && "${RELEASE}" == "noble" ]] || return 0

    if [[ ! -f "${fstab}" ]]; then
        display_alert "Cannot harden VCA2 EFI mount" \
            "target /etc/fstab is missing at format_partitions" "error"
        return 1
    fi

    # A deliberately omitted EFI fstab entry needs no nofail hardening.
    if [[ "${UEFI_MOUNT_POINT_SKIP_FSTAB:-no}" == "yes" ]]; then
        display_alert "Skipping VCA2 EFI fstab hardening" \
            "UEFI_MOUNT_POINT_SKIP_FSTAB=yes" "debug"
        return 0
    fi

    if ! awk -v mountpoint="${efi_mount}" '
        /^[[:space:]]*#/ || NF < 4 { next }
        $2 == mountpoint { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "${fstab}"; then
        display_alert "Cannot harden VCA2 EFI mount" \
            "${efi_mount} not found in final target fstab" "error"
        return 1
    fi

    if ! awk -v mountpoint="${efi_mount}" '
        BEGIN { OFS="\t" }

        /^[[:space:]]*#/ || NF < 4 || $2 != mountpoint {
            print
            next
        }

        {
            if ($4 !~ /(^|,)nofail(,|$)/)
                $4 = $4 ",nofail"

            if ($4 !~ /(^|,)x-systemd\.device-timeout=5s(,|$)/)
                $4 = $4 ",x-systemd.device-timeout=5s"

            print
        }
    ' "${fstab}" > "${tmp}"; then
        rm -f "${tmp}"
        display_alert "Cannot harden VCA2 EFI mount" \
            "failed to rewrite final target fstab" "error"
        return 1
    fi

    mv "${tmp}" "${fstab}"
}
