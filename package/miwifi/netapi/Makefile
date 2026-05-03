#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=netapi
PKG_VERSION:=2.0
PKG_RELEASE:=1.1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/netapi
  SECTION:=data
  CATEGORY:=MiWiFi
  TITLE:=netapi
  DEPENDS:=@TARGET_ipq53xx +libcurl +liblua +libjson-c +libuci +libubus
endef

define Package/netapi/install
  true
endef

$(eval $(call BuildPackage,netapi))
