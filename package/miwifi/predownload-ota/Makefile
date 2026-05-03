#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=predownload-ota
PKG_VERSION:=1.1
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/predownload-ota
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=predownload-ota
  DEPENDS:=@TARGET_ipq53xx +xiaoqiang-util
endef

define Package/predownload-ota/install
  true
endef

$(eval $(call BuildPackage,predownload-ota))
