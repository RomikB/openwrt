#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=iwevent-call
PKG_VERSION:=0.0.1
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/iwevent-call
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=This package is used for listen wireless event
  DEPENDS:=@TARGET_ipq53xx +wireless-tools
endef

define Package/iwevent-call/install
  true
endef

$(eval $(call BuildPackage,iwevent-call))
