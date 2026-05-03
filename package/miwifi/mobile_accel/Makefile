#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=mobile_accel
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/mobile_accel
  SECTION:=data
  CATEGORY:=MiWiFi
  TITLE:=mobile_accel
  DEPENDS:=+iptables-mod-ipopt
  PKGARCH:=all
endef

define Package/mobile_accel/install
  true
endef

$(eval $(call BuildPackage,mobile_accel))
