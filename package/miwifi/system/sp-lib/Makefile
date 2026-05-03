#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=sp-lib
PKG_VERSION:=1.1
PKG_RELEASE:=1.1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/sp-lib
  SECTION:=data
  CATEGORY:=MiWiFi
  TITLE:=Library to collect/convert stat points data
  DEPENDS:=+stat_points +busybox +logrotate
  PKGARCH:=all
endef

define Package/sp-lib/install
  true
endef

$(eval $(call BuildPackage,sp-lib))
