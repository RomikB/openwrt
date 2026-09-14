include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-cnss
PKG_SOURCE_URL:=https://git.codelinaro.org/clo/qsdk/oss/wifi/qca-cnss.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_DATE:=2023-11-16
PKG_SOURCE_VERSION:=17fe2f6321ea1cf5f0ff83339d9b0057988beb13
PKG_MIRROR_HASH:=9d4f549c7b9866ca004708cecb44a0729f015d0f160447a8371b3eeaf6c02034
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-cnss
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Wireless Drivers
  TITLE:=Qualcomm Atheros CNSS driver
  DEPENDS:=@TARGET_ipq53xx
  FILES:=$(PKG_BUILD_DIR)/ipq_cnss2.ko
endef

define KernelPackage/qca-cnss/description
  Platform bus driver for Qualcomm Atheros PCIe/AHB Wi-Fi devices.
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/qca-cnss
	$(CP) $(PKG_BUILD_DIR)/include/cnss2.h $(1)/usr/include/qca-cnss/
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) $(PKG_BUILD_DIR)/include/cnss2.h $(1)/usr/include/
endef

CNSS_MAKE_OPTS:= \
	QCA_CNSS_PCI_SUPPORT=y \
	QCA_CNSS_DEBUG_SUPPORT=y \
	QCA_CNSS_LOWMEM_PROFILE=y \
	ENABLE_QCA5332_HEADER=y \
	QCA_CNSS_KERNEL_DEPENDENCY=y

define Build/Compile
	+$(KERNEL_MAKE) $(PKG_JOBS) $(strip $(CNSS_MAKE_OPTS)) \
		M="$(PKG_BUILD_DIR)" \
		modules
endef

$(eval $(call KernelPackage,qca-cnss))
