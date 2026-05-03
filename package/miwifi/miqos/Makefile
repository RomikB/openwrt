#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=miqos
PKG_VERSION:=1.1
PKG_RELEASE:=a

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/miqos
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=miqos
  DEPENDS:=@TARGET_ipq53xx +kmod-sched +tc +ip
  PKGARCH:=all
endef

define Package/miqos/description
  A script to do traffing shaping with the HTB algorithm.
  Wshaper attempts to:
  * Maintain low latency for interfactive traffic at all times
  * Allow 'surfing' at reasonable speeds while up or downloading
  * Make sure uploads don't harm downloads, and the other way around
endef

define Package/miqos/install
  true
endef

$(eval $(call BuildPackage,miqos))
