#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-nsm
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-nss-nsm
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  DEPENDS:=@TARGET_ipq53xx +kmod-qca-nss-sfe +kmod-qca-nss-ppe +kmod-qca-nss-dp
  TITLE:=Network Status Module
endef

define KernelPackage/qca-nss-nsm/install
	true
endef

$(eval $(call KernelPackage,qca-nss-nsm))
