
ARCH:=arm
SUBTARGET:=rd15
BOARDNAME:=Xiaomi Router BE3600
FEATURES:=squashfs fpu nand
CPU_TYPE:=cortex-a7
KERNEL_PATCHVER:=5.4

DEFAULT_PACKAGES += \
	-procd-ujail \
	-firewall4 -nftables -kmod-nft-offload \
	firewall iptables-zz-legacy xtables-legacy swconfig bridge ethtool ip-full block-mount nand-utils \
	luci iperf3 htop iw iwinfo \
	kmod-bootconfig kmod-qca-nss-dp-vendor \
	kmod-yt-9215s-driver-vendor kmod-yt-phy-driver-vendor \
	kmod-pwm-rgb kmod-gpio-button-hotplug \
	nvram-vendor qca-ssdk-shell-vendor yt-9215s-client-vendor \
	kmod-ipt-conntrack-extra kmod-ipt-raw kmod-ipt-ipopt \
	kmod-ipt-offload kmod-ipt-filter kmod-ipt-extra kmod-ipt-nat6 \
	kmod-qca-nss-ecm-premium-vendor kmod-qca-nss-ppe-pppoe-mgr-vendor kmod-qca-nss-ppe-lag-mgr-vendor \
	qca-firmware-vendor wififw_mount_script-vendor qca-wifi-scripts-vendor \
	qca-cnss-daemon-vendor kmod-qca-wifi-lowmem-profile-vendor kmod-qca-nss-ecm-wifi-plugin-vendor \
	qca-hostap-vendor qca-wpa-supplicant-vendor qca-hostapd-cli-vendor qca-wpa-cli-vendor



define Target/Description
	Build firmware image for Xiaomi Router BE3600.
endef

KERNEL_TOOLCHAIN_DIR_NAME:=toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel
KERNEL_TOOLCHAIN_DIR:=$(TOPDIR)/staging_dir/$(KERNEL_TOOLCHAIN_DIR_NAME)
kernel_iremap = -iremap $(1):$(2)
KERNEL_CROSS:=$(KERNEL_TOOLCHAIN_DIR)/bin/arm-openwrt-linux-muslgnueabi-
KERNEL_CC:=$(KERNEL_CROSS)gcc
