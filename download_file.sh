#!/bin/sh
#
# Universal file downloader from Xiaomi Router BE3600 (RD15)
#
# Usage:
#   ./download_file.sh [HOST] <REMOTE_FILE> [LOCAL_DEST]
#   ./download_file.sh <REMOTE_FILE> [LOCAL_DEST]  (uses default host 192.168.11.46)
#
# Examples:
#   ./download_file.sh /tmp/dmesg_stock.log
#   ./download_file.sh 192.168.11.36 /tmp/device-tree.tar.gz ./device-tree.tar.gz
#   ./download_file.sh 192.168.11.36 /proc/cmdline ./cmdline.txt
#

DEFAULT_HOST="192.168.11.36"
USER="root"
PARAMS="-o HostKeyAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Parse arguments: supports both `[HOST] <SRC> [DST]` and `<SRC> [DST]`
case "$1" in
    *.*.*.*)
        HOST="$1"
        SRC="$2"
        DST="$3"
        ;;
    *)
        HOST="$DEFAULT_HOST"
        SRC="$1"
        DST="$2"
        ;;
esac

if [ -z "$SRC" ]; then
    echo "Usage: $0 [HOST] <REMOTE_FILE> [LOCAL_DEST]"
    echo "       $0 <REMOTE_FILE> [LOCAL_DEST]"
    echo ""
    echo "Example: $0 /tmp/dmesg_stock.log"
    echo "Example: $0 $DEFAULT_HOST /tmp/device-tree.tar.gz"
    exit 1
fi

if [ -z "$DST" ]; then
    DST="./$(basename "$SRC")"
fi

echo "Downloading from ${USER}@${HOST}:${SRC} to ${DST}..."

# Prompt for password if not provided via environment
if [ -z "$PASS" ]; then
    printf "Password (press Enter if none): "
    stty -echo 2>/dev/null || true
    read -r PASS
    stty echo 2>/dev/null || true
    echo ""
fi

# Download file or directory using scp
if [ -n "$PASS" ]; then
    sshpass -p "$PASS" scp $PARAMS -r "${USER}@${HOST}:${SRC}" "$DST"
    STATUS=$?
else
    scp $PARAMS -r "${USER}@${HOST}:${SRC}" "$DST"
    STATUS=$?
fi

if [ $STATUS -eq 0 ]; then
    if [ -e "$DST" ]; then
        SIZE=$(du -h "$DST" 2>/dev/null | cut -f1)
        echo "Successfully downloaded: ${DST} (${SIZE})"
    else
        echo "Successfully downloaded: ${DST}"
    fi
else
    echo "Download failed with error code $STATUS"
    exit $STATUS
fi
