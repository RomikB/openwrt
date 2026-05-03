#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=xiaoqiang-util
PKG_VERSION:=1
PKG_RELEASE:=1.1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/xiaoqiang-util
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=OTA
  DEPENDS:=@TARGET_ipq53xx +base-files +luasocket +curl +librt +libuci +libmbedtls +libopenssl
endef

define Package/xiaoqiang-util/install
  true
endef

$(eval $(call BuildPackage,xiaoqiang-util))
