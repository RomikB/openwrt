include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-dp
PKG_RELEASE:=1
PKG_LICENSE:=ISC GPL-2.0

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-dp.git

ifeq ($(CONFIG_TARGET_ipq53xx),y)
  PKG_SOURCE_DATE:=2024-02-01
  PKG_SOURCE_VERSION:=931028771b0e4e69238f47e313421e730d81fa2f
  PKG_MIRROR_HASH:=54e54d60551662b7fb0e943b6f1b897e7341fecbcd74747c1b9e2cc722071592
  PATCH_DIR:=./patches-5.4
  DP_DEPENDS:=@TARGET_ipq53xx +kmod-qca-ssdk-nohnat +kmod-qca-nss-ppe
  DP_SOC:=ipq53xx
else
  PKG_SOURCE_DATE:=2024-04-16
  PKG_SOURCE_VERSION:=5bf8b91e9fc209f175f9a58723b03055ace3d581
  PKG_MIRROR_HASH:=e86b04ea674c18fb69cd09a45ccab50317b85117e40d76c8457052c2e55d7c18
  PATCH_DIR:=./patches
  DP_DEPENDS:=@(TARGET_qualcommax||TARGET_ipq53xx) +TARGET_ipq53xx:kmod-qca-ssdk-nohnat +TARGET_ipq53xx:kmod-qca-nss-ppe +TARGET_qualcommax:kmod-qca-ssdk
  DP_SOC:=ipq53xx
endif

PKG_BUILD_PARALLEL:=1
PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-nss-dp
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Qualcomm NSS dataplane ethernet driver
  DEPENDS:=$(DP_DEPENDS)
  FILES:=$(PKG_BUILD_DIR)/qca-nss-dp.ko
  AUTOLOAD:=$(call AutoLoad,31,qca-nss-dp,1)
endef

define KernelPackage/qca-nss-dp/Description
  NSS dataplane ethernet driver for Qualcomm SoCs (IPQ53xx/RD15).
endef

define KernelPackage/qca-nss-dp/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/qca-nss-dp $(1)/etc/init.d/qca-nss-dp
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/etc/config/qca_nss_dp $(1)/etc/config/qca_nss_dp
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/edma_dump $(1)/usr/bin/edma_dump
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/qca-nss-dp
	$(CP) $(PKG_BUILD_DIR)/exports/* $(1)/usr/include/qca-nss-dp/
	$(CP) $(PKG_BUILD_DIR)/include/* $(1)/usr/include/qca-nss-dp/
endef

EXTRA_CFLAGS+= \
	-I$(STAGING_DIR)/usr/include/qca-ssdk \
	-I$(STAGING_DIR)/usr/include/qca-nss-ppe

NSS_DP_HAL_DIR:=$(PKG_BUILD_DIR)/hal

define Build/Configure
	$(CP) $(NSS_DP_HAL_DIR)/soc_ops/$(DP_SOC)/nss_$(DP_SOC).h \
		$(PKG_BUILD_DIR)/exports/nss_dp_arch.h
endef

MAKE_OPTS:=dp-ppe-ds=y

define Build/Compile
	+$(KERNEL_MAKE) $(PKG_JOBS) $(strip $(MAKE_OPTS)) \
		-C "$(LINUX_DIR)" \
		M="$(PKG_BUILD_DIR)" \
		EXTRA_CFLAGS="$(EXTRA_CFLAGS)" SoC="$(DP_SOC)" \
		modules
endef

$(eval $(call KernelPackage,qca-nss-dp))
