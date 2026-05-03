#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=smartcontroller_c
PKG_VERSION:=1
PKG_RELEASE:=1.2

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/smartcontroller_c
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=the smart controller c demaon
  DEPENDS:=@TARGET_ipq53xx +libubus +ubusd +glib2 +libjson-c
endef

define Package/smartcontroller_c/install
  true
endef

$(eval $(call BuildPackage,smartcontroller_c))
