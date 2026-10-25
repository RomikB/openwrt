include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=yt-921x-dsa
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define KernelPackage/yt-921x-dsa
  SUBMENU:=Network Devices
  TITLE:=Motorcomm YT921x DSA Switch Driver
  DEPENDS:=@TARGET_ipq53xx_ipq53xx_32
  FILES:= \
	$(PKG_BUILD_DIR)/yt921x.ko \
	$(PKG_BUILD_DIR)/tag_yt921x.ko
  AUTOLOAD:=$(call AutoLoad,58,tag_yt921x yt921x)
endef

define KernelPackage/yt-921x-dsa/description
  Open-source Distributed Switch Architecture (DSA) driver and frame tagger
  for Motorcomm YT9215 / YT921x switches on Xiaomi Router BE3600 (RD15/RD16).
endef

EXTRA_CFLAGS:= \
	-I$(srctree)/net/dsa \
	-I$(PKG_BUILD_DIR)

define Build/Compile
	+$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)" EXTRA_CFLAGS="$(EXTRA_CFLAGS)" modules
endef

$(eval $(call KernelPackage,yt-921x-dsa))
