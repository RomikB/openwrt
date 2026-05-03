#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=topology_monitor_v2
PKG_VERSION:=1.0
PKG_RELEASE:=a

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/topology_monitor_v2
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=xiaomi mesh topology monitor.
  DEPENDS:=+libubus +libblobmsg-json +ubusd +libubox +libiw +libuci +libpthread +sp-lib
  PKGARCH:=all
endef

define Package/topology_monitor_v2/install
  true
endef

$(eval $(call BuildPackage,topology_monitor_v2))
