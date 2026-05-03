#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=ftm
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/ftm
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QCA ftm utils
  DEPENDS:=@TARGET_ipq53xx +libnl +libtcmd +qca-diag +librt
endef

define Package/ftm/install
  true
endef

$(eval $(call BuildPackage,ftm))
