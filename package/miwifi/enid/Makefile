#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=enid
PKG_RELEASE:=0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/enid
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=MiWiFi Ethernet Neighbor Info Detect
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/enid
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=MiWiFi Ethernet Neighbor Info Detect
  DEPENDS:=@TARGET_ipq53xx +libubox
endef

define Package/enid/install
  true
endef


$(eval $(call KernelPackage,enid))
$(eval $(call BuildPackage,enid))
