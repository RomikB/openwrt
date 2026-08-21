
ARCH:=arm
SUBTARGET:=rd15
BOARDNAME:=Xiaomi Router BE3600
FEATURES:=squashfs fpu nand
CPU_TYPE:=cortex-a7
DEFAULT_PACKAGES += \
	-procd-ujail \
	-firewall4 -nftables -kmod-nft-offload \
	firewall iptables-zz-legacy xtables-legacy swconfig bridge ethtool ip-full block-mount nand-utils \
	luci iperf3 htop iw \
	kmod-bootconfig-vendor kmod-qca-nss-dp-vendor \
	kmod-yt-9215s-driver-vendor kmod-yt-phy-driver-vendor \
	kmod-pwm-rgb-vendor kmod-gpio-button-hotplug-vendor \
	nvram-vendor qca-ssdk-shell-vendor yt-9215s-client-vendor \
	kmod-ipt-conntrack-extra-vendor kmod-ipt-raw-vendor kmod-ipt-ipopt-vendor \
	kmod-ipt-offload-vendor kmod-ipt-filter-vendor kmod-ipt-extra-vendor kmod-ipt-nat6-vendor \
	kmod-qca-nss-ecm-premium-vendor kmod-qca-nss-ppe-pppoe-mgr-vendor kmod-qca-nss-ppe-lag-mgr-vendor \
	qca-firmware-vendor wififw_mount_script-vendor qca-wifi-scripts-vendor \
	qca-cnss-daemon-vendor kmod-qca-wifi-lowmem-profile-vendor \
	qca-hostap-vendor qca-wpa-supplicant-vendor qca-hostapd-cli-vendor qca-wpa-cli-vendor



define Target/Description
	Build firmware image for Xiaomi Router BE3600.
endef
