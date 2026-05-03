#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-ssdk-shell
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/qca-ssdk-shell
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=Shell application for QCA SSDK
endef

define Package/qca-ssdk-shell/Description
  This package contains a qca-ssdk shell application for QCA chipset
endef

define Package/qca-ssdk-shell/install
	true
endef

$(eval $(call BuildPackage,qca-ssdk-shell))
