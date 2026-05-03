#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=trafficd
PKG_VERSION:=1.2
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/ipaccount2
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=ip account module
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/ipaccount2
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=ip account
  DEPENDS:=@TARGET_ipq53xx +libc +lua +libnl-tiny
endef

define Package/traffic2
  SECTION:=net
  CATEGORY:=MiWiFi
  TITLE:=traffic
  DEPENDS:=@TARGET_ipq53xx +libuci +jshn +iwinfo +lua +libblobmsg-json +libjson-c +ubus +ipaccount2
endef

define Package/ipaccount2/install
  true
endef

define Package/traffic2/install
  true
endef

$(eval $(call KernelPackage,ipaccount2))
$(eval $(call BuildPackage,ipaccount2))
$(eval $(call BuildPackage,traffic2))
