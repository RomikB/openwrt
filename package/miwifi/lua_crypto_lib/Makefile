#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=lua_crypto_lib
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/lua_crypto_lib
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=lua rsa lib form polarssl
  DEPENDS:=@TARGET_ipq53xx +lua +librt +libmbedtls
endef

define Package/lua_crypto_lib/install
  true
endef

$(eval $(call BuildPackage,lua_crypto_lib))
