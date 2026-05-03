#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=firewall_cpp
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/firewall_cpp
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=TODO
  DEPENDS:=@TARGET_ipq53xx +libstdcpp +libubus +firewall
endef

define Package/firewall_cpp/install
  true
endef

$(eval $(call BuildPackage,firewall_cpp))
