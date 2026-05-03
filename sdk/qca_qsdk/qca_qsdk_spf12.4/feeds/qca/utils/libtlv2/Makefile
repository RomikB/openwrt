#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=libtlv2
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/libtlv2
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QTI libtlv2 utils
  DEPENDS:=@TARGET_ipq53xx +libnl
endef

define Package/libtlv2/install
  true
endef

$(eval $(call BuildPackage,libtlv2))
