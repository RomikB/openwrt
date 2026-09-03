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
  # Upstream OpenWrt 24 version for kernels 5.15+
  PKG_SOURCE_DATE:=2022-09-19
  PKG_SOURCE_VERSION:=4c5beee236841724219598fabb1edc93d4f08ce5
  PKG_MIRROR_HASH:=09b93f31d10030d3b4f326066b544b70b1f60236d0482f27c384ed93b298c0a6
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
