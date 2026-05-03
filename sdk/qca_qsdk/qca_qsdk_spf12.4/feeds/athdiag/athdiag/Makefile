#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=athdiag
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/athdiag
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=athdiag command support for ath10k
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/athdiag/install
  true
endef

$(eval $(call BuildPackage,athdiag))
