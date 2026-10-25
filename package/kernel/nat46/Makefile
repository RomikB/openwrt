include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=nat46

ifeq ($(call kernel_patchver_eq,5.4),1)
  # QSDK 12.4 version for kernel 5.4 with PPE/ECM hardware MAP-T acceleration
  PKG_SOURCE_DATE:=2020-06-26
  PKG_SOURCE_VERSION:=1182f30785e4274913f01a8c3d7e1b5437ae3819
  PKG_MIRROR_HASH:=1f11eadbfb4f40b61a0e939fbf5aa3218b0ba0d3b01ed880f14f2d63c4a66ef1
  PATCH_DIR:=./patches-5.4
else
  # Upstream OpenWrt 25 version for kernels 6.x
  PKG_SOURCE_DATE:=2025-04-23
  PKG_SOURCE_VERSION:=04923c51039e8ca270c6f1dde3f04f3b36958089
  PKG_MIRROR_HASH:=35d7987eed7f05e5f7d1d2e111a8c9f5d019ccf11eb839dfe0bd2e2c46b6199a
  PATCH_DIR:=./patches
endif

PKG_SOURCE_URL:=https://github.com/ayourtch/nat46.git
PKG_SOURCE_PROTO:=git
PKG_MAINTAINER:=Hans Dedecker <dedeckeh@gmail.com>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define KernelPackage/nat46
  DEPENDS:=@IPV6 +kmod-nf-conntrack6
  TITLE:=Stateless NAT46 translation kernel module
  SECTION:=kernel
  SUBMENU:=Network Support
  FILES:=$(PKG_BUILD_DIR)/nat46/modules/nat46.ko
  AUTOLOAD:=$(call AutoLoad,33,nat46)
endef

include $(INCLUDE_DIR)/kernel-defaults.mk

define Build/Compile
	$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)/nat46/modules" \
		MODFLAGS="-DMODULE -mlong-calls" \
		EXTRA_CFLAGS="-DNAT46_VERSION=\\\"$(PKG_SOURCE_VERSION)\\\"" \
		modules
	[ ! -f $(PKG_BUILD_DIR)/nat46/modules/Module.symvers ] || \
		cp $(PKG_BUILD_DIR)/nat46/modules/Module.symvers $(PKG_BUILD_DIR)/Module.symvers
endef

define Build/InstallDev
	mkdir -p -m 0777 $(STAGING_DIR)/usr/include/nat46
	$(CP) $(PKG_BUILD_DIR)/nat46/modules/*.h $(STAGING_DIR)/usr/include/nat46/
endef

$(eval $(call KernelPackage,nat46))
