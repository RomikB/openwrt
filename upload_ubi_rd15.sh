#!/bin/bash
#
# Upload Factory UBI firmware image to Xiaomi Router BE3600 (RD15)
# Usage: ./upload_ubi_rd15.sh [HOST]
#

HOST="${1:-192.168.31.1}"
FILE="bin/targets/ipq53xx/rd15/openwrt-ipq53xx-rd15-xiaomi-rd15-prebuild-squashfs-factory.ubi"

# Auto-detect if exact file path isn't found
if [ ! -f "$FILE" ]; then
    FOUND=$(ls -t bin/targets/ipq53xx/rd15/*factory.ubi 2>/dev/null | head -n 1)
    if [ -n "$FOUND" ] && [ -f "$FOUND" ]; then
        FILE="$FOUND"
    fi
fi

# Check if the target image file exists before proceeding
if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found. Please build the target image first."
    exit 1
fi

./upload_file.sh "$HOST" "$FILE" "/tmp/root.ubi"
