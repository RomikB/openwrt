#!/bin/sh
set -e

# Parse arguments and determine target model & firmware file path
TARGET_MODEL="rd15"
FW_FILE=""

if [ "$1" = "rd15" ]; then
	TARGET_MODEL="rd15"
	shift
elif [ "$1" = "rd16" ]; then
	TARGET_MODEL="rd16"
	shift
fi

if [ -n "$1" ]; then
	FW_FILE="$1"
	case "$FW_FILE" in
		*rd16*) TARGET_MODEL="rd16" ;;
		*rd15*) TARGET_MODEL="rd15" ;;
	esac
else
	for f in miwifi_${TARGET_MODEL}_firmware_*.bin; do
		if [ -f "$f" ]; then
			FW_FILE="$f"
			break
		fi
	done
fi

# Validate firmware file existence
if [ -z "$FW_FILE" ] || [ ! -f "$FW_FILE" ]; then
	echo "Error: Firmware file not found for target $TARGET_MODEL." >&2
	echo "Usage: $0 [rd15|rd16] [firmware_file.bin]" >&2
	exit 1
fi
echo "Target model: $TARGET_MODEL"
echo "Using firmware image: $FW_FILE"

PACKAGES_LIST="vendor_scripts/packages.list"
REQUIRED_LIST="vendor_scripts/required.list"
IGNORED_LIST="vendor_scripts/ignored.list"
NATIVE_LIST="vendor_scripts/native.list"

if [ ! -f "$PACKAGES_LIST" ]; then
	echo "Error: Packages list file not found at $PACKAGES_LIST" >&2
	exit 1
fi

if [ ! -f "$REQUIRED_LIST" ]; then
	echo "Error: Required packages list file not found at $REQUIRED_LIST" >&2
	exit 1
fi

if [ ! -f "$IGNORED_LIST" ]; then
	echo "Error: Ignored packages list file not found at $IGNORED_LIST" >&2
	exit 1
fi

ADD_VENDOR_PACKAGES=$(grep -v '^[[:space:]]*#' "$PACKAGES_LIST" | grep -v '^[[:space:]]*$' | tr '\n' ' ')
IGNORE_VENDOR_PACKAGES=$(grep -v '^[[:space:]]*#' "$IGNORED_LIST" | grep -v '^[[:space:]]*$' | tr '\n' ' ')
NATIVE_VENDOR_PACKAGES=""
if [ -f "$NATIVE_LIST" ]; then
	NATIVE_VENDOR_PACKAGES=$(grep -v '^[[:space:]]*#' "$NATIVE_LIST" | grep -v '^[[:space:]]*$' | tr '\n' ' ')
fi

# Prepare temporary directory
TMP_DIR="./tmp"
FEED_DIR="./vendor_feed"
FW_TMP_DIR="$TMP_DIR/fw_extract"
mkdir -p "$TMP_DIR"

# Clean previous extraction
rm -rf "$FW_TMP_DIR" "$TMP_DIR/rootfs"
mkdir -p "$FW_TMP_DIR"

# Extract UBI images using ubireader_extract_images
echo "Extracting UBI images from $FW_FILE to $FW_TMP_DIR..."
ubireader_extract_images -o "$FW_TMP_DIR" "$FW_FILE"

# Locate extracted rootfs UBIFS volume image
UBI_ROOTFS=""
for img in "$FW_TMP_DIR"/*/img-*_vol-ubi_rootfs.ubifs "$FW_TMP_DIR"/img-*_vol-ubi_rootfs.ubifs; do
	if [ -f "$img" ]; then
		UBI_ROOTFS="$img"
		break
	fi
done

if [ -z "$UBI_ROOTFS" ] || [ ! -f "$UBI_ROOTFS" ]; then
	echo "Error: Could not find img-*_vol-ubi_rootfs.ubifs in $FW_TMP_DIR" >&2
	exit 1
fi
echo "Found UBI rootfs volume: $UBI_ROOTFS"

# Locate and copy extracted kernel image to target subtarget directory
for kimg in "$FW_TMP_DIR"/*/img-*_vol-kernel.ubifs "$FW_TMP_DIR"/img-*_vol-kernel.ubifs; do
	if [ -f "$kimg" ]; then
		echo "Found kernel volume: $kimg, copying to target/linux/ipq53xx/$TARGET_MODEL/kernel..."
		mkdir -p "target/linux/ipq53xx/$TARGET_MODEL"
		cp -f "$kimg" "target/linux/ipq53xx/$TARGET_MODEL/kernel"
		break
	fi
done

# Extract filesystem using unsquashfs
EXTRACTED_ROOTFS="$TMP_DIR/rootfs"
rm -rf "$EXTRACTED_ROOTFS"
echo "Unpacking rootfs using unsquashfs to $EXTRACTED_ROOTFS..."
unsquashfs -f -d "$EXTRACTED_ROOTFS" "$UBI_ROOTFS" >/dev/null 2>&1 || true

# Verify successful rootfs extraction
if [ ! -d "$EXTRACTED_ROOTFS/etc" ] || [ ! -d "$EXTRACTED_ROOTFS/usr" ]; then
	echo "Error: Failed to extract rootfs or directory structure is invalid." >&2
	exit 1
fi

echo "Successfully extracted firmware rootfs to $EXTRACTED_ROOTFS"

# Verify hardware model from extracted rootfs
if [ -f "$EXTRACTED_ROOTFS/usr/share/xiaoqiang/xiaoqiang_version" ]; then
	HW_DETECT=$(awk '/option[ \t]+HARDWARE/ {print $3}' "$EXTRACTED_ROOTFS/usr/share/xiaoqiang/xiaoqiang_version" | tr -d "'\"\r\n" | tr '[:upper:]' '[:lower:]' || true)
	if [ -n "$HW_DETECT" ] && [ "$HW_DETECT" != "$TARGET_MODEL" ]; then
		echo "Notice: Detected hardware $HW_DETECT differs from requested $TARGET_MODEL. Updating target model to $HW_DETECT."
		TARGET_MODEL="$HW_DETECT"
		for kimg in "$FW_TMP_DIR"/*/img-*_vol-kernel.ubifs "$FW_TMP_DIR"/img-*_vol-kernel.ubifs; do
			if [ -f "$kimg" ]; then
				mkdir -p "target/linux/ipq53xx/$TARGET_MODEL"
				cp -f "$kimg" "target/linux/ipq53xx/$TARGET_MODEL/kernel"
				break
			fi
		done
	fi
fi

# Copy vendor_data files over extracted rootfs
if [ -d "vendor_data" ]; then
	echo "Copying vendor_data over extracted rootfs..."
	cp -a vendor_data/* "$EXTRACTED_ROOTFS/"
fi

# Extract kernel module dependencies directly from .ko binaries
KMOD_DEPS_JSON="$TMP_DIR/kmod_deps.json"
echo "Extracting kernel module dependencies from binaries to $KMOD_DEPS_JSON..."
python3 ./vendor_scripts/extract_kmod_deps.py "$EXTRACTED_ROOTFS" "$KMOD_DEPS_JSON"

# Feed management:
# For rd15: clean and recreate vendor_feed from scratch.
# For rd16: only create if absent, otherwise update files-rd16.
STATUS_FILE="$EXTRACTED_ROOTFS/usr/lib/opkg/status"
if [ ! -f "$STATUS_FILE" ]; then
	echo "Error: opkg status file not found at $STATUS_FILE" >&2
	exit 1
fi

if [ "$TARGET_MODEL" = "rd15" ]; then
	echo "Target model is rd15: cleaning existing $FEED_DIR to regenerate from scratch..."
	rm -rf "$FEED_DIR"
fi

if [ ! -d "$FEED_DIR" ]; then
	echo "Generating vendor feed in $FEED_DIR for $TARGET_MODEL..."
	python3 ./vendor_scripts/generate_feed.py "$STATUS_FILE" "$EXTRACTED_ROOTFS" "$FEED_DIR" "$ADD_VENDOR_PACKAGES" "$IGNORE_VENDOR_PACKAGES" "$KMOD_DEPS_JSON" "$REQUIRED_LIST" "$NATIVE_VENDOR_PACKAGES"
	echo "Vendor feed generation complete: $FEED_DIR"

	for pkg_dir in "$FEED_DIR"/*; do
		if [ -d "$pkg_dir" ]; then
			echo "Patching package $(basename "$pkg_dir")"
			python3 ./vendor_scripts/patch_package.py "$pkg_dir"
		fi
	done
else
	echo "Existing vendor feed detected. Updating subtarget-specific files for $TARGET_MODEL..."
	python3 ./vendor_scripts/generate_package.py --update \
		--rootfs "$EXTRACTED_ROOTFS" \
		--feed "$FEED_DIR" \
		--subtarget "$TARGET_MODEL"
	echo "Successfully updated subtarget files in $FEED_DIR for $TARGET_MODEL"
fi

# Configure feeds.conf to include vendor_feed and custom bypass/proxy feeds
FEEDS_CONF="feeds.conf"

if [ ! -f "$FEEDS_CONF" ]; then
	if [ -f "feeds.conf.default" ]; then
		cp "feeds.conf.default" "$FEEDS_CONF"
	else
		touch "$FEEDS_CONF"
	fi
fi
add_feed_entry() {
	local name="$1"
	local entry="$2"
	if ! grep -q "^[[:space:]]*src-[^[:space:]]*[[:space:]]\+$name[[:space:]]" "$FEEDS_CONF"; then
		echo "$entry" >> "$FEEDS_CONF"
		echo "Added $name to $FEEDS_CONF"
	else
		echo "$name is already present in $FEEDS_CONF"
	fi
}

add_feed_entry "vendor_feed" "src-link vendor_feed ../vendor_feed"
add_feed_entry "amneziawg" "src-git amneziawg https://github.com/RomikB/amneziawg-openwrt.git"
add_feed_entry "forkop" "src-git forkop https://github.com/ushan0v/forkop.git"
add_feed_entry "podkop" "src-git podkop https://github.com/itdoginfo/podkop.git"
add_feed_entry "ruantiblock" "src-git ruantiblock https://github.com/gSpotx2f/ruantiblock_openwrt.git"
add_feed_entry "zapret2" "src-git zapret2 https://github.com/remittor/zapret-openwrt.git;master"

# Clone and update standalone single-package addons (e.g. LuCI themes)
if [ -f "vendor_scripts/update_addons.sh" ]; then
	./vendor_scripts/update_addons.sh
fi
