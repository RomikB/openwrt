#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=stat_points
PKG_VERSION:=2.3
PKG_RELEASE:=1.3

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/stat_points
  SECTION:=data
  CATEGORY:=MiWiFi
  TITLE:=Library to collect/convert stat points data
  DEPENDS:=@TARGET_ipq53xx +libcurl +lua +libjson-c +libmbedtls +libuci +milog
endef

define Package/stat_points/install
  true
endef

$(eval $(call BuildPackage,stat_points))
