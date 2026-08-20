#!/bin/bash

HOST="${1:-192.168.11.36}"
USER="root"
# Compatible with both legacy and modern OpenSSH versions
PARAMS="-o HostKeyAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
FILE="bin/targets/ipq53xx/rd15/openwrt-ipq53xx-rd15-xiaomi-rd15-prebuild-squashfs-factory.ubi"
REMOTE_DIR="/tmp"

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

echo "Uploading: $FILE ($(du -h "$FILE" | cut -f1)) to ${USER}@${HOST}:${REMOTE_DIR}/root.ubi"

read -s -p "Password: " PASS
echo

# Upload the file via sftp
sshpass -p "$PASS" sftp $PARAMS "${USER}@${HOST}" <<EOF
put "$FILE" "$REMOTE_DIR/root.ubi"
quit
EOF

if [ $? -eq 0 ]; then
    echo "Successfully uploaded to ${REMOTE_DIR}/root.ubi"
fi

