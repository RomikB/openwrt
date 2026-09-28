#!/bin/sh
#
# Upload Factory UBI firmware image to Xiaomi Router BE3600 (RD15)
# Usage: ./upload_ubi_rd15.sh [HOST] [FILE|FLAVOR]
# Examples:
#   ./upload_ubi_rd15.sh                              # Interactive selection
#   ./upload_ubi_rd15.sh qsdk                         # QSDK native + RuAntiBlock
#   ./upload_ubi_rd15.sh qsdk-podkop                  # QSDK native + Podkop
#   ./upload_ubi_rd15.sh prebuild                     # Prebuild vendor + RuAntiBlock
#   ./upload_ubi_rd15.sh prebuild-podkop              # Prebuild vendor + Podkop
#   ./upload_ubi_rd15.sh 192.168.1.1 qsdk-podkop      # Specify IP and image flavor
#   ./upload_ubi_rd15.sh bin/.../image.ubi            # Specify explicit image path
#

BIN_DIR="bin/targets/ipq53xx/rd15"
DEFAULT_HOST="192.168.11.36"

HOST="$DEFAULT_HOST"
FILE=""

# Flavor shortcuts
QSDK_RU_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-qsdk-squashfs-factory.ubi"
QSDK_PODKOP_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-qsdk-podkop-squashfs-factory.ubi"
PREBUILD_RU_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-prebuild-squashfs-factory.ubi"
PREBUILD_PODKOP_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-prebuild-podkop-squashfs-factory.ubi"

resolve_flavor() {
    case "$1" in
        qsdk-podkop|podkop-qsdk)
            echo "$QSDK_PODKOP_IMG"
            ;;
        qsdk|qsdk-ru|ruantiblock-qsdk)
            echo "$QSDK_RU_IMG"
            ;;
        prebuild-podkop|podkop-prebuild)
            echo "$PREBUILD_PODKOP_IMG"
            ;;
        prebuild|prebuild-ru|ruantiblock-prebuild)
            echo "$PREBUILD_RU_IMG"
            ;;
        podkop)
            # Default podkop flavor prefers QSDK native
            echo "$QSDK_PODKOP_IMG"
            ;;
        ruantiblock)
            # Default ruantiblock flavor prefers QSDK native
            echo "$QSDK_RU_IMG"
            ;;
        *)
            echo ""
            ;;
    esac
}

get_image_label() {
    local fn="$1"
    case "$fn" in
        *qsdk-podkop*)
            echo "QSDK Native Kernel + Podkop / sing-box"
            ;;
        *qsdk*)
            echo "QSDK Native Kernel + RuAntiBlock / DoH [Main]"
            ;;
        *prebuild-podkop*)
            echo "Vendor Prebuild Kernel + Podkop / sing-box"
            ;;
        *prebuild*)
            echo "Vendor Prebuild Kernel + RuAntiBlock / DoH"
            ;;
        *)
            basename "$fn"
            ;;
    esac
}

# Parse command line arguments
for arg in "$@"; do
    case "$arg" in
        *.ubi)
            FILE="$arg"
            ;;
        qsdk*|prebuild*|podkop*|ruantiblock*)
            resolved=$(resolve_flavor "$arg")
            if [ -n "$resolved" ]; then
                FILE="$resolved"
            fi
            ;;
        [0-9]*.[0-9]*.[0-9]*.[0-9]*)
            HOST="$arg"
            ;;
        *)
            if [ -f "$arg" ]; then
                FILE="$arg"
            else
                HOST="$arg"
            fi
            ;;
    esac
done

# If no explicit file was passed, scan BIN_DIR
if [ -z "$FILE" ]; then
    # Collect all existing standard images in priority order
    FOUND_IMGS=""
    for img in "$QSDK_RU_IMG" "$QSDK_PODKOP_IMG" "$PREBUILD_RU_IMG" "$PREBUILD_PODKOP_IMG"; do
        if [ -f "$img" ]; then
            FOUND_IMGS="$FOUND_IMGS $img"
        fi
    done

    # Also check if there are any other .ubi images not in standard list
    for img in "$BIN_DIR"/*.ubi; do
        [ -f "$img" ] || continue
        case " $FOUND_IMGS " in
            *" $img "*) ;; # already included
            *) FOUND_IMGS="$FOUND_IMGS $img" ;;
        esac
    done

    # Trim leading space
    FOUND_IMGS=$(echo "$FOUND_IMGS" | sed 's/^ *//')

    COUNT=0
    for img in $FOUND_IMGS; do
        COUNT=$((COUNT + 1))
    done

    if [ "$COUNT" -eq 0 ]; then
        echo "Error: No .ubi firmware images found in $BIN_DIR."
        echo "Please build target/linux first (e.g. make target/linux/compile)."
        exit 1
    elif [ "$COUNT" -eq 1 ]; then
        FILE="$FOUND_IMGS"
        LABEL=$(get_image_label "$FILE")
        echo "Single firmware image found: $LABEL"
        echo "Selected: $FILE"
    else
        echo "=========================================================="
        echo " Multiple firmware images found in $BIN_DIR:"
        echo "=========================================================="
        IDX=1
        for img in $FOUND_IMGS; do
            LABEL=$(get_image_label "$img")
            FSIZE=$(ls -lh "$img" | awk '{print $5}')
            echo "  $IDX) $LABEL ($FSIZE)"
            echo "     -> $img"
            IDX=$((IDX + 1))
        done
        echo "=========================================================="

        while true; do
            printf "Select image to upload [1-%d, default: 1]: " "$COUNT"
            read -r CHOICE
            [ -z "$CHOICE" ] && CHOICE=1

            case "$CHOICE" in
                ''|*[!0-9]*)
                    echo "Invalid selection. Please enter a number between 1 and $COUNT."
                    ;;
                *)
                    if [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "$COUNT" ]; then
                        SEL_IDX=1
                        for img in $FOUND_IMGS; do
                            if [ "$SEL_IDX" -eq "$CHOICE" ]; then
                                FILE="$img"
                                break
                            fi
                            SEL_IDX=$((SEL_IDX + 1))
                        done
                        break
                    else
                        echo "Invalid selection. Please enter a number between 1 and $COUNT."
                    fi
                    ;;
            esac
        done
    fi
fi

if [ ! -f "$FILE" ]; then
    echo "Error: Firmware file '$FILE' not found."
    exit 1
fi

FILE_SIZE=$(ls -lh "$FILE" | awk '{print $5}')
echo ""
echo "Selected firmware image: $(get_image_label "$FILE")"
echo "File: $FILE ($FILE_SIZE)"
echo "Target host: $HOST"
echo "Uploading to ${HOST}:/tmp/root.ubi..."
echo ""

exec ./upload_file.sh "$HOST" "$FILE" "/tmp/root.ubi"
