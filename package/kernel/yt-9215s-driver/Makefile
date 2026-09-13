include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=yt-9215s-driver
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/OpenEmbeddedBSP/motorcomm-yt9215-switch-sdk.git
PKG_SOURCE_DATE:=2025-05-25
PKG_SOURCE_VERSION:=d2c8d6fc721fdb7e04e815b4fe2a397a2817ee5e
PKG_MIRROR_HASH:=7e4b24d4eb0355e84cd71144571a29f1fb3b775907c343ae2ff5c471fa0b2f6c

include $(INCLUDE_DIR)/package.mk

define KernelPackage/yt-9215s-driver
  SUBMENU:=Network Devices
  TITLE:=Motorcomm YT9215S Switch Driver
  DEPENDS:=@TARGET_ipq53xx_rd15
  FILES:=$(PKG_BUILD_DIR)/switch_sdk/make/yt_switch.ko
  AUTOLOAD:=$(call AutoLoad,57,yt_switch)
endef

define KernelPackage/yt-9215s-driver/description
  Unified kernel module driver for Motorcomm YT9215S switch on Xiaomi Router BE3600 (RD15).
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	cp $(PKG_BUILD_DIR)/yt9215rb_mdio_driver/yt9215rb.* $(PKG_BUILD_DIR)/switch_sdk/core/drv/sw_ctrl/
	cd $(PKG_BUILD_DIR)/switch_sdk/make && ./build_kernel_module.sh
endef

define Build/Compile
	+$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)/switch_sdk/make" modules
endef

$(eval $(call KernelPackage,yt-9215s-driver))
