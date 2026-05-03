#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=boot_check
PKG_VERSION:=1
PKG_RELEASE:=1.1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/boot_check
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=check boot successfully?
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/boot_check/install
  true
endef

$(eval $(call BuildPackage,boot_check))
