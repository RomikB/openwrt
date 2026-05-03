#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qca-firmware
PKG_VERSION:=0
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/qca-firmware
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QCA Wifi Firmware
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/qca-firmware/install
  true
endef

$(eval $(call BuildPackage,qca-firmware))
