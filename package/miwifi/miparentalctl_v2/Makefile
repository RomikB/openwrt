#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=miparentalctl_v2
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/miparentalctl_v2
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=miwifi storage service
  DEPENDS:=@TARGET_ipq53xx +firewall_cpp +libstdcpp +connattr-label +connattr-statistic +haohan_dpi +libubus +libuci +libsqlite3 +miwifi-xtcounter +miwifi-xthostset +iptables-mod-conntrack-extra
endef

define Package/miparentalctl_v2/install
  true
endef

$(eval $(call BuildPackage,miparentalctl_v2))
