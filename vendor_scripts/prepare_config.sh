#!/bin/sh

set -e

enable() {
    echo "CONFIG_${1}=${2:-y}" >> .config
}

disable() {
    echo "# CONFIG_${1} is not set" >> .config
}

TARGET_MODEL="${1:-rd15}"
case "$TARGET_MODEL" in
    rd16|RD16) TARGET_MODEL="rd16" ;;
    all|ALL)   TARGET_MODEL="all" ;;
    *)         TARGET_MODEL="rd15" ;;
esac

echo "Preparing target configuration for Xiaomi Router BE3600 ($TARGET_MODEL)..."

rm -f .config

enable TARGET_ipq53xx
enable TARGET_ipq53xx_ipq53xx_32
enable TARGET_MULTI_PROFILE
enable TARGET_PER_DEVICE_ROOTFS

case "$TARGET_MODEL" in
    rd16)
        enable TARGET_DEVICE_ipq53xx_ipq53xx_32_DEVICE_xiaomi-rd16-qsdk
        enable TARGET_DEVICE_ipq53xx_ipq53xx_32_DEVICE_xiaomi-rd16-qsdk-singbox
        ;;
    all)
        enable TARGET_DEVICE_ipq53xx_ipq53xx_32_DEVICE_xiaomi-rd15-qsdk
        enable TARGET_DEVICE_ipq53xx_ipq53xx_32_DEVICE_xiaomi-rd15-qsdk-singbox
        enable TARGET_DEVICE_ipq53xx_ipq53xx_32_DEVICE_xiaomi-rd15-qsdk-dev
        enable TARGET_DEVICE_ipq53xx_ipq53xx_32_DEVICE_xiaomi-rd16-qsdk
        enable TARGET_DEVICE_ipq53xx_ipq53xx_32_DEVICE_xiaomi-rd16-qsdk-singbox
        ;;
    *)
        enable TARGET_DEVICE_ipq53xx_ipq53xx_32_DEVICE_xiaomi-rd15-qsdk
        enable TARGET_DEVICE_ipq53xx_ipq53xx_32_DEVICE_xiaomi-rd15-qsdk-singbox
        enable TARGET_DEVICE_ipq53xx_ipq53xx_32_DEVICE_xiaomi-rd15-qsdk-dev
        ;;
esac
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
enable KERNEL_CC_STACKPROTECTOR_STRONG
enable KERNEL_DYNAMIC_DEBUG
enable KERNEL_CGROUP_NET_CLASSID
enable KERNEL_NET_CLS_CGROUP
disable KERNEL_AIO
disable KERNEL_FHANDLE
disable KERNEL_FANOTIFY
disable KERNEL_EXT4_FS_SECURITY
disable KERNEL_NF_CONNTRACK_TIMEOUT
disable KERNEL_BLK_DEV_THROTTLING
disable KERNEL_KALLSYMS
disable KERNEL_KEYS
enable LUCI_LANG_ru

# Modular packages to build as standalone .ipk without embedding into ROM (=m)
enable PACKAGE_forkop m
enable PACKAGE_iptables-mod-ipopt
enable PACKAGE_iptables-nft m
enable PACKAGE_kmod-ifb m
enable PACKAGE_kmod-sched-cake m
enable PACKAGE_librt m
enable PACKAGE_luci-app-forkop m
enable PACKAGE_luci-app-podkop m
enable PACKAGE_luci-app-ruantiblock m
enable PACKAGE_podkop m
enable PACKAGE_ruantiblock m
enable PACKAGE_ruantiblock-mod-lua m

# Busybox customization
enable BUSYBOX_CUSTOM
enable BUSYBOX_CONFIG_ARPING
enable BUSYBOX_CONFIG_ASH_HELP
enable BUSYBOX_CONFIG_ASH_IDLE_TIMEOUT
enable BUSYBOX_CONFIG_ASH_SLEEP
enable BUSYBOX_CONFIG_BASE64
enable BUSYBOX_CONFIG_BUNZIP2
enable BUSYBOX_CONFIG_DEVMEM
enable BUSYBOX_CONFIG_FEATURE_FTPD_WRITE
enable BUSYBOX_CONFIG_FEATURE_GETOPT_LONG
enable BUSYBOX_CONFIG_FEATURE_PS_ADDITIONAL_COLUMNS
enable BUSYBOX_CONFIG_FEATURE_PS_LONG
enable BUSYBOX_CONFIG_FEATURE_PS_TIME
enable BUSYBOX_CONFIG_FEATURE_RUN_PARTS_FANCY
enable BUSYBOX_CONFIG_FEATURE_RUN_PARTS_LONG_OPTIONS
enable BUSYBOX_CONFIG_FEATURE_SHOW_THREADS
enable BUSYBOX_CONFIG_FEATURE_SH_MATH_BASE
enable BUSYBOX_CONFIG_FEATURE_SH_READ_FRAC
enable BUSYBOX_CONFIG_FEATURE_STAT_FILESYSTEM
enable BUSYBOX_CONFIG_FEATURE_STAT_FORMAT
enable BUSYBOX_CONFIG_FEATURE_SUID
enable BUSYBOX_CONFIG_FEATURE_SUID_CONFIG
enable BUSYBOX_CONFIG_FEATURE_TELNETD_STANDALONE
enable BUSYBOX_CONFIG_FEATURE_TFTP_BLOCKSIZE
enable BUSYBOX_CONFIG_FEATURE_TFTP_GET
enable BUSYBOX_CONFIG_FEATURE_TFTP_PUT
enable BUSYBOX_CONFIG_FEATURE_TOPMEM
enable BUSYBOX_CONFIG_FEATURE_TOP_SMP_CPU
enable BUSYBOX_CONFIG_FEATURE_TOP_SMP_PROCESS
enable BUSYBOX_CONFIG_FEATURE_UDHCPC_ARPING
enable BUSYBOX_CONFIG_FEATURE_WGET_AUTHENTICATION
enable BUSYBOX_CONFIG_FEATURE_WGET_HTTPS
enable BUSYBOX_CONFIG_FEATURE_WGET_LONG_OPTIONS
enable BUSYBOX_CONFIG_FEATURE_WGET_STATUSBAR
enable BUSYBOX_CONFIG_FEATURE_WGET_TIMEOUT
enable BUSYBOX_CONFIG_FTPD
enable BUSYBOX_CONFIG_FTPGET
enable BUSYBOX_CONFIG_FTPPUT
enable BUSYBOX_CONFIG_GETOPT
enable BUSYBOX_CONFIG_HOSTID
enable BUSYBOX_CONFIG_INETD
enable BUSYBOX_CONFIG_IPCS
enable BUSYBOX_CONFIG_LOGIN_SESSION_AS_CHILD
enable BUSYBOX_CONFIG_LSOF
enable BUSYBOX_CONFIG_MKFS_EXT2
enable BUSYBOX_CONFIG_MKFS_VFAT
enable BUSYBOX_CONFIG_MPSTAT
enable BUSYBOX_CONFIG_PIE
enable BUSYBOX_CONFIG_PSTREE
enable BUSYBOX_CONFIG_RENICE
enable BUSYBOX_CONFIG_RUN_PARTS
enable BUSYBOX_CONFIG_STAT
enable BUSYBOX_CONFIG_TELNET
enable BUSYBOX_CONFIG_TELNETD
enable BUSYBOX_CONFIG_TFTP
enable BUSYBOX_CONFIG_TFTPD
enable BUSYBOX_CONFIG_TIMEOUT
enable BUSYBOX_CONFIG_UNXZ
enable BUSYBOX_CONFIG_USLEEP
enable BUSYBOX_CONFIG_VCONFIG
enable BUSYBOX_CONFIG_WATCH
enable BUSYBOX_CONFIG_WGET
enable BUSYBOX_CONFIG_XZ

# Minimal profile for sing-box (exclude heavy Go subsystems: WireGuard, Tailscale, Tor, gRPC, ACME, V2Ray API, DHCP, gVisor)
disable SINGBOX_WITH_ACME
disable SINGBOX_WITH_DHCP
disable SINGBOX_WITH_EMBEDDED_TOR
disable SINGBOX_WITH_GRPC
disable SINGBOX_WITH_GVISOR
disable SINGBOX_WITH_TAILSCALE
disable SINGBOX_WITH_V2RAY_API
disable SINGBOX_WITH_WIREGUARD

# Exclude non-standard feeds from target distfeeds.conf (keep standard base, luci, packages, routing, telephony)
disable FEED_vendor_feed
disable FEED_amneziawg
disable FEED_forkop
disable FEED_podkop
disable FEED_ruantiblock
disable FEED_zapret2

# Wi-Fi configuration (use classic shell netifd driver for Qualcomm QSDK 12.5)
disable WIFI_SCRIPTS_UCODE
enable WIFI_SCRIPTS_WPS_BUTTON_DISABLED

make defconfig

echo "Configuration successfully prepared."
