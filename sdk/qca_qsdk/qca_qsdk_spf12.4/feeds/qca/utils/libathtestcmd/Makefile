#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libathtestcmd
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/libathtestcmd
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QTI libathtestcmd utils
  DEPENDS:=@TARGET_ipq53xx +libnl +libtcmd +libtlv2 +libtlvutil
endef

define Package/libathtestcmd/install
  true
endef

$(eval $(call BuildPackage,libathtestcmd))
