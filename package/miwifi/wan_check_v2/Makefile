#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=wan_check_v2
PKG_VERSION:=1.1
PKG_RELEASE:=1.1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/wan_check_v2
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=wan_check_v2
  DEPENDS:=@TARGET_ipq53xx +kmod-nf-conntrack
endef

define Package/wan_check_v2
  SECTION:=util
  CATEGORY:=MiWiFi
  TITLE:=Check status of net and port, then light the led.
  DEPENDS:=@TARGET_ipq53xx +libubus +libuci +xqled_v2 +kmod-wan_check_v2
endef

define Package/wan_check_v2/install
  true
endef

$(eval $(call KernelPackage,wan_check_v2))
$(eval $(call BuildPackage,wan_check_v2))
