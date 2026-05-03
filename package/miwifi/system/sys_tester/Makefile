#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=sys_tester
PKG_VERSION:=2.0
PKG_RELEASE:=1.1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/sys_tester
  SECTION:=data
  CATEGORY:=MiWiFi
  TITLE:=sys_tester
  DEPENDS:=@TARGET_ipq53xx +kmod-mtdtests
endef

define Package/sys_tester/install
  true
endef

$(eval $(call BuildPackage,sys_tester))
