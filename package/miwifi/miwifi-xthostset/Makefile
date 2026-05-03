#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=miwifi-xthostset
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/miwifi-xthostset
  SUBMENU:=MiWiFi modules
  TITLE:=miwifi-xthostset
  DEPENDS:=@TARGET_ipq53xx +kmod-ipt-compat-xtables
endef

define Package/miwifi-xthostset
  SECTION:=miwifi
  CATEGORY:=MiWiFi
  TITLE:=miwifi-xthostset
  DEPENDS:=@TARGET_ipq53xx +kmod-miwifi-xthostset
endef

define KernelPackage/miwifi-xthostset/install
  true
endef

define Package/miwifi-xthostset/install
  true
endef

$(eval $(call KernelPackage,miwifi-xthostset))
$(eval $(call BuildPackage,miwifi-xthostset))
