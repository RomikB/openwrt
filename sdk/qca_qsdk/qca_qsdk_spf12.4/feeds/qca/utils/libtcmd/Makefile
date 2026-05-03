#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libtcmd
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/libtcmd
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QCA libtcmd utils
  DEPENDS:=@TARGET_ipq53xx +libnl
endef

define Package/libtcmd/install
  true
endef

$(eval $(call BuildPackage,libtcmd))
