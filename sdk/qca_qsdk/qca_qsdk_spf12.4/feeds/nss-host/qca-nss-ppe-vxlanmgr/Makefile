#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-ppe-vxlanmgr
PKG_VERSION:=miwifi_git
PKG_RELEASE:=2

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-nss-ppe-vxlanmgr
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Kernel driver for PPE VxLAN tunnel client
  DEPENDS:=@TARGET_ipq53xx \
		+kmod-qca-nss-ppe-tun \
		+kmod-qca-nss-ppe-bridge-mgr \
		+kmod-vxlan
endef

$(eval $(call KernelPackage,qca-nss-ppe-vxlanmgr))
