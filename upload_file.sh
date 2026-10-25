#!/bin/sh
#
# Universal file uploader for Xiaomi Router BE3600 (RD15)
# Usage: ./upload_file.sh [HOST] <LOCAL_FILE> [REMOTE_DEST]
# Example: ./upload_file.sh 192.168.11.36 script.sh /tmp/script.sh
# Example: ./upload_file.sh 192.168.11.36 factory.ubi /tmp/root.ubi
#

DEFAULT_HOST="192.168.11.36"

# Parse arguments: supports both `[HOST] <SRC> [DST]` and `<SRC> [DST]`
if [ -f "$1" ]; then
    HOST="$DEFAULT_HOST"
    SRC="$1"
    DST="$2"
else
    HOST="${1:-$DEFAULT_HOST}"
    SRC="$2"
    DST="$3"
fi

if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
    echo "Usage: $0 [HOST] <LOCAL_FILE> [REMOTE_DEST]"
    echo "Error: File '$SRC' not found."
    exit 1
fi

if [ -z "$DST" ]; then
    DST="/tmp/$(basename "$SRC")"
fi

USER="root"
PARAMS="-o HostKeyAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

FILE_SIZE=$(du -h "$SRC" 2>/dev/null | cut -f1)
echo "Uploading: $SRC ($FILE_SIZE) to ${USER}@${HOST}:${DST}"

# Prompt for password if not set in environment
if [ -z "$PASS" ]; then
    printf "Password (press Enter if none): "
    stty -echo 2>/dev/null || true
    read -r PASS
    stty echo 2>/dev/null || true
    echo ""
fi

# Transfer file
if [ -n "$PASS" ]; then
    sshpass -p "$PASS" scp $PARAMS "$SRC" "${USER}@${HOST}:${DST}"
    STATUS=$?
else
    scp $PARAMS "$SRC" "${USER}@${HOST}:${DST}"
    STATUS=$?
fi

if [ $STATUS -eq 0 ]; then
    # Make scripts and binaries executable automatically
    case "$SRC" in
        *.sh)
            if [ -n "$PASS" ]; then
                sshpass -p "$PASS" ssh $PARAMS "${USER}@${HOST}" "chmod +x '${DST}'" 2>/dev/null || true
            else
                ssh $PARAMS "${USER}@${HOST}" "chmod +x '${DST}'" 2>/dev/null || true
            fi
            ;;
        *)
            if file "$SRC" 2>/dev/null | grep -q "ELF"; then
                if [ -n "$PASS" ]; then
                    sshpass -p "$PASS" ssh $PARAMS "${USER}@${HOST}" "chmod +x '${DST}'" 2>/dev/null || true
                else
                    ssh $PARAMS "${USER}@${HOST}" "chmod +x '${DST}'" 2>/dev/null || true
                fi
            fi
            ;;
    esac
    echo "Successfully uploaded: ${DST}"
else
    echo "Upload failed with error code $STATUS"
    exit $STATUS
fi
