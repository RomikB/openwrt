#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-ppe-clients
PKG_VERSION:=miwifi_git
PKG_RELEASE:=2

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-nss-ppe-bridge-mgr
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Kernel driver for NSS PPE bridge manager
  DEPENDS:=@TARGET_ipq53xx \
		+kmod-qca-nss-ppe \
		+kmod-qca-nss-ppe-vlan-mgr \
		+PACKAGE_kmod-bonding:kmod-bonding
endef

define KernelPackage/qca-nss-ppe-vlan-mgr
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Kernel driver for NSS PPE vlan manager
  DEPENDS:=@TARGET_ipq53xx \
		+kmod-qca-nss-ppe \
		+kmod-qca-nss-ppe-vp \
		+PACKAGE_kmod-bonding:kmod-bonding
endef

define KernelPackage/qca-nss-ppe-pppoe-mgr
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Kernel driver for NSS PPE PPPoE manager
  DEPENDS:=@TARGET_ipq53xx \
		+kmod-qca-nss-ppe \
		+kmod-pppoe @!LINUX_3_18 \
		+PACKAGE_kmod-bonding:kmod-bonding
endef

define KernelPackage/qca-nss-ppe-lag-mgr
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Kernel driver for NSS LAG manager
  DEPENDS:=@TARGET_ipq53xx \
		+kmod-qca-nss-ppe \
		+kmod-qca-nss-ppe-vlan-mgr \
		+kmod-bonding
endef

$(eval $(call KernelPackage,qca-nss-ppe-bridge-mgr))
$(eval $(call KernelPackage,qca-nss-ppe-vlan-mgr))
$(eval $(call KernelPackage,qca-nss-ppe-pppoe-mgr))
$(eval $(call KernelPackage,qca-nss-ppe-lag-mgr))
