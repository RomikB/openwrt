#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-dp
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-nss-dp
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  DEPENDS:=@TARGET_ipq53xx \
		+kmod-qca-ssdk-nohnat \
		+TARGET_ipq53xx:kmod-qca-nss-ppe
  TITLE:=Kernel driver for NSS data plane
endef

define KernelPackage/qca-nss-dp/install
	true
endef

$(eval $(call KernelPackage,qca-nss-dp))
