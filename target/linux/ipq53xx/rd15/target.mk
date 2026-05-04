
ARCH:=arm
SUBTARGET:=rd15
BOARDNAME:=Xiaomi Router BE3600
FEATURES:=squashfs fpu nand
CPU_TYPE:=cortex-a7

DEFAULT_PACKAGES += \
	ab, anti-attack arptables athdiag athtestcmd-lith boost boost-date_time boost-iostreams \
	boot_check bridge cnssdiag common-tools conntrack cryptsetup-openssl \
	ddns-scripts ddns-scripts_no-ip_com e2fsprogs enid ethtool flock ftm glog htpdate \
	ip-full ip6tables-extra ip6tables-mod-nat \
	iptables-mod-filter iptables-mod-ipsec iptables-mod-physdev ipv6-support-v2 iwevent-call json4lua \
	kmod-bootconfig kmod-crypto-authenc kmod-crypto-cbc kmod-crypto-deflate kmod-crypto-des kmod-crypto-iv kmod-crypto-md5 kmod-crypto-xts \
	kmod-diag-char kmod-enid kmod-fs-ext4 kmod-i2c-core \
	kmod-ipaccount2 kmod-ipt-sctp kmod-ipt-tproxy kmod-ipt-u32 kmod-loop kmod-macvlan \
	kmod-nf-nathelper kmod-nf-nathelper-extra kmod-nft-netdev kmod-nft-offload \
	kmod-nls-cp437 kmod-nls-iso8859-1 kmod-nls-utf8 \
	kmod-passthrough kmod-pwm-rgb kmod-qca-nss-ecm-wifi-plugin kmod-qca-nss-nsm \
	kmod-qca-nss-ppe-lag-mgr kmod-qca-nss-ppe-pppoe-mgr \
	kmod-yt-9215s-driver kmod-yt-phy-driver \
	libacl libaio libcap libconfig libdaemon libexpat libgmp libgpg-error \
	libiconv-full libiconv libltdl libssh2 libthriftnb libubox-lua libwrap \
	lsqlite3 local_gw_security losetup lua_crypto_lib luabitop luac lualogging luaposix luasec \
	luci-i18n-chinese luci-i18n-hongkong luci-i18n-taiwan luci-lib-lua-cjson luci-lib-xiaoqiang \
	luci-mod-admin-diagnosis luci-mod-func-anti_attack luci-mod-func-mipctl luci-mod-product-retails luci-theme-web \
	map messagingagent miio_ot miio_spec minidump miniupnpd miparentalctl_v2 \
	miwifi-discovery miwifi-logd miwifi-mesh miwifi-relay miwifi-roam miwifi-storage \
	miqos mobile_accel mosquitto-ssl mwan3 myftm nand-utils netapi nginx nvram openssl-util packagesign pconfig pluginmanager \
	port_service port_service_game port_service_lag port_service_media port_service_wandt \
	ppp-mod-pptp pppoe-discovery predownload-ota qca-cfg80211tool qca-cnss-daemon qca-firmware \
	qca-hostap qca-hostapd-cli qca-ssdk-shell qca-thermald qca-wifi-scripts \
	qca-wpa-cli qca-wpa-supplicant qti-license-pfm rp-pppoe-server rsync smartcontroller_c \
	spawn-fcgi sys_tester tc-full tcpdump-mini thrifttunnel topology_monitor_v2 \
	traffic2 tz2localtime uboot-2016-ipq5332 uclibcxx wan_check_v2 webpages wififw_mount_script \
	xiaoqiang_sync xl2tpd xq_info_sync_mqtt yt-9215s-client \
	zoneinfo-africa zoneinfo-asia zoneinfo-atlantic zoneinfo-australia-nz zoneinfo-core zoneinfo-europe \
	zoneinfo-india zoneinfo-northamerica zoneinfo-pacific zoneinfo-poles zoneinfo-simple zoneinfo-southamerica \
	librpc 

define Target/Description
	Build firmware image for Xiaomi Router BE3600.
endef

KERNEL_CONFIG += CONFIG_ARM_PMU=y