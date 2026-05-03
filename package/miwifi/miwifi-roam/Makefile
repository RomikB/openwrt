#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=miwifi-roam
PKG_VERSION:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/miwifi-roam
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=miwifi roam daemon.
  DEPENDS:=@TARGET_ipq53xx +libubus +libblobmsg-json +ubusd +libubox +libwifisoncfg +libhyficommon +sp-lib
endef

define Package/miwifi-roam/install
  true
endef

$(eval $(call BuildPackage,miwifi-roam))
