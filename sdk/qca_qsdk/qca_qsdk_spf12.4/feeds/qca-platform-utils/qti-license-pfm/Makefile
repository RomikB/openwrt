#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qti-license-pfm
PKG_VERSION:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/qti-license-pfm
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=qti-license-pfm
endef

define Package/qti-license-pfm/description
  This package contains a license pfm init and upgrade which can be used
  internally by QTI to update the pfm license files
endef

define Package/qti-license-pfm/install
  true
endef

$(eval $(call BuildPackage,qti-license-pfm))
