#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=connattr-statistic
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/connattr-statistic
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=connattr-statistic
  DEPENDS:=@TARGET_ipq53xx +kmod-conntrack-attr +kmod-ipt-compat-xtables
endef

define Package/connattr-statistic
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=TODO
  DEPENDS:=@TARGET_ipq53xx +kmod-connattr-statistic
endef

define KernelPackage/connattr-statistic/install
  true
endef

define Package/connattr-statistic/install
  true
endef

$(eval $(call KernelPackage,connattr-statistic))
$(eval $(call BuildPackage,connattr-statistic))
