#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=ipv6-support-v2
PKG_VERSION:=2022-4-27
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/ipv6-support-v2
  SECTION:=ipv6
  CATEGORY:=MiWiFi
  TITLE:=ipv6-support-v2
  DEPENDS:=@TARGET_ipq53xx +ip6tables +odhcp6c
  PKGARCH:=all
endef

define Package/ipv6-support-v2/description
  This package provides basic IPv6 support including Router Discovery,
  DHCPv6 (client & server), prefix delegation and distribution.
endef

define Package/ipv6-support-v2/install
  true
endef

$(eval $(call BuildPackage,ipv6-support-v2))
