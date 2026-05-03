#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=miwifi-xtcounter
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/miwifi-xtcounter
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=miwifi-xtcounter
  DEPENDS:=@TARGET_ipq53xx +kmod-ipt-compat-xtables
endef

define Package/miwifi-xtcounter
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=TODO
  DEPENDS:=@TARGET_ipq53xx +kmod-miwifi-xtcounter
endef

define KernelPackage/miwifi-xtcounter/install
  true
endef

define Package/miwifi-xtcounter/install
  true
endef

$(eval $(call KernelPackage,miwifi-xtcounter))
$(eval $(call BuildPackage,miwifi-xtcounter))
