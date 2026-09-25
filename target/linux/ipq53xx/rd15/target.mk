
ARCH:=arm
SUBTARGET:=rd15
BOARDNAME:=Xiaomi Router BE3600
FEATURES:=squashfs fpu nand
CPU_TYPE:=cortex-a7
KERNEL_PATCHVER:=5.4

DEFAULT_PACKAGES.router:=\
	-procd-ujail \
	dnsmasq-full \
	firewall4 \
	nftables \
	kmod-nft-offload \
	odhcp6c \
	odhcpd-ipv6only \
	ppp \
	ppp-mod-pppoe

DEFAULT_PACKAGES += \
	kmod-bootconfig kmod-gpio-button-hotplug kmod-pwm-rgb \
	kmod-nft-bridge \
	kmod-yt-9215s-driver kmod-yt-phy-driver swconfig yt-9215s-client \
	kmod-qca-nss-ppe-lag-mgr kmod-qca-nss-ppe-pppoe-mgr qca-ssdk-shell \
	block-mount ethtool ip-full nand-utils \
	luci \
	iw iwinfo kmod-qca-nss-ecm-wifi-plugin \
	qca-cnss-daemon-vendor qca-firmware-vendor qca-hostap-vendor \
	qca-hostapd-cli qca-wpa-cli qca-wpa-supplicant-vendor wififw_mount_script \
	iperf3 htop \
	amneziawg-tools luci-proto-amneziawg \
	kmod-nft-tproxy ruantiblock luci-app-ruantiblock \
	kmod-nft-queue zapret2 luci-app-zapret2 \
	kmod-nft-socket \
	kmod-tcp-bbr

define Target/Description
	Build firmware image for Xiaomi Router BE3600.
endef

KERNEL_TOOLCHAIN_DIR_NAME:=toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel
KERNEL_TOOLCHAIN_DIR:=$(TOPDIR)/staging_dir/$(KERNEL_TOOLCHAIN_DIR_NAME)
kernel_iremap = -iremap $(1):$(2)
KERNEL_CROSS:=$(KERNEL_TOOLCHAIN_DIR)/bin/arm-openwrt-linux-muslgnueabi-
KERNEL_CC:=$(KERNEL_CROSS)gcc
