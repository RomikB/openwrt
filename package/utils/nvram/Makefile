#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=nvram
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/nvram
  SECTION:=utils
  CATEGORY:=Base system
  TITLE:=nvram
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/nvram/description
  Prebuild package nvram.
endef

define Package/nvram/install
  true
endef

$(eval $(call BuildPackage,nvram))
