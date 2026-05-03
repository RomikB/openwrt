#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libwifisoncfg
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/libwifisoncfg
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=This Package contains the WiFi-SON Configuration layer support
  DEPENDS:=@TARGET_ipq53xx +qca-cfg80211 +libhyficommon +libnl
endef

define Package/libwifisoncfg/install
  true
endef

$(eval $(call BuildPackage,libwifisoncfg))
