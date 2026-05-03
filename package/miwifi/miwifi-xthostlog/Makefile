#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=miwifi-xthostlog
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/miwifi-xthostlog
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=miwifi-xthostlog
  DEPENDS:=@TARGET_ipq53xx +kmod-ipt-compat-xtables +kmod-miwifi-xthostset
endef

define Package/miwifi-xthostlog
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=TODO
  DEPENDS:=@TARGET_ipq53xx +kmod-miwifi-xthostlog
endef

define KernelPackage/miwifi-xthostlog/install
  true
endef

define Package/miwifi-xthostlog/install
  true
endef

$(eval $(call KernelPackage,miwifi-xthostlog))
$(eval $(call BuildPackage,miwifi-xthostlog))
