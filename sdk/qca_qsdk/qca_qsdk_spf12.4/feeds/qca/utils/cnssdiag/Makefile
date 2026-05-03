#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=cnssdiag
PKG_VERSION:=miwifi_git

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/cnssdiag
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QCA cnssdiag utils
  DEPENDS:=@TARGET_ipq53xx +qca-diag +libnl
endef

define Package/cnssdiag/install
  true
endef

$(eval $(call BuildPackage,cnssdiag))
