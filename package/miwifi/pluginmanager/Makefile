#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=pluginmanager
PKG_VERSION:=1.1
PKG_RELEASE:=1.1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/pluginmanager
  SECTION:=data
  CATEGORY:=MiWiFi
  TITLE:=pluginmanager
  DEPENDS:=@TARGET_ipq53xx +libjson-c +libuci +libopenssl +libzip +libuuid +libcurl
endef

define Package/pluginmanager/install
  true
endef

$(eval $(call BuildPackage,pluginmanager))
