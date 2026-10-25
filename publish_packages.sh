#!/bin/bash
# ==============================================================================
# Script: publish_packages.sh
# Purpose: Collect custom APK packages and kernel modules, generate signed APK
#          repository for GitHub Pages (releases/25.12-SNAPSHOT/targets/ipq53xx/ipq53xx_32/packages)
#          using OpenWrt 25 ECDSA prime256v1 keys.
# ==============================================================================

set -euo pipefail

# 1. Parameter check
if [ $# -lt 1 ]; then
    echo "Usage: $0 <path_to_github_pages_repo> [subtarget]"
    echo "Example: $0 /home/romikb/romikb.github.io ipq53xx_32"
    exit 1
fi

GHPAGES_ROOT="$1"
SUBTARGET="${2:-ipq53xx_32}"
TOPDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REL_PATH="releases/25.12-SNAPSHOT/targets/ipq53xx/${SUBTARGET}/packages"
DEST_DIR="${GHPAGES_ROOT}/${REL_PATH}"

ARCH_NAME="arm_cortex-a7_neon-vfpv4"
TARGET_PKG_DIR="${TOPDIR}/bin/targets/ipq53xx/${SUBTARGET}/packages"
FEEDS_DIR="${TOPDIR}/bin/packages/${ARCH_NAME}"

# OpenWrt 25 APK keys (ECDSA prime256v1 PEM format)
KEY_APK_SEC="${BUILD_KEY_APK_SEC:-${TOPDIR}/private-key.pem}"
KEY_APK_PUB="${BUILD_KEY_APK_PUB:-${TOPDIR}/public-key.pem}"
APK_HOST_BIN="${TOPDIR}/staging_dir/host/bin/apk"
INDEX_JSON_SCRIPT="${TOPDIR}/scripts/make-index-json.py"

# Helper function to identify proprietary vendor packages
is_vendor_package() {
    local pkg_path="$1"
    local filename
    filename="$(basename "${pkg_path}")"

    # Match packages with -vendor in name (e.g. qca-firmware-vendor-rd15-*, libc-vendor-*)
    case "${filename}" in
        *-vendor*|*-vendor_*)
            return 0
            ;;
    esac

    # Match packages present in vendor_feed directory
    if [ -d "${TOPDIR}/vendor_feed" ]; then
        for vdir in "${TOPDIR}/vendor_feed"/*; do
            [ -d "${vdir}" ] || continue
            local vname="$(basename "${vdir}")"
            if [[ "${filename}" == "${vname}"-* ]] || [[ "${filename}" == "${vname}"_* ]]; then
                return 0
            fi
        done
    fi

    return 1
}

# 2. Prerequisites validation
if [ ! -f "${KEY_APK_SEC}" ]; then
    echo "Error: APK private key '${KEY_APK_SEC}' not found!" >&2
    echo "Generate it or run a build first: openssl ecparam -name prime256v1 -genkey -noout -out ${KEY_APK_SEC}" >&2
    exit 1
fi

if [ ! -f "${KEY_APK_PUB}" ]; then
    echo "Error: APK public key '${KEY_APK_PUB}' not found!" >&2
    echo "Generate it via: openssl ec -in ${KEY_APK_SEC} -pubout > ${KEY_APK_PUB}" >&2
    exit 1
fi

if [ -x "${APK_HOST_BIN}" ]; then
    APK="${APK_HOST_BIN}"
elif command -v apk >/dev/null 2>&1; then
    APK="apk"
else
    echo "Error: 'apk' host utility not found in staging_dir/host/bin or PATH!" >&2
    exit 1
fi

echo "=== Preparing GitHub Pages package repository ==="
echo "Subtarget:   ${SUBTARGET}"
echo "Source:      ${TOPDIR}"
echo "Destination: ${DEST_DIR}"
echo "Keys:        ${KEY_APK_SEC} / ${KEY_APK_PUB}"

# 3. Clean old packages in destination directory
echo "Cleaning old packages and indices in destination..."
rm -rf "${DEST_DIR}"
mkdir -p "${DEST_DIR}"

# 4. Copy target-specific packages (kmod-*, custom drivers, utilities)
copied_count=0

if [ -d "${TARGET_PKG_DIR}" ]; then
    echo "Copying target packages from: ${TARGET_PKG_DIR}"
    for pkg in "${TARGET_PKG_DIR}"/*.apk; do
        [ -e "${pkg}" ] || continue
        if is_vendor_package "${pkg}"; then
            echo "Skipping nonshared vendor package: $(basename "${pkg}")"
            continue
        fi
        cp "${pkg}" "${DEST_DIR}/"
        copied_count=$((copied_count + 1))
    done
else
    echo "Warning: Target packages directory '${TARGET_PKG_DIR}' does not exist!"
fi

# 5. Copy custom feeds, excluding standard upstream feeds and proprietary vendor_feed
if [ -d "${FEEDS_DIR}" ]; then
    for feed_path in "${FEEDS_DIR}"/*; do
        [ -d "${feed_path}" ] || continue
        feed_name="$(basename "${feed_path}")"

        # Exclude standard upstream feeds and proprietary vendor_feed
        case "${feed_name}" in
            base|luci|packages|routing|telephony|video|vendor_feed)
                echo "Skipping excluded feed: ${feed_name}"
                continue
                ;;
            *)
                echo "Copying custom feed packages from: ${feed_name}"
                for pkg in "${feed_path}"/*.apk; do
                    [ -e "${pkg}" ] || continue
                    cp "${pkg}" "${DEST_DIR}/"
                    copied_count=$((copied_count + 1))
                done
                ;;
        esac
    done
fi

echo "Total .apk packages copied: ${copied_count}"

if [ "${copied_count}" -eq 0 ]; then
    echo "Error: No packages found to index! Run build first." >&2
    exit 1
fi

# 6. Generate APK repository index & sign with ECDSA key
cd "${DEST_DIR}"

echo "Generating signed APK repository index (packages.adb)..."
"${APK}" mkndx \
    --root "${TOPDIR}" \
    --keys-dir "${TOPDIR}" \
    --allow-untrusted \
    --sign "${KEY_APK_SEC}" \
    --output packages.adb \
    *.apk

echo "Verifying APK repository index signature..."
if "${APK}" verify --keys-dir "${TOPDIR}" packages.adb >/dev/null 2>&1; then
    echo "==> Signature verification: SUCCESS (OK)"
else
    echo "==> Signature verification: FAILED!" >&2
    exit 1
fi

# Generate index.json if helper script is available
if [ -f "${INDEX_JSON_SCRIPT}" ] && command -v python3 >/dev/null 2>&1; then
    echo "Generating index.json..."
    "${APK}" adbdump --format json packages.adb | \
        python3 "${INDEX_JSON_SCRIPT}" -f apk -a "${ARCH_NAME}" - > index.json
fi

# Copy public key to repository root so clients can install it into /etc/apk/keys/
echo "Publishing public key: public-key.pem"
cp "${KEY_APK_PUB}" "${DEST_DIR}/public-key.pem"

# Generate sha256 checksums
echo "Generating sha256sums..."
find . -maxdepth 1 -type f -not -name 'sha256sums' -printf "%P\n" | sort | \
    xargs -r sha256sum > sha256sums

echo ""
echo "=== Repository successfully published to: ==="
echo "${DEST_DIR}"
echo ""
echo "Files created:"
ls -lh packages.adb public-key.pem index.json sha256sums
