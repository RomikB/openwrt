
ARCH:=arm
SUBTARGET:=rd15
BOARDNAME:=Xiaomi Router BE3600
FEATURES:=squashfs fpu nand
CPU_TYPE:=cortex-a7
KERNEL_PATCHVER:=5.4

DEFAULT_PACKAGES += \
	-procd-ujail \
	swconfig bridge ethtool ip-full block-mount nand-utils \
	luci iperf3 htop iw iwinfo \
	kmod-bootconfig \
	kmod-qca-nss-ppe-pppoe-mgr kmod-qca-nss-ppe-lag-mgr \
	kmod-pwm-rgb kmod-gpio-button-hotplug \
	qca-ssdk-shell \
	kmod-yt-9215s-driver kmod-yt-phy-driver yt-9215s-client \
	kmod-nft-bridge \
	kmod-qca-nss-ecm-wifi-plugin \
	qca-firmware-vendor wififw_mount_script qca-wifi-scripts \
	qca-cnss-daemon-vendor \
	qca-hostap-vendor qca-wpa-supplicant-vendor qca-hostapd-cli qca-wpa-cli



define Target/Description
	Build firmware image for Xiaomi Router BE3600.
endef

KERNEL_TOOLCHAIN_DIR_NAME:=toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel
KERNEL_TOOLCHAIN_DIR:=$(TOPDIR)/staging_dir/$(KERNEL_TOOLCHAIN_DIR_NAME)
kernel_iremap = -iremap $(1):$(2)
KERNEL_CROSS:=$(KERNEL_TOOLCHAIN_DIR)/bin/arm-openwrt-linux-muslgnueabi-
KERNEL_CC:=$(KERNEL_CROSS)gcc
