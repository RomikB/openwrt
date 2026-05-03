#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-ssdk
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-ssdk-nohnat
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Kernel driver for QCA SSDK
  DEPENDS:=@TARGET_ipq53xx
  PROVIDES:=qca-ssdk
  VARIANT:=nohnat
endef

define KernelPackage/qca-ssdk-nohnat/install
	true
endef

$(eval $(call KernelPackage,qca-ssdk-nohnat))
