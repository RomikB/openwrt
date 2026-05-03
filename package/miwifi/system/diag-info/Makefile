#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=diag-info
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/diag-info
  SECTION:=data
  CATEGORY:=MiWiFi
  TITLE:=Tool to collect diagnose informations
  DEPENDS:=+base-files
  PKGARCH:=all
endef

define Package/diag-info/install
  true
endef

$(eval $(call BuildPackage,diag-info))
