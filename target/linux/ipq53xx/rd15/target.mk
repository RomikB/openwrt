
ARCH:=arm
SUBTARGET:=rd15
BOARDNAME:=Xiaomi Router BE3600
FEATURES:=squashfs fpu nand
CPU_TYPE:=cortex-a7
DEFAULT_PACKAGES += \
	-procd-ujail \
	-firewall4 -nftables -kmod-nft-offload \
	firewall iptables-zz-legacy xtables-legacy swconfig bridge ethtool ip-full block-mount nand-utils \
	kmod-bootconfig-vendor kmod-qca-nss-dp-vendor \
	kmod-yt-9215s-driver-vendor kmod-yt-phy-driver-vendor \
	kmod-pwm-rgb-vendor kmod-gpio-button-hotplug-vendor \
	kmod-ipt-core-vendor kmod-ipt-nat-vendor kmod-ipt-conntrack-vendor \
	kmod-ipt-conntrack-extra-vendor kmod-ipt-raw-vendor kmod-ipt-ipopt-vendor \
	kmod-ipt-offload-vendor kmod-ipt-filter-vendor kmod-ipt-extra-vendor \
	kmod-ipt-nat6-vendor kmod-nf-conntrack-vendor kmod-nf-conntrack6-vendor \
	kmod-nf-nat-vendor kmod-nf-nat6-vendor kmod-nf-reject-vendor kmod-nf-reject6-vendor \
	kmod-ppp-vendor kmod-pppoe-vendor kmod-pppox-vendor kmod-slhc-vendor kmod-lib-crc-ccitt-vendor kmod-ipv6-vendor \
	kmod-qca-nss-ecm-premium-vendor kmod-qca-nss-ppe-pppoe-mgr-vendor kmod-qca-nss-ppe-ds-vendor kmod-qca-nss-ppe-lag-mgr-vendor \
	luci iperf3 htop \
	qca-firmware-vendor wififw_mount_script-vendor qca-wifi-scripts-vendor \
	kmod-qca-cnss-vendor qca-cnss-daemon-vendor qca-qmi-framework-vendor libnl-vendor \
	kmod-cfg80211-linux-vendor kmod-qca-wifi-lowmem-profile-vendor qca-cfg80211-vendor libroxml-vendor iw \
	libopenssl-vendor qca-hostap-vendor qca-wpa-supplicant-vendor qca-hostapd-cli-vendor qca-wpa-cli-vendor \
	nvram-vendor qca-ssdk-shell-vendor \
	yt-9215s-client-vendor


define Target/Description
	Build firmware image for Xiaomi Router BE3600.
endef
