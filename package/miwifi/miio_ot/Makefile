#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=miio_ot
PKG_VERSION:=0.1
PKG_RELEASE:=0.1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/miio_ot
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=miot ot for connect to mijia
  DEPENDS:=@TARGET_ipq53xx +libubus +libblobmsg-json +libjson-c
endef

define Package/miio_ot/install
  true
endef

$(eval $(call BuildPackage,miio_ot))
