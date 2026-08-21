#!/bin/bash
#
# Universal file uploader for Xiaomi Router BE3600 (RD15)
# Usage: ./upload_file.sh [HOST] <LOCAL_FILE> [REMOTE_DEST]
# Example: ./upload_file.sh 192.168.11.46 script.sh /tmp/script.sh
# Example: ./upload_file.sh 192.168.11.46 factory.ubi /tmp/root.ubi
#

HOST="${1:-192.168.11.46}"
SRC="$2"

if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
    echo "Usage: $0 [HOST] <LOCAL_FILE> [REMOTE_DEST]"
    echo "Error: File '$SRC' not found."
    exit 1
fi

DST="${3:-/tmp/$(basename "$SRC")}"
USER="root"
PARAMS="-o HostKeyAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

echo "Uploading: $SRC ($(du -h "$SRC" | cut -f1)) to ${USER}@${HOST}:${DST}"
read -s -p "Password: " PASS
echo

sshpass -p "$PASS" scp $PARAMS "$SRC" "${USER}@${HOST}:${DST}"
STATUS=$?

if [ $STATUS -eq 0 ]; then
    if [[ "$SRC" == *.sh ]] || file "$SRC" 2>/dev/null | grep -q "ELF"; then
        sshpass -p "$PASS" ssh $PARAMS "${USER}@${HOST}" "chmod +x '${DST}'" 2>/dev/null || true
    fi
    echo "Successfully uploaded: ${DST}"
else
    echo "Upload failed with error code $STATUS"
    exit $STATUS
fi
