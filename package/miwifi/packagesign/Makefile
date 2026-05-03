#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=packagesign
PKG_VERSION:=1_0_0
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/packagesign
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=package sign tool
  DEPENDS:=@TARGET_ipq53xx +libstdcpp +libopenssl +gtest +boost-thread +boost-filesystem +libpthread
endef

define Package/packagesign/install
  true
endef

$(eval $(call BuildPackage,packagesign))
