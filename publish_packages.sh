#!/bin/bash
# ==============================================================================
# Script: publish_packages.sh
# Purpose: Collect custom packages and kernel modules, generate signed opkg
#          repository for GitHub Pages (releases/24.10-SNAPSHOT/targets/ipq53xx/rd15/packages).
# ==============================================================================

set -euo pipefail

# 1. Parameter check
if [ $# -lt 1 ]; then
    echo "Usage: $0 <path_to_github_pages_repo>"
    echo "Example: $0 /home/romikb/romikb.github.io"
    exit 1
fi

GHPAGES_ROOT="$1"
TOPDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REL_PATH="releases/24.10-SNAPSHOT/targets/ipq53xx/rd15/packages"
DEST_DIR="${GHPAGES_ROOT}/${REL_PATH}"

KEY_BUILD="${TOPDIR}/key-build"
KEY_BUILD_PUB="${TOPDIR}/key-build.pub"
USIGN_BIN="${TOPDIR}/staging_dir/host/bin/usign"
MKHASH_BIN="${TOPDIR}/staging_dir/host/bin/mkhash"
INDEX_SCRIPT="${TOPDIR}/scripts/ipkg-make-index.sh"

ARCH_NAME="arm_cortex-a7_neon-vfpv4"

# 2. Prerequisites validation
if [ ! -f "${KEY_BUILD}" ]; then
    echo "Error: Private build key '${KEY_BUILD}' not found!" >&2
    exit 1
fi

if [ ! -f "${KEY_BUILD_PUB}" ]; then
    echo "Error: Public build key '${KEY_BUILD_PUB}' not found!" >&2
    exit 1
fi

if [ -x "${USIGN_BIN}" ]; then
    USIGN="${USIGN_BIN}"
elif command -v usign >/dev/null 2>&1; then
    USIGN="usign"
else
    echo "Error: 'usign' utility not found in staging_dir or PATH!" >&2
    exit 1
fi

if [ -x "${MKHASH_BIN}" ]; then
    export MKHASH="${MKHASH_BIN}"
elif command -v mkhash >/dev/null 2>&1; then
    export MKHASH="mkhash"
else
    echo "Error: 'mkhash' utility not found in staging_dir or PATH!" >&2
    exit 1
fi

if [ ! -f "${INDEX_SCRIPT}" ]; then
    echo "Error: Index generator '${INDEX_SCRIPT}' not found!" >&2
    exit 1
fi

echo "=== Preparing GitHub Pages package repository ==="
echo "Source:      ${TOPDIR}"
echo "Destination: ${DEST_DIR}"

# 3. Clean old packages in destination directory
echo "Cleaning old packages and indices in destination..."
rm -rf "${DEST_DIR}"
mkdir -p "${DEST_DIR}"

# 4. Copy target-specific packages (kmod-*, rd15-dev-mode, etc.)
TARGET_PKG_DIR="${TOPDIR}/bin/targets/ipq53xx/rd15/packages"
copied_count=0

if [ -d "${TARGET_PKG_DIR}" ]; then
    echo "Copying target packages from: ${TARGET_PKG_DIR}"
    for ipk in "${TARGET_PKG_DIR}"/*.ipk; do
        [ -e "${ipk}" ] || continue
        cp "${ipk}" "${DEST_DIR}/"
        copied_count=$((copied_count + 1))
    done
else
    echo "Warning: Target packages directory '${TARGET_PKG_DIR}' does not exist!"
fi

# 5. Copy custom feeds, excluding standard upstream feeds and vendor_feed
FEEDS_DIR="${TOPDIR}/bin/packages/${ARCH_NAME}"
if [ -d "${FEEDS_DIR}" ]; then
    for feed_path in "${FEEDS_DIR}"/*; do
        [ -d "${feed_path}" ] || continue
        feed_name="$(basename "${feed_path}")"

        # Exclude standard upstream feeds and proprietary vendor_feed
        case "${feed_name}" in
            base|luci|packages|routing|telephony|vendor_feed)
                echo "Skipping excluded feed: ${feed_name}"
                continue
                ;;
            *)
                echo "Copying custom feed packages from: ${feed_name}"
                for ipk in "${feed_path}"/*.ipk; do
                    [ -e "${ipk}" ] || continue
                    cp "${ipk}" "${DEST_DIR}/"
                    copied_count=$((copied_count + 1))
                done
                ;;
        esac
    done
fi

echo "Total .ipk packages copied: ${copied_count}"

if [ "${copied_count}" -eq 0 ]; then
    echo "Error: No packages found to index! Run build first." >&2
    exit 1
fi

# 6. Generate repository index
echo "Generating package index (Packages)..."
cd "${DEST_DIR}"

"${INDEX_SCRIPT}" . 2>&1 > Packages.manifest
grep -vE '^(Maintainer|LicenseFiles|Source|SourceName|Require|SourceDateEpoch)' Packages.manifest > Packages

# Workaround usign SHA-512 padding issue (matching OpenWrt package/Makefile)
case "$(((64 + $(stat -L -c%s Packages)) % 128))" in
    110|111)
        echo "Applying usign SHA-512 bug padding workaround..."
        { echo ""; echo ""; } >> Packages
        ;;
esac

# Compressed index
gzip -9nc Packages > Packages.gz

# 7. Sign package index with usign
echo "Signing package index with local build key..."
"${USIGN}" -S -m Packages -s "${KEY_BUILD}"

# 8. Verify generated signature
echo "Verifying signature..."
if "${USIGN}" -V -m Packages -p "${KEY_BUILD_PUB}" >/dev/null 2>&1; then
    echo "==> Signature verification: SUCCESS (OK)"
else
    echo "==> Signature verification: FAILED!" >&2
    exit 1
fi

echo ""
echo "=== Repository successfully published to: ==="
echo "${DEST_DIR}"
echo ""
echo "Files created:"
ls -lh Packages Packages.gz Packages.sig
