#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=conntrack-attr
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/conntrack-attr
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=conntrack-attr
  DEPENDS:=@TARGET_ipq53xx
endef

define KernelPackage/connattr-label/install
  true
endef

$(eval $(call KernelPackage,conntrack-attr))
