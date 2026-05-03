#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-ppe-tun
PKG_VERSION:=miwifi_git
PKG_RELEASE:=2

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-nss-ppe-tun
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Kernel driver for PPE Tunnel (tunnel driver)
  DEPENDS:=@TARGET_ipq53xx +kmod-qca-nss-ppe +kmod-qca-nss-ppe-vp +kmod-qca-nss-ppe-rule
endef

$(eval $(call KernelPackage,qca-nss-ppe-tun))
