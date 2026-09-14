include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-mcs
PKG_RELEASE:=1
PKG_LICENSE:=ISC GPL-2.0

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.codelinaro.org/clo/qsdk/oss/lklm/qca-mcs.git
PKG_SOURCE_DATE:=2024-02-07
PKG_SOURCE_VERSION:=2237266b6b234ca0c488437d82fb969026624ec3
PKG_MIRROR_HASH:=6dcc5e6b319f14d200324fc5de74f209bb0bf0271968f1ad9d9104fbd71e067c

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-mcs
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  TITLE:=QCA Multicast Snooping (MCS) driver
  DEPENDS:=@TARGET_ipq53xx
  FILES:=$(PKG_BUILD_DIR)/qca-mcs.ko
  AUTOLOAD:=$(call AutoLoad,52,qca-mcs)
endef

define KernelPackage/qca-mcs/Description
  Qualcomm Multicast Snooping and Forwarding acceleration driver for IPQ53xx/RD15.
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/qca-mcs
	$(CP) -rf $(PKG_BUILD_DIR)/*.h $(1)/usr/include/qca-mcs/
endef

define Build/Compile
	+$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)" \
		KERNELPATH="$(LINUX_DIR)" \
		CONFIG_SUPPORT_MLD=y \
		modules
endef

$(eval $(call KernelPackage,qca-mcs))
