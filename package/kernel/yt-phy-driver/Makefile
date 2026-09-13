#
# Copyright (C) 2026 OpenWrt.org
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=yt-phy-driver
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0+

include $(INCLUDE_DIR)/package.mk

define KernelPackage/yt-phy-driver
  SUBMENU:=Network Devices
  TITLE:=Motorcomm YT8821 2.5G Ethernet PHY Driver
  DEPENDS:=@TARGET_ipq53xx_rd15
  FILES:=$(PKG_BUILD_DIR)/yt_phy_module.ko
  AUTOLOAD:=$(call AutoLoad,57,yt_phy_module,1)
  KCONFIG:=
endef

define KernelPackage/yt-phy-driver/description
  Open-source PHYlib driver for Motorcomm YT8821 2.5Gbps Ethernet transceiver on Xiaomi Router BE3600 (RD15).
endef

define Build/Compile
	$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)" modules
endef

$(eval $(call KernelPackage,yt-phy-driver))
