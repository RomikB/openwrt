#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=anti-attack
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/anti-attack
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=TODO
  DEPENDS:=@TARGET_ipq53xx +kmod-ipt-raw +kmod-ipt-raw6 +iptables-mod-hashlimit +iptables-mod-rpfilter +miwifi-xthostlog
endef

define Package/anti-attack/install
  true
endef

$(eval $(call BuildPackage,anti-attack))
