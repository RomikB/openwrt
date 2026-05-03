#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=miwifi-relay
PKG_VERSION:=1.0
PKG_RELEASE:=a

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/miwifi-relay
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=A script to do iot onboarding relay.
  DEPENDS:=@TARGET_ipq53xx +libjson-c +libiw +libmbedtls +libuci
  PKGARCH:=all
endef

define Package/miwifi-relay/install
  true
endef

$(eval $(call BuildPackage,miwifi-relay))
