include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-ppe-vp
PKG_RELEASE:=1
PKG_LICENSE:=ISC GPL-2.0

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git
PKG_SOURCE_DATE:=2024-01-19
PKG_SOURCE_VERSION:=0c6434d7d19459b9e10ccf870faffb7dff8e4d98
PKG_MIRROR_HASH:=511aaf6dc77c6d5c96c26cdff63142a12ab21c5aeb8b5d7e2b6d2b38e8a1ba82
PKG_SOURCE_SUBDIR:=qca-nss-ppe-$(subst -,.,$(PKG_SOURCE_DATE))~$(call version_abbrev,$(PKG_SOURCE_VERSION))
PKG_SOURCE:=$(PKG_SOURCE_SUBDIR).tar.zst

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

TAR_OPTIONS+=--strip-components 1
TAR_CMD=$(HOST_TAR) -C $(1) $(TAR_OPTIONS)

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(Build/Prepare/Default)
endef

define KernelPackage/qca-nss-ppe-vp
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Kernel driver for PPE virtual port (core driver)
  DEPENDS:=@TARGET_ipq53xx +kmod-qca-nss-ppe +kmod-qca-nss-dp
  FILES:=$(PKG_BUILD_DIR)/drv/ppe_vp/qca-nss-ppe-vp.ko
  AUTOLOAD:=$(call AutoLoad,52,qca-nss-ppe-vp)
endef

define KernelPackage/qca-nss-ppe-vp/Description
  Kernel module for PPE virtual port core driver (IPQ53xx/RD15).
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/qca-nss-ppe
	$(CP) $(PKG_BUILD_DIR)/drv/exports/* $(1)/usr/include/qca-nss-ppe/
endef

EXTRA_CFLAGS+= \
	-I$(STAGING_DIR)/usr/include \
	-I$(STAGING_DIR)/usr/include/qca-nss-dp \
	-I$(STAGING_DIR)/usr/include/qca-nss-ppe \
	-I$(STAGING_DIR)/usr/include/qca-ssdk \
	-I$(STAGING_DIR)/usr/include/qca-ssdk/fal \
	-I$(STAGING_DIR)/usr/include/qca-ssdk/init

MAKE_OPTS:=ppe-vp=y

define Build/Compile
	+$(KERNEL_MAKE) $(PKG_JOBS) $(strip $(MAKE_OPTS)) \
		M="$(PKG_BUILD_DIR)" \
		EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
		SoC="ipq53xx" \
		modules
endef

$(eval $(call KernelPackage,qca-nss-ppe-vp))
