#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lualogging
PKG_VERSION:=1
PKG_RELEASE:=1.3.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/lualogging
  SECTION:=lang
  CATEGORY:=MiWiFi
  TITLE:=lualogging
  DEPENDS:=@TARGET_ipq53xx +lua
endef

define Package/lualogging/install
  true
endef

$(eval $(call BuildPackage,lualogging))
