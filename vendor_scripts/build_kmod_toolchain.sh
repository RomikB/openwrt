#!/usr/bin/env bash
#
# Build script for dedicated Linux 5.4 kernel module toolchain (GCC 7.5.0)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPDIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TOOLCHAIN_DIR="${TOPDIR}/staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel"

echo "================================================================="
echo " Building Linux 5.4.213 Kernel Module Toolchain (GCC 7.5.0)"
echo " Workspace: ${TOPDIR}"
echo " Destination: ${TOOLCHAIN_DIR}"
echo "================================================================="

# Ensure host tools from OpenWrt are built
STAMP_TOOLS_COMPILE="$(find "${TOPDIR}/staging_dir/host/stamp" -name ".tools_compile_*" 2>/dev/null | head -n 1 || true)"

if [ -z "${STAMP_TOOLS_COMPILE}" ] || \
   [ ! -f "${TOPDIR}/staging_dir/host/bin/m4" ] || \
   [ ! -f "${TOPDIR}/staging_dir/host/include/gmp.h" ] || \
   [ ! -f "${TOPDIR}/staging_dir/host/include/mpfr.h" ] || \
   [ ! -f "${TOPDIR}/staging_dir/host/include/mpc.h" ] || \
   [ ! -f "${TOPDIR}/staging_dir/host/lib/libmpc.a" ]; then
    echo "Host tools / required libraries (GMP/MPFR/MPC) in staging_dir/host not complete."
    echo "Building OpenWrt host tools first (make tools/install)..."
    make -C "${TOPDIR}" tools/install -j"$(nproc 2>/dev/null || echo 4)"
fi

# Run the vendor toolchain build
make -C "${TOPDIR}/vendor_toolchain" -j1 all

echo ""
echo "================================================================="
echo " Toolchain Build Complete!"
echo " Compiler: ${TOOLCHAIN_DIR}/bin/arm-openwrt-linux-gcc"
echo " Version:  $("${TOOLCHAIN_DIR}/bin/arm-openwrt-linux-gcc" -dumpversion)"
echo ""
echo " To build kernel modules out-of-tree for Linux 5.4.213:"
echo "   export PATH=\"${TOOLCHAIN_DIR}/bin:\$PATH\""
echo "   export CROSS_COMPILE=arm-openwrt-linux-"
echo "   export ARCH=arm"
echo "================================================================="
