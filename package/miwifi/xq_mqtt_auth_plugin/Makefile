#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=xq_mqtt_auth_plugin
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/xq_mqtt_auth_plugin
  SECTION:=lib
  CATEGORY:=MiWiFi
  TITLE:=xiaomi auth plugin for mosquitto
  DEPENDS:=@TARGET_ipq53xx +libmosquitto-ssl +libopenssl
endef

define Package/xq_mqtt_auth_plugin/install
  true
endef

$(eval $(call BuildPackage,xq_mqtt_auth_plugin))
