#!/bin/sh
#
# Upload Factory UBI firmware image to Xiaomi Router BE3600 (RD15)
# Usage: ./upload_ubi_rd15.sh [HOST] [FILE]
#

BIN_DIR="bin/targets/ipq53xx/rd15"
PREBUILD_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-prebuild-squashfs-factory.ubi"
QSDK_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-qsdk-squashfs-factory.ubi"

HOST="192.168.11.36"
FILE=""

# Parse arguments
if [ -n "$1" ]; then
    case "$1" in
        *.ubi)
            FILE="$1"
            if [ -n "$2" ]; then
                HOST="$2"
            fi
            ;;
        *)
            HOST="$1"
            if [ -n "$2" ]; then
                FILE="$2"
            fi
            ;;
    esac
fi

# Auto-detect or prompt if no explicit file was passed
if [ -z "$FILE" ]; then
    HAVE_QSDK=0
    HAVE_PREBUILD=0

    if [ -f "$QSDK_IMG" ]; then
        HAVE_QSDK=1
    fi

    if [ -f "$PREBUILD_IMG" ]; then
        HAVE_PREBUILD=1
    fi

    if [ "$HAVE_PREBUILD" -eq 1 ] && [ "$HAVE_QSDK" -eq 0 ]; then
        FILE="$PREBUILD_IMG"
        echo "Selected prebuild vendor image: $FILE"
    elif [ "$HAVE_PREBUILD" -eq 0 ] && [ "$HAVE_QSDK" -eq 1 ]; then
        FILE="$QSDK_IMG"
        echo "Selected native QSDK image: $FILE"
    elif [ "$HAVE_PREBUILD" -eq 1 ] && [ "$HAVE_QSDK" -eq 1 ]; then
        echo "Multiple firmware images found in $BIN_DIR:"
        echo "  1) Prebuild vendor kernel ($PREBUILD_IMG)"
        echo "  2) QSDK native kernel ($QSDK_IMG)"
        while true; do
            printf "Select image to upload [1/2]: "
            read -r CHOICE
            case "$CHOICE" in
                1)
                    FILE="$PREBUILD_IMG"
                    break
                    ;;
                2)
                    FILE="$QSDK_IMG"
                    break
                    ;;
                *)
                    echo "Invalid selection. Please enter 1 or 2."
                    ;;
            esac
        done
    else
        echo "Error: No .ubi firmware images found in $BIN_DIR."
        echo "Please build target/linux first."
        exit 1
    fi
fi

if [ ! -f "$FILE" ]; then
    echo "Error: Firmware file '$FILE' not found."
    exit 1
fi

echo "Uploading '$FILE' to ${HOST}:/tmp/root.ubi..."
exec ./upload_file.sh "$HOST" "$FILE" "/tmp/root.ubi"
