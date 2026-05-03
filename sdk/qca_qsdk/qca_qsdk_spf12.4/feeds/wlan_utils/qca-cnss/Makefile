#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-cnss
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-cnss
	SECTION:=kernel
	CATEGORY:=Kernel modules
	SUBMENU:=Network Devices
	TITLE:=CNSS Platform Driver
	DEPENDS:=@TARGET_ipq53xx
endef

define KernelPackage/qca-cnss/install
    true
endef

$(eval $(call KernelPackage,qca-cnss))
