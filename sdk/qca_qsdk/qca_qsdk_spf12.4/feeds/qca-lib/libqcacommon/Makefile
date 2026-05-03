#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libqcacommon
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/libhyficommon
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=This Package contains the Hy-Fi Common Functionality Library
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/libhyficommon/install
  true
endef

$(eval $(call BuildPackage,libhyficommon))
