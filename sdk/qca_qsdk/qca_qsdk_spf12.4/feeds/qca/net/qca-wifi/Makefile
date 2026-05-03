#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-wifi
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-wifi-lowmem-profile
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QCA Wireless LAN Driver
  DEPENDS:=@TARGET_ipq53xx +librt +kmod-cfg80211-linux +libroxml +libnl +qca-cfg80211 +kmod-qca-cnss +kmod-bonding +kmod-qca-nss-ppe-vp +kmod-qca-nss-ppe-ds
  PROVIDES:=kmod-qca-wifi
  VARIANT:=lowmem-profile
endef

$(eval $(call KernelPackage,qca-wifi-lowmem-profile))
