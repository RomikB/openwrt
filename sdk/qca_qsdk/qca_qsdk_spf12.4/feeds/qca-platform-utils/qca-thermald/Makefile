#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qca-thermald
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/qca-thermald
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=This package is IPQ Thermal Mitigation daemon.
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/qca-thermald/install
  true
endef

$(eval $(call BuildPackage,qca-thermald))
