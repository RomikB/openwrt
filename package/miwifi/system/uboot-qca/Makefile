#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=uboot-qca
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/uboot-2016-ipq5332
  SECTION:=data
  CATEGORY:=MiWiFi
  TITLE:=U-boot for IPQ5332 based platforms
  DEPENDS:=@TARGET_ipq53xx +xiaoqiang-util
endef

define Package/uboot-2016-ipq5332/install
  true
endef

$(eval $(call BuildPackage,uboot-2016-ipq5332))
