#!/bin/sh
set -e

# Parse arguments and determine firmware file path
FW_FILE=""
if [ -n "$1" ]; then
	FW_FILE="$1"
else
	for f in miwifi_rd15_firmware_*.bin; do
		if [ -f "$f" ]; then
			FW_FILE="$f"
			break
		fi
	done
fi

# Validate firmware file existence
if [ -z "$FW_FILE" ] || [ ! -f "$FW_FILE" ]; then
	echo "Error: Firmware file not found." >&2
	echo "Usage: $0 [firmware_file.bin]" >&2
	exit 1
fi
echo "Using firmware image: $FW_FILE"

PACKAGES_LIST="vendor_scripts/packages.list"
REQUIRED_LIST="vendor_scripts/required.list"

if [ ! -f "$PACKAGES_LIST" ]; then
	echo "Error: Packages list file not found at $PACKAGES_LIST" >&2
	exit 1
fi

if [ ! -f "$REQUIRED_LIST" ]; then
	echo "Error: Required packages list file not found at $REQUIRED_LIST" >&2
	exit 1
fi

ADD_VENDOR_PACKAGES=$(grep -v '^[[:space:]]*#' "$PACKAGES_LIST" | grep -v '^[[:space:]]*$' | tr '\n' ' ')
IGNORE_VENDOR_PACKAGES="${IGNORE_VENDOR_PACKAGES:-kernel ubus ubusd ubox fstools ubi-utils procd jshn netifd jsonfilter usign openwrt-keyring fwtool base-files}"

# Validate that all required packages from required.list are present
while IFS= read -r req_pkg || [ -n "$req_pkg" ]; do
	req_pkg=$(echo "$req_pkg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
	[ -z "$req_pkg" ] && continue
	case "$req_pkg" in \#*) continue ;; esac
	found=0
	for p in $ADD_VENDOR_PACKAGES; do
		if [ "$p" = "$req_pkg" ]; then
			found=1
			break
		fi
	done
	if [ "$found" -eq 0 ]; then
		echo "Error: Required package '$req_pkg' from $REQUIRED_LIST is missing in $PACKAGES_LIST!" >&2
		exit 1
	fi
done < "$REQUIRED_LIST"

# Prepare temporary and feed directories
TMP_DIR="./tmp"
FEED_DIR="./vendor_feed"
mkdir -p "$TMP_DIR"
rm -rf "$FEED_DIR"
mkdir -p "$FEED_DIR"

# Extract UBI images using ubireader_extract_images
echo "Extracting UBI images from $FW_FILE to $TMP_DIR..."
ubireader_extract_images -o "$TMP_DIR" "$FW_FILE"

# Locate extracted rootfs UBIFS volume image
UBI_ROOTFS=""
for img in "$TMP_DIR"/*/img-*_vol-ubi_rootfs.ubifs "$TMP_DIR"/img-*_vol-ubi_rootfs.ubifs; do
	if [ -f "$img" ]; then
		UBI_ROOTFS="$img"
		break
	fi
done

if [ -z "$UBI_ROOTFS" ] || [ ! -f "$UBI_ROOTFS" ]; then
	echo "Error: Could not find img-*_vol-ubi_rootfs.ubifs in $TMP_DIR" >&2
	exit 1
fi
echo "Found UBI rootfs volume: $UBI_ROOTFS"

# Locate and copy extracted kernel image
for kimg in "$TMP_DIR"/*/img-*_vol-kernel.ubifs "$TMP_DIR"/img-*_vol-kernel.ubifs; do
	if [ -f "$kimg" ]; then
		echo "Found kernel volume: $kimg, copying to target/linux/ipq53xx/rd15/kernel..."
		mkdir -p target/linux/ipq53xx/rd15
		cp -f "$kimg" target/linux/ipq53xx/rd15/kernel
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

# Copy vendor_data files over extracted rootfs
if [ -d "vendor_data" ]; then
	echo "Copying vendor_data over extracted rootfs..."
	cp -a vendor_data/* "$EXTRACTED_ROOTFS/"
fi

# Resolve package list and generate vendor feed using external python script
STATUS_FILE="$EXTRACTED_ROOTFS/usr/lib/opkg/status"
if [ ! -f "$STATUS_FILE" ]; then
	echo "Error: opkg status file not found at $STATUS_FILE" >&2
	exit 1
fi

echo "Generating vendor feed in $FEED_DIR..."
python3 ./vendor_scripts/generate_feed.py "$STATUS_FILE" "$EXTRACTED_ROOTFS" "$FEED_DIR" "$ADD_VENDOR_PACKAGES" "$IGNORE_VENDOR_PACKAGES"
echo "Vendor feed generation complete: $FEED_DIR"

# Run patch script for each generated package
for pkg_dir in "$FEED_DIR"/*; do
    if [ -d "$pkg_dir" ]; then
        echo "Patching package $(basename "$pkg_dir")"
        python3 ./vendor_scripts/patch_package.py "$pkg_dir"
    fi
done

# Configure feeds.conf to include vendor_feed
FEEDS_CONF="feeds.conf"
FEED_PATH="../vendor_feed"
FEED_ENTRY="src-link vendor_feed $FEED_PATH"

if [ ! -f "$FEEDS_CONF" ]; then
	if [ -f "feeds.conf.default" ]; then
		cp "feeds.conf.default" "$FEEDS_CONF"
	else
		touch "$FEEDS_CONF"
	fi
fi

if ! grep -q "vendor_feed" "$FEEDS_CONF"; then
	echo "$FEED_ENTRY" >> "$FEEDS_CONF"
	echo "Added vendor_feed to $FEEDS_CONF"
else
	echo "vendor_feed is already present in $FEEDS_CONF"
fi
