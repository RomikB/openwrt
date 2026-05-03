#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=haohan_dpi
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/connattr-haohan
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=connattr-haohan
  DEPENDS:=@TARGET_ipq53xx +kmod-conntrack-attr +kmod-ipt-compat-xtables +kmod-nfnlq-extension +kmod-miwifi-skb-mark
endef

define Package/haohan_dpi
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=TODO
  DEPENDS:=@TARGET_ipq53xx +nfnlq-extension +kmod-connattr-haohan
endef

define KernelPackage/connattr-haohan/install
  true
endef

define Package/haohan_dpi/install
  true
endef

$(eval $(call KernelPackage,connattr-haohan))
$(eval $(call BuildPackage,haohan_dpi))
