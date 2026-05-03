#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=emesh-sp
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/emesh-sp
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  DEPENDS:=@TARGET_ipq53xx
  TITLE:=This is the kernel module for Service Prioritization in EasyMesh
endef

define KernelPackage/emesh-sp/install
	true
endef

$(eval $(call KernelPackage,emesh-sp))
