#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=yt-phy-driver
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/yt-phy-driver
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=motorcomm phy driver
  DEPENDS:=@TARGET_ipq53xx
endef

$(eval $(call KernelPackage,yt-phy-driver))
