#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=miwifi-mesh
PKG_VERSION:=1.0
PKG_RELEASE:=a

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/miwifi-mesh
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=miwifi-mesh daemon.
  DEPENDS:=+libiw +liblua +libopenssl +libjson-c +sp-lib +mesh_cmd
  PKGARCH:=all
endef

define Package/miwifi-mesh/install
  true
endef

$(eval $(call BuildPackage,miwifi-mesh))
