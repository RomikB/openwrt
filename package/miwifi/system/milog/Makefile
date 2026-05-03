#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=milog
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/milog
  SECTION:=data
  CATEGORY:=MiWiFi
  TITLE:=Log manager layer for XiaoQiang
  DEPENDS:=+syslog-ng +logrotate +diag-info
  PKGARCH:=all
endef

define Package/milog/install
  true
endef

$(eval $(call BuildPackage,milog))
