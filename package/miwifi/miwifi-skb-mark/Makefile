#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=miwifi-skb-mark
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/miwifi-skb-mark
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=miwifi skb mark
  DEPENDS:=@TARGET_ipq53xx
endef

define KernelPackage/miwifi-skb-mark/install
  true
endef

$(eval $(call KernelPackage,miwifi-skb-mark))
