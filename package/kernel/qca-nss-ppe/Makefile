include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-ppe
PKG_RELEASE:=1
PKG_LICENSE:=ISC GPL-2.0

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git
PKG_SOURCE_DATE:=2024-05-23
PKG_SOURCE_VERSION:=a9998acd81f2e1bd0ef128003ad8b6b67c24b1f6
PKG_MIRROR_HASH:=060b27889a02db9237659782ac22262c2598f7be4cb04a73a14d441d73b8a4ff

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-nss-ppe
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Kernel driver for PPE (core driver)
  DEPENDS:=@TARGET_ipq53xx +kmod-qca-ssdk-nohnat +kmod-nat46
  FILES:=$(PKG_BUILD_DIR)/drv/ppe_drv/qca-nss-ppe.ko
  AUTOLOAD:=$(call AutoLoad,31,qca-nss-ppe)
endef

define KernelPackage/qca-nss-ppe/Description
  NSS PPE core driver for Qualcomm IPQ53xx.
endef

define KernelPackage/qca-nss-ppe/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/ppe_flow_dump $(1)/usr/bin/
	$(INSTALL_BIN) ./files/ppe_if_map $(1)/usr/bin/
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/qca-nss-ppe
	$(CP) $(PKG_BUILD_DIR)/exports/* $(1)/usr/include/qca-nss-ppe/
	$(CP) $(PKG_BUILD_DIR)/drv/exports/* $(1)/usr/include/qca-nss-ppe/
endef

EXTRA_CFLAGS+= \
	-I$(STAGING_DIR)/usr/include \
	-I$(STAGING_DIR)/usr/include/qca-ssdk \
	-I$(STAGING_DIR)/usr/include/qca-ssdk/fal \
	-I$(STAGING_DIR)/usr/include/qca-ssdk/init \
	-I$(STAGING_DIR)/usr/include/nat46

MAKE_OPTS:=ppe-drv=y

define Build/Compile
	+$(KERNEL_MAKE) $(PKG_JOBS) $(strip $(MAKE_OPTS)) \
		M="$(PKG_BUILD_DIR)" \
		EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
		SoC="ipq53xx" \
		modules
endef

$(eval $(call KernelPackage,qca-nss-ppe))
