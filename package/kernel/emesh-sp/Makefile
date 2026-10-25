include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=emesh-sp
PKG_RELEASE:=1
PKG_LICENSE:=ISC GPL-2.0

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.codelinaro.org/clo/qsdk/oss/lklm/emesh-sp.git
PKG_SOURCE_DATE:=2023-07-21
PKG_SOURCE_VERSION:=3de1a656130fe31aab27c08c7adeb2cfb9dac09d
PKG_MIRROR_HASH:=14cda6f3fad6e1320869d6afd8bd239661472d79235bd6e65f2a0ef5c5664638

include $(INCLUDE_DIR)/package.mk

define KernelPackage/emesh-sp
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  TITLE:=Qualcomm EasyMesh Service Prioritization (SP) driver
  DEPENDS:=@TARGET_ipq53xx
  KCONFIG:=CONFIG_NETFILTER=y CONFIG_BRIDGE_NETFILTER=y
  FILES:=$(PKG_BUILD_DIR)/emesh-sp.ko
  AUTOLOAD:=$(call AutoLoad,50,emesh-sp)
endef

define KernelPackage/emesh-sp/Description
  Qualcomm EasyMesh Service Prioritization kernel module for IPQ53xx/RD15.
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/emesh-sp
	$(CP) $(PKG_BUILD_DIR)/sp_api.h $(1)/usr/include/emesh-sp/
endef

define Build/Compile
	+$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)" \
		modules
endef

$(eval $(call KernelPackage,emesh-sp))
