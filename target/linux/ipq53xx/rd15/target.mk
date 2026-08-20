
ARCH:=arm
SUBTARGET:=rd15
BOARDNAME:=Xiaomi Router BE3600
FEATURES:=squashfs fpu nand
CPU_TYPE:=cortex-a7
DEVICE_TYPE:=basic

DEFAULT_PACKAGES += \
	-opkg -urandom-seed -urngd -procd-ujail \
	-ca-bundle -libustream-mbedtls \
	base-files libc libgcc bridge ethtool ip-full nand-utils dropbear mtd uci swconfig busybox ubus ubusd ubox getrandom logd fstools block-mount ubi-utils procd netifd jsonfilter usign openwrt-keyring fwtool \
	kmod-bootconfig-vendor kmod-qca-nss-dp-vendor \
	kmod-yt-9215s-driver-vendor kmod-yt-phy-driver-vendor \
	nvram-vendor qca-ssdk-shell-vendor \
	yt-9215s-client-vendor


define Target/Description
	Build firmware image for Xiaomi Router BE3600.
endef
