#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=thrifttunnel
PKG_VERSION:=1
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/thrifttunnel
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=the utility tunnel to a thrift protocol based service
  DEPENDS:=@TARGET_ipq53xx +libstdcpp +libpthread +libthrift +boost-filesystem +libubus +ubusd
endef

define Package/thrifttunnel/install
  true
endef

$(eval $(call BuildPackage,thrifttunnel))
