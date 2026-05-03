#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=webpages
PKG_VERSION:=1.0
PKG_RELEASE:=a

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/webpages
  SECTION:=util
  CATEGORY:=MiWiFi
  TITLE:=webinit src code.
  DEPENDS:=@TARGET_ipq53xx +luci
endef

define Package/webpages/install
  true
endef

$(eval $(call BuildPackage,webpages))
