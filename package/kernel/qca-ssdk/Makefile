include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-ssdk
PKG_SOURCE_PROTO:=git

ifeq ($(call kernel_patchver_eq,5.4),1)
  # Qualcomm CodeLinaro QSDK 12.4 version for Linux 5.4 / IPQ53xx (Xiaomi RD15)
  PKG_RELEASE:=1
  PKG_LICENSE:=ISC GPL-2.0
  PKG_SOURCE_URL:=https://git.codelinaro.org/clo/qsdk/oss/lklm/qca-ssdk.git
  PKG_SOURCE_DATE:=2023-11-16
  PKG_SOURCE_VERSION:=2e8bf9963e3cbe530ae3fff23ad4f0cf3b03e613
  PKG_MIRROR_HASH:=97aae0b18255b62e744dcf4bbb0339203b95a1cc08e54d9193fc6659cbbaf63b
  PATCH_DIR:=./patches-5.4
else
  # Upstream OpenWrt 25 version for kernels 6.x / qualcommax
  PKG_RELEASE:=1
  PKG_SOURCE_URL:=https://github.com/openwrt/qca-ssdk.git
  PKG_SOURCE_DATE:=2025-05-30
  PKG_SOURCE_VERSION:=446db12b1fd3bca2e61e45cb01c4ad52cfddd95b
  PKG_MIRROR_HASH:=d7bf3b83b08c61801e3ee3fe6d18da19c8c774e87f94c494c01f80b52d279589
  PKG_FLAGS:=nonshared
  PKG_BUILD_PARALLEL:=1
  PKG_BUILD_FLAGS:=no-lto
  PATCH_DIR:=./patches
endif

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-ssdk-nohnat
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Qualcomm SSDK switch driver (nohnat)
  DEPENDS:=@TARGET_ipq53xx
  FILES:=$(PKG_BUILD_DIR)/build/bin/qca-ssdk.ko
  AUTOLOAD:=$(call AutoLoad,30,qca-ssdk)
endef

define KernelPackage/qca-ssdk-nohnat/Description
  Driver for Qualcomm Atheros switches (QSDK 12.4 no-HNAT for IPQ53xx/RD15).
endef

define KernelPackage/qca-ssdk-nohnat/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/qca-ssdk $(1)/etc/init.d/qca-ssdk
endef

define KernelPackage/qca-ssdk
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Devices
  TITLE:=Qualcomm SSDK switch driver
  DEPENDS:=@(TARGET_qualcommax)
  FILES:=$(PKG_BUILD_DIR)/qca-ssdk.ko
  AUTOLOAD:=$(call AutoLoad,30,qca-ssdk)
endef

define KernelPackage/qca-ssdk/Description
  Driver for Qualcomm Atheros switches.
endef

ifeq ($(call kernel_patchver_eq,5.4),1)

KERNEL_TOOLCHAIN_DIR:=$(TOPDIR)/staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel
KERNEL_TOOL_PATH:=$(KERNEL_TOOLCHAIN_DIR)/bin

QCASSDK_CONFIG_OPTS:= \
	TOOL_PATH=$(KERNEL_TOOL_PATH) \
	SYS_PATH=$(LINUX_DIR) \
	TOOLPREFIX=arm-openwrt-linux-muslgnueabi- \
	KVER=$(LINUX_VERSION) \
	ARCH=$(LINUX_KARCH) \
	TARGET_SUFFIX=$(CONFIG_TARGET_SUFFIX) \
	GCC_VERSION=7.5.0 \
	SoC=ipq53xx \
	CHIP_TYPE=MPPE \
	PTP_FEATURE=disable \
	MINI_SSDK=enable \
	IN_AQUANTIA_PHY=FALSE \
	IN_QCA803X_PHY=FALSE \
	IN_MALIBU_PHY=FALSE \
	CFLAGS="-I$(STAGING_DIR)/usr/include"

define Build/Compile
	rm -f $(PKG_BUILD_DIR)/src_list.dep
	+$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(QCASSDK_CONFIG_OPTS)) \
		LNX_MAKEOPTS='ARCH=$(LINUX_KARCH) CROSS_COMPILE=$(KERNEL_TOOL_PATH)/arm-openwrt-linux-muslgnueabi- CC=$(KERNEL_TOOL_PATH)/arm-openwrt-linux-muslgnueabi-gcc' \
		MODULE_TYPE=KSLIB \
		modules
endef

else

GCC_VERSION=$(shell echo "$(CONFIG_GCC_VERSION)" | sed 's/[^0-9.]*\([0-9.]*\).*/\1/')

LNX_CONFIG_OPTS = LNX_MAKEOPTS='$(KERNEL_MAKEOPTS)' PRJ_PATH=$(PKG_BUILD_DIR) MODULE_TYPE=KSLIB modules

EXTRA_CFLAGS:= \
	-fno-stack-protector \
	-Wno-missing-prototypes \
	-Wno-missing-declarations \
	-I$(STAGING_DIR)/usr/include

MAKE_FLAGS+= \
	TARGET_NAME=$(CONFIG_TARGET_NAME) \
	TOOL_PATH=$(firstword $(TOOLCHAIN_BIN_DIRS)) \
	SYS_PATH=$(LINUX_DIR) \
	TOOLPREFIX=$(TARGET_CROSS) \
	KVER=$(LINUX_VERSION) \
	ARCH=$(LINUX_KARCH) \
	TARGET_SUFFIX=$(CONFIG_TARGET_SUFFIX) \
	GCC_VERSION=$(GCC_VERSION) \
	EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
	SoC=$(CONFIG_TARGET_SUBTARGET) \
	SHELL="$(BASH)" \
	PTP_FEATURE=disable SWCONFIG_FEATURE=disable \
	ISISC_ENABLE=disable MHT_ENABLE=disable \
	IN_QCA803X_PHY=FALSE IN_QCA808X_PHY=FALSE \
	IN_MALIBU_PHY=FALSE IN_MP_PHY=FALSE \
	$(LNX_CONFIG_OPTS)

ifeq ($(CONFIG_TARGET_SUBTARGET), "ipq807x")
    MAKE_FLAGS+= CHIP_TYPE=HPPE
endif

ifeq ($(CONFIG_TARGET_SUBTARGET), "ipq60xx")
    MAKE_FLAGS+= CHIP_TYPE=CPPE \
                 IN_AQUANTIA_PHY=TRUE
endif

ifeq ($(CONFIG_TARGET_SUBTARGET), "ipq50xx")
    MAKE_FLAGS+= CHIP_TYPE=MP
endif
define Build/Compile
	+$(MAKE) $(PKG_JOBS) $(MAKE_FLAGS) -C $(PKG_BUILD_DIR) $(LNX_CONFIG_OPTS)
endef

endif

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/qca-ssdk
	$(INSTALL_DIR) $(1)/usr/include/qca-ssdk/api
	$(INSTALL_DIR) $(1)/usr/include/qca-ssdk/ref
	$(INSTALL_DIR) $(1)/usr/include/qca-ssdk/fal
	$(INSTALL_DIR) $(1)/usr/include/qca-ssdk/sal
	$(INSTALL_DIR) $(1)/usr/include/qca-ssdk/init
	$(CP) -rf $(PKG_BUILD_DIR)/include/api/sw_ioctl.h $(1)/usr/include/qca-ssdk/api
	if [ -f $(PKG_BUILD_DIR)/include/ref/ref_vsi.h ]; then \
		$(CP) -rf $(PKG_BUILD_DIR)/include/ref/ref_vsi.h $(1)/usr/include/qca-ssdk/ref/; \
	fi
	if [ -f $(PKG_BUILD_DIR)/include/ref/ref_fdb.h ]; then \
		$(CP) -rf $(PKG_BUILD_DIR)/include/ref/ref_fdb.h $(1)/usr/include/qca-ssdk/ref/; \
	fi
	if [ -f $(PKG_BUILD_DIR)/include/ref/ref_port_ctrl.h ]; then \
		$(CP) -rf $(PKG_BUILD_DIR)/include/ref/ref_port_ctrl.h $(1)/usr/include/qca-ssdk/ref/; \
	fi
	if [ -f $(PKG_BUILD_DIR)/include/init/ssdk_init.h ]; then \
		$(CP) -rf $(PKG_BUILD_DIR)/include/init/ssdk_init.h $(1)/usr/include/qca-ssdk/init/; \
	fi
	if [ -f $(PKG_BUILD_DIR)/include/init/ssdk_netlink.h ]; then \
		$(CP) -rf $(PKG_BUILD_DIR)/include/init/ssdk_netlink.h $(1)/usr/include/qca-ssdk/init/; \
	fi
	$(CP) -rf $(PKG_BUILD_DIR)/include/fal $(1)/usr/include/qca-ssdk
	$(CP) -rf $(PKG_BUILD_DIR)/include/common/*.h $(1)/usr/include/qca-ssdk
	$(CP) -rf $(PKG_BUILD_DIR)/include/sal/os/linux/*.h $(1)/usr/include/qca-ssdk
	$(CP) -rf $(PKG_BUILD_DIR)/include/sal/os/*.h $(1)/usr/include/qca-ssdk
endef

$(eval $(call KernelPackage,qca-ssdk-nohnat))
$(eval $(call KernelPackage,qca-ssdk))
