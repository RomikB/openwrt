#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=xiaoqiang_sync
PKG_VERSION:=0.1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/xiaoqiang_sync
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=xiaomi Router sync with AP/LAN/RE replay
  DEPENDS:=@TARGET_ipq53xx +uci +libubus +libblobmsg-json +ubusd +libubox
endef

define Package/xiaoqiang_sync/install
  true
endef

$(eval $(call BuildPackage,xiaoqiang_sync))
