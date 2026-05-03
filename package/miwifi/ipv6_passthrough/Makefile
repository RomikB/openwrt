#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=ipv6_passthrough
PKG_VERSION:=1.0
PKG_RELEASE:=0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/passthrough
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=MiWiFi modules
  DEPENDS:=@TARGET_ipq53xx
  TITLE:=IPv6 Passthrough Kernel Module
endef

define Package/pconfig
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=IPv6 Passthrough util
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/pconfig/install
  true
endef

$(eval $(call KernelPackage,passthrough))
$(eval $(call BuildPackage,pconfig))
