include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-sfe
PKG_RELEASE:=1
PKG_LICENSE:=ISC GPL-2.0

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.codelinaro.org/clo/qsdk/oss/lklm/shortcut-fe.git
PKG_SOURCE_DATE:=2024-03-20
PKG_SOURCE_VERSION:=7d82c7104fa14a84660b8c8caa4d824ef1784b7c
PKG_MIRROR_HASH:=98f9d25928b49d54ad52794312a261469a0b3e23618e608ad7c82886f6e7224c
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(subst -,.,$(PKG_SOURCE_DATE))~$(call version_abbrev,$(PKG_SOURCE_VERSION))
PKG_SOURCE:=$(PKG_SOURCE_SUBDIR).tar.zst

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-nss-sfe
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  TITLE:=Kernel data path for Shortcut FE (SFE)
  DEPENDS:=@TARGET_ipq53xx +kmod-pppoe +kmod-qca-nss-ppe-rule
  FILES:=$(PKG_BUILD_DIR)/qca-nss-sfe.ko
  KCONFIG:=CONFIG_NF_CONNTRACK_EVENTS=y
  AUTOLOAD:=$(call AutoLoad,09,qca-nss-sfe)
endef

define KernelPackage/qca-nss-sfe/Description
  Shortcut Forwarding Engine (SFE) fast path kernel module for IPQ53xx/RD15.
endef

define KernelPackage/qca-nss-sfe/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/sfe_dump $(1)/usr/bin/
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/qca-nss-sfe
	$(CP) -rf $(PKG_BUILD_DIR)/exports/* $(1)/usr/include/qca-nss-sfe/
endef

SFE_MAKE_OPTS:= \
	SFE_SUPPORT_IPV6=y \
	SFE_PROCESS_LOCAL_OUT=y \
	SFE_BRIDGE_VLAN_FILTERING_ENABLE=y \
	SFE_256M_PROFILE=y \
	SFE_RFS_SUPPORTED=y

EXTRA_CFLAGS+= \
	-I$(PKG_BUILD_DIR)/exports \
	-I$(STAGING_DIR)/usr/include/qca-nss-ppe \
	-DSFE_MEM_PROFILE_LOW \
	-DSFE_TSO_MAX_SEG_LIMIT_ENABLE

define Build/Compile
	+$(KERNEL_MAKE) $(PKG_JOBS) $(strip $(SFE_MAKE_OPTS)) \
		M="$(PKG_BUILD_DIR)" \
		EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
		modules
endef

$(eval $(call KernelPackage,qca-nss-sfe))
