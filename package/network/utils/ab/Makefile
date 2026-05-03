#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=ab
PKG_VERSION:=1.3.42
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/ab
  SECTION:=net
  CATEGORY:=Network
  TITLE:=ab
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/ab/description
  Prebuild package ab.
endef

define Package/ab/install
  true
endef

$(eval $(call BuildPackage,ab))
