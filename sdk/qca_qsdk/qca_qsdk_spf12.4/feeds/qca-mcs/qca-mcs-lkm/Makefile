#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-mcs
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-mcs
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  DEPENDS:=@TARGET_ipq53xx
  TITLE:=This package installs the IGMP/MLD Snooping Module
endef

define KernelPackage/qca-mcs/install
	true
endef

$(eval $(call KernelPackage,qca-mcs))
