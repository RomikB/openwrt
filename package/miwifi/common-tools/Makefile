#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=common-tools
PKG_VERSION:=1_0_0
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/common-tools
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=Some common tools
  DEPENDS:=@TARGET_ipq53xx +boost-thread
endef

define Package/common-tools/install
  true
endef

$(eval $(call BuildPackage,common-tools))
