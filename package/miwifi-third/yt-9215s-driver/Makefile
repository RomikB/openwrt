#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=yt-9215s-driver
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/yt-9215s-driver
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=yt switch driver
  DEPENDS:=@TARGET_ipq53xx +kmod-bonding
endef

$(eval $(call KernelPackage,yt-9215s-driver))
