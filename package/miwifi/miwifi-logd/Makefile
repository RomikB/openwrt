#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=miwifi-logd
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/miwifi-logd
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=TODO
  DEPENDS:=@TARGET_ipq53xx +libstdcpp +libsqlite3 +libubus +libblobmsg-json
endef

define Package/miwifi-logd/install
  true
endef

$(eval $(call BuildPackage,miwifi-logd))
