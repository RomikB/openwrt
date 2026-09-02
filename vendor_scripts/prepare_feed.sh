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
mkdir -p "$TMP_DIR"

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

# Extract kernel module dependencies directly from .ko binaries
KMOD_DEPS_JSON="$TMP_DIR/kmod_deps.json"
echo "Extracting kernel module dependencies from binaries to $KMOD_DEPS_JSON..."
python3 ./vendor_scripts/extract_kmod_deps.py "$EXTRACTED_ROOTFS" "$KMOD_DEPS_JSON"

# Resolve package list, validate required dependencies, and generate vendor feed
STATUS_FILE="$EXTRACTED_ROOTFS/usr/lib/opkg/status"
if [ ! -f "$STATUS_FILE" ]; then
	echo "Error: opkg status file not found at $STATUS_FILE" >&2
	exit 1
fi

echo "Resolving dependencies and generating vendor feed in $FEED_DIR..."
python3 ./vendor_scripts/generate_feed.py "$STATUS_FILE" "$EXTRACTED_ROOTFS" "$FEED_DIR" "$ADD_VENDOR_PACKAGES" "$IGNORE_VENDOR_PACKAGES" "$KMOD_DEPS_JSON" "$REQUIRED_LIST" "$NATIVE_VENDOR_PACKAGES"
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
