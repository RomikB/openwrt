#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-sfe
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-nss-sfe
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  DEPENDS:=@TARGET_ipq53xx +kmod-pppoe \
	   +TARGET_ipq53xx:kmod-qca-nss-ppe-rule
  TITLE:=Kernel data path for SFE
endef

$(eval $(call KernelPackage,qca-nss-sfe))
