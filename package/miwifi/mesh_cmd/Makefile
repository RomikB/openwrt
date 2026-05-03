#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=mesh_cmd
PKG_VERSION:=1.0
PKG_RELEASE:=a

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/mesh_cmd
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=mesh common commands.
  PKGARCH:=all
endef

define Package/mesh_cmd/install
  true
endef

$(eval $(call BuildPackage,mesh_cmd))
