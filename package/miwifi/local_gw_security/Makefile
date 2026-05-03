#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=local_gw_security
PKG_RELEASE:=0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/local_gw_security
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=MIWIFI Gateway Security
  DEPENDS:=@TARGET_ipq53xx +kmod-ipt-compat-xtables +kmod-miwifi-xthostset
endef

define Package/local_gw_security
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=MIWIFI Gateway Security
  DEPENDS:=@TARGET_ipq53xx +kmod-local_gw_security
endef

define KernelPackage/local_gw_security/install
  true
endef

define Package/local_gw_security/install
  true
endef

$(eval $(call KernelPackage,local_gw_security))
$(eval $(call BuildPackage,local_gw_security))
