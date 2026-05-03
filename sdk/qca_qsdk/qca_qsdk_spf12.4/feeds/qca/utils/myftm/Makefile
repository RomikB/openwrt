#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=myftm
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/myftm
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QTI myftm utils
  DEPENDS:=@TARGET_ipq53xx +libtcmd +librt +libnl +libathtestcmd +zlib
endef

define Package/myftm/install
  true
endef

$(eval $(call BuildPackage,myftm))
