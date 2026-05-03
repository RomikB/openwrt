#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qca-diag
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/qca-diag
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QCA Linux diag software
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/qca-diag/install
  true
endef

$(eval $(call BuildPackage,qca-diag))
