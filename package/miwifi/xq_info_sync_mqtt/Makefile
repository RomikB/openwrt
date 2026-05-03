#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=xq_info_sync_mqtt
PKG_VERSION:=0.3
PKG_RELEASE:=0.2

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/xq_info_sync_mqtt
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=xiaomi Router sync with AP/LAN/RE replay
  DEPENDS:=@TARGET_ipq53xx +uci +libubus +libblobmsg-json +ubusd +libubox +libmosquitto +zlib +libmbedtls +xq_mqtt_auth_plugin +sp-lib
endef

define Package/xq_info_sync_mqtt/install
  true
endef

$(eval $(call BuildPackage,xq_info_sync_mqtt))
