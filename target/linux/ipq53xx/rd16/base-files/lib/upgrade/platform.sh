#
# Copyright (C) 2024-2026 OpenWrt.org
# Platform upgrade script for Xiaomi Router BE3600 (RD16)
#

RAMFS_COPY_BIN="nvram"

platform_check_image() {
	local magic="$(get_magic_long "$1")"

	# Accept both raw factory.ubi and sysupgrade.bin (UBI# header 0x55424923)
	[ "$magic" = "55424923" ] && return 0

	echo "Invalid image: missing UBI signature"
	return 1
}

platform_pre_upgrade() {
	# Handle configuration backup in persistent /data partition
	if [ -f /tmp/sysupgrade.tgz ] && [ -d /data ]; then
		cp -f /tmp/sysupgrade.tgz /data/sysupgrade.tgz
		sync
	else
		rm -f /data/sysupgrade.tgz
	fi
}

platform_do_upgrade() {
	local boot_flag="$(nvram get flag_boot_rootfs 2>/dev/null)"
	local target_part=""

	case "$boot_flag" in
		0)
			target_part="rootfs"
			;;
		1)
			target_part="rootfs_1"
			;;
		*)
			echo "Error: unable to determine active slot via nvram (flag_boot_rootfs='$boot_flag')"
			return 1
			;;
	esac

	local target_mtd="$(find_mtd_index "$target_part")"
	[ -z "$target_mtd" ] && {
		echo "Error: target partition $target_part not found!"
		return 1
	}

	echo "Flashing firmware into active Slot $boot_flag ($target_part, /dev/mtd${target_mtd})..."

	# Detach UBI from target MTD (with force detach for active slot)
	ubidetach -f -m "$target_mtd" 2>/dev/null || ubidetach -m "$target_mtd"

	# Calculate pure UBI size aligned to eraseblock size (trims fwtool metadata if present)
	local file_size="$(wc -c < "$1")"
	local eb_size="$(cat "/sys/class/mtd/mtd${target_mtd}/erasesize" 2>/dev/null || echo 131072)"
	local ubi_size="$(( file_size - (file_size % eb_size) ))"

	ubiformat "/dev/mtd${target_mtd}" -f - -S "$ubi_size" -s 2048 -O 2048 -y < "$1"
	local ret=$?

	sync
	return $ret
}
