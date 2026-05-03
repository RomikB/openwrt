#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=athtestcmd
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/athtestcmd-lith
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=qcatestcmd command support for lithium
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/athtestcmd-lith/install
  true
endef

$(eval $(call BuildPackage,athtestcmd-lith))
