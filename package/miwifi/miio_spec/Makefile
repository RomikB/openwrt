#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=miio_spec
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/miio_spec
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=miot spec realization
  DEPENDS:=@TARGET_ipq53xx +sp-lib
endef

define Package/miio_spec/install
  true
endef

$(eval $(call BuildPackage,miio_spec))
