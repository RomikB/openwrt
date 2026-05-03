#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=xqled_v2
PKG_VERSION:=1
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/xqled_v2
  SECTION:=util
  CATEGORY:=MiWiFi
  TITLE:=New framework for miwifi led status controll.
  DEPENDS:=@TARGET_ipq53xx +libubus +libblobmsg-json +libubox +libjson-c
endef

define Package/xqled_v2/install
  true
endef

$(eval $(call BuildPackage,xqled_v2))
