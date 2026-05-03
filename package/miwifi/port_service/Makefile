#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=port_service
PKG_VERSION:=1
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/port_service
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=port service controller
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/port_service_game
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=game port function
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/port_service_lag
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=Link aggregation
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/port_service_media
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=IPTV and VOIP service
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/port_service_wandt
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=Auto wan port detect
  DEPENDS:=@TARGET_ipq53xx +libubox +libubus +libuci
endef

define Package/port_service/install
  true
endef

define Package/port_service_game/install
  true
endef

define Package/port_service_lag/install
  true
endef

define Package/port_service_media/install
  true
endef

define Package/port_service_wandt/install
  true
endef

$(eval $(call BuildPackage,port_service))
$(eval $(call BuildPackage,port_service_game))
$(eval $(call BuildPackage,port_service_lag))
$(eval $(call BuildPackage,port_service_media))
$(eval $(call BuildPackage,port_service_wandt))
