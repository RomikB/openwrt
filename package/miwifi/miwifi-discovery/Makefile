#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=miwifi-discovery
PKG_VERSION:=0

PKG_FORCE_PREBUILT:=y


define Package/miwifi-discovery
  SECTION:=miwifi
  CATEGORY:=MiWiFi
  TITLE:=MiWiFi new router discovery
  DEPENDS:=@TARGET_ipq53xx +libubus +libblobmsg-json +libubox +sp-lib +libnl +qca-cfg80211 +libmbedtls +kmod-qca-wifi +libjson-c
endef

define Package/miwifi-discovery/install
  true
endef


include $(INCLUDE_DIR)/package.mk

$(eval $(call BuildPackage,miwifi-discovery))
