#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=connattr-label
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/connattr-label
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=connattr-label
  DEPENDS:=@TARGET_ipq53xx +kmod-conntrack-attr +kmod-ipt-compat-xtables
endef

define Package/connattr-label
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=TODO
  DEPENDS:=@TARGET_ipq53xx +kmod-connattr-label
endef

define KernelPackage/connattr-label/install
  true
endef

define Package/connattr-label/install
  true
endef

$(eval $(call KernelPackage,connattr-label))
$(eval $(call BuildPackage,connattr-label))
