#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=tz2localtime
PKG_VERSION:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/tz2localtime
  SECTION:=TimeUtil
  CATEGORY:=MiWiFi
  TITLE:=Module to monitor /tmp/TZ and transform TZ info to localtime.
  PKGARCH:=all
endef

define Package/tz2localtime/install
  true
endef

$(eval $(call BuildPackage,tz2localtime))
