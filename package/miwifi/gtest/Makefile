#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=gtest
PKG_VERSION:=1.7.0
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/gtest
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=gtest
  DEPENDS:=@TARGET_ipq53xx +libstdcpp
endef

define Package/gtest/install
  true
endef

$(eval $(call BuildPackage,gtest))
