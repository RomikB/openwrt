#!/bin/sh

set -e

enable() {
    echo "CONFIG_${1}=${2:-y}" >> .config
}

disable() {
    echo "# CONFIG_${1} is not set" >> .config
}

echo "Preparing target configuration for Xiaomi Router BE3600 (RD15)..."

rm -f .config

enable TARGET_ipq53xx
enable TARGET_ipq53xx_rd15
enable TARGET_ipq53xx_rd15_DEVICE_xiaomi-rd15-prebuild
disable USE_SECCOMP
disable USE_FS_ACL_ATTR
disable KERNEL_SECCOMP
disable KERNEL_SWAP
disable KERNEL_NAMESPACES
enable KERNEL_DEVMEM
enable KERNEL_CC_OPTIMIZE_FOR_SIZE
enable KERNEL_CGROUP_DEVICE
enable KERNEL_CGROUP_FREEZER
disable KERNEL_CGROUP_BPF
disable KERNEL_CGROUP_RDMA
disable KERNEL_JFFS2_FS_SECURITY
disable KERNEL_UBIFS_FS_SECURITY
disable KERNEL_IPV6_MROUTE_MULTIPLE_TABLES
disable KERNEL_IPV6_PIMSM_V2
disable KERNEL_IPV6_SEG6_LWTUNNEL
enable KERNEL_PERF_EVENTS
disable KERNEL_DEBUG_INFO_REDUCED
enable KERNEL_DEBUG_ATOMIC_SLEEP

make defconfig

echo "Configuration successfully prepared."
