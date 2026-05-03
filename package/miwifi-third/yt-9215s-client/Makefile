#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=yt-9215s-client
PKG_VERSION:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/yt-9215s-client
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=yt switch client
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/yt-9215s-client/install
  true
endef

$(eval $(call BuildPackage,yt-9215s-client))
