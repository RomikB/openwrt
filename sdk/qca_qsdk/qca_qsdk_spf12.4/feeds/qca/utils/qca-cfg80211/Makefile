#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qca-cfg80211
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/qca-cfg80211
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QCA cfg80211 utils
  DEPENDS:=@TARGET_ipq53xx +libnl +iw
endef

define Package/qca-cfg80211/install
  true
endef

$(eval $(call BuildPackage,qca-cfg80211))
