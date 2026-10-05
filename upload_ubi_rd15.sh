#!/bin/sh
#
# Upload Factory UBI firmware image to Xiaomi Router BE3600 (RD15)
# Usage: ./upload_ubi_rd15.sh [HOST] [FILE|FLAVOR]
# Examples:
#   ./upload_ubi_rd15.sh                              # Interactive selection
#   ./upload_ubi_rd15.sh prebuild                     # Prebuild vendor Base
#   ./upload_ubi_rd15.sh qsdk                         # QSDK native Base [Main]
#   ./upload_ubi_rd15.sh prebuild-ru                  # Prebuild vendor + RuAntiBlock
#   ./upload_ubi_rd15.sh qsdk-ru                      # QSDK native + RuAntiBlock
#   ./upload_ubi_rd15.sh prebuild-podkop              # Prebuild vendor + Podkop
#   ./upload_ubi_rd15.sh qsdk-podkop                  # QSDK native + Podkop
#   ./upload_ubi_rd15.sh prebuild-dev                 # Prebuild vendor Dev
#   ./upload_ubi_rd15.sh qsdk-dev                     # QSDK native Dev
#   ./upload_ubi_rd15.sh 192.168.1.1 qsdk             # Specify IP and image flavor
#   ./upload_ubi_rd15.sh bin/.../image.ubi            # Specify explicit image path
#

BIN_DIR="bin/targets/ipq53xx/rd15"
DEFAULT_HOST="192.168.11.36"

HOST="$DEFAULT_HOST"
FILE=""

# Standard image definitions
PREBUILD_BASE_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-prebuild-squashfs-factory.ubi"
QSDK_BASE_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-qsdk-squashfs-factory.ubi"
PREBUILD_RU_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-prebuild-ruantiblock-squashfs-factory.ubi"
QSDK_RU_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-qsdk-ruantiblock-squashfs-factory.ubi"
PREBUILD_PODKOP_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-prebuild-podkop-squashfs-factory.ubi"
QSDK_PODKOP_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-qsdk-podkop-squashfs-factory.ubi"
PREBUILD_DEV_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-prebuild-dev-squashfs-factory.ubi"
QSDK_DEV_IMG="$BIN_DIR/openwrt-ipq53xx-rd15-xiaomi-rd15-qsdk-dev-squashfs-factory.ubi"

resolve_flavor() {
    case "$1" in
        # Base flavors
        prebuild|prebuild-base|base-prebuild)
            echo "$PREBUILD_BASE_IMG"
            ;;
        qsdk|qsdk-base|base-qsdk|base)
            echo "$QSDK_BASE_IMG"
            ;;
        # RuAntiBlock flavors
        prebuild-ru|prebuild-ruantiblock|ruantiblock-prebuild|ru-prebuild)
            echo "$PREBUILD_RU_IMG"
            ;;
        qsdk-ru|qsdk-ruantiblock|ruantiblock-qsdk|ru-qsdk|ru|ruantiblock)
            echo "$QSDK_RU_IMG"
            ;;
        # Podkop flavors
        prebuild-podkop|podkop-prebuild)
            echo "$PREBUILD_PODKOP_IMG"
            ;;
        qsdk-podkop|podkop-qsdk|podkop)
            echo "$QSDK_PODKOP_IMG"
            ;;
        # Dev flavors
        prebuild-dev|dev-prebuild)
            echo "$PREBUILD_DEV_IMG"
            ;;
        qsdk-dev|dev-qsdk|dev)
            echo "$QSDK_DEV_IMG"
            ;;
        *)
            echo ""
            ;;
    esac
}

get_image_label() {
    local bname; bname="$(basename "$1")"
    case "$bname" in
        # RuAntiBlock profiles
        *prebuild-ruantiblock*|*prebuild-ru*)
            echo "Vendor Prebuild Kernel + RuAntiBlock / DoH"
            ;;
        *qsdk-ruantiblock*|*qsdk-ru*)
            echo "QSDK Native Kernel + RuAntiBlock / DoH"
            ;;
        # Podkop profiles
        *prebuild-podkop*)
            echo "Vendor Prebuild Kernel + Podkop / sing-box"
            ;;
        *qsdk-podkop*)
            echo "QSDK Native Kernel + Podkop / sing-box"
            ;;
        # Dev profiles
        *prebuild-dev*)
            echo "Vendor Prebuild Kernel + Dev"
            ;;
        *qsdk-dev*)
            echo "QSDK Native Kernel + Dev"
            ;;
        # Base profiles
        *xiaomi-rd15-prebuild-squashfs*|*-prebuild-squashfs*|*prebuild-base*|*-prebuild-factory.ubi)
            echo "Vendor Prebuild Kernel + Base"
            ;;
        *xiaomi-rd15-qsdk-squashfs*|*-qsdk-squashfs*|*qsdk-base*|*-qsdk-factory.ubi)
            echo "QSDK Native Kernel + Base [Main]"
            ;;
        # Other images
        *prebuild*)
            echo "Vendor Prebuild Kernel + Other"
            ;;
        *qsdk*)
            echo "QSDK Native Kernel + Other"
            ;;
        *)
            echo "Unknown Kernel + Other"
            ;;
    esac
}

# Parse command line arguments
for arg in "$@"; do
    case "$arg" in
        *.ubi)
            FILE="$arg"
            ;;
        base*|qsdk*|prebuild*|podkop*|ruantiblock*|ru*|dev*)
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
    # Collect standard images in order:
    # 1. Base (prebuilt -> qsdk)
    # 2. RuAntiBlock (prebuilt -> qsdk)
    # 3. Podkop (prebuilt -> qsdk)
    # 4. Dev (prebuilt -> qsdk)
    FOUND_IMGS=""
    for img in \
        "$PREBUILD_BASE_IMG" "$QSDK_BASE_IMG" \
        "$PREBUILD_RU_IMG"   "$QSDK_RU_IMG" \
        "$PREBUILD_PODKOP_IMG" "$QSDK_PODKOP_IMG" \
        "$PREBUILD_DEV_IMG"  "$QSDK_DEV_IMG"; do
        if [ -f "$img" ]; then
            FOUND_IMGS="$FOUND_IMGS $img"
        fi
    done

    # 5. Other .ubi images at the end (sorted: prebuilt first, then qsdk, then others)
    OTHER_PREBUILD=""
    OTHER_QSDK=""
    OTHER_REST=""
    for img in "$BIN_DIR"/*.ubi; do
        [ -f "$img" ] || continue
        case " $FOUND_IMGS " in
            *" $img "*) continue ;; # already included
        esac
        case "$(basename "$img")" in
            *prebuild*)
                OTHER_PREBUILD="$OTHER_PREBUILD $img"
                ;;
            *qsdk*)
                OTHER_QSDK="$OTHER_QSDK $img"
                ;;
            *)
                OTHER_REST="$OTHER_REST $img"
                ;;
        esac
    done

    for img in $OTHER_PREBUILD $OTHER_QSDK $OTHER_REST; do
        FOUND_IMGS="$FOUND_IMGS $img"
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
