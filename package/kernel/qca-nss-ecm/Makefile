include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-ecm
PKG_RELEASE:=1
PKG_LICENSE:=ISC GPL-2.0

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://git.codelinaro.org/clo/qsdk/oss/lklm/qca-nss-ecm.git
PKG_SOURCE_DATE:=2023-11-15
PKG_SOURCE_VERSION:=aed84d4719a3d5c97a5394bb3e0e7f9dd7b5013d
PKG_MIRROR_HASH:=e987292c40042aa66d4b1395ef89874c12d9edd9730b6c1c2ce1ee992b4576fd

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-nss-ecm-premium
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  TITLE:=QCA NSS Enhanced Connection Manager (ECM Premium)
  DEPENDS:=@TARGET_ipq53xx \
	+kmod-ipt-conntrack \
	+kmod-vxlan \
	+kmod-pppoe \
	+kmod-qca-mcs \
	+kmod-nat46 \
	+kmod-l2tp \
	+kmod-pppol2tp \
	+kmod-pptp \
	+kmod-qca-nss-sfe \
	+kmod-qca-nss-ppe \
	+kmod-qca-nss-ppe-vxlanmgr \
	+kmod-bonding \
	+kmod-emesh-sp \
	+kmod-qca-nss-ppe-vp
  PROVIDES:=kmod-qca-nss-ecm
  FILES:= \
	$(PKG_BUILD_DIR)/ecm.ko \
	$(PKG_BUILD_DIR)/examples/ecm_sfe_l2.ko \
	$(PKG_BUILD_DIR)/examples/ecm_ae_select.ko
  KCONFIG:= \
	CONFIG_BRIDGE_NETFILTER=y \
	CONFIG_NF_CONNTRACK_EVENTS=y \
	CONFIG_NF_CONNTRACK_CHAIN_EVENTS=y \
	CONFIG_NF_CONNTRACK_DSCPREMARK_EXT=y
endef

define KernelPackage/qca-nss-ecm-premium/Description
  QCA NSS Enhanced Connection Manager (ECM Premium) with PPE + SFE acceleration for IPQ53xx/RD15.
endef

define KernelPackage/qca-nss-ecm-premium/install
	$(INSTALL_DIR) $(1)/etc/firewall.d $(1)/etc/init.d $(1)/usr/bin $(1)/lib/netifd/offload $(1)/etc/config $(1)/etc/uci-defaults $(1)/etc/sysctl.d
	$(INSTALL_DATA) ./files/etc/firewall.d/qca-nss-ecm $(1)/etc/firewall.d/qca-nss-ecm
	$(INSTALL_BIN) ./files/etc/init.d/qca-nss-ecm $(1)/etc/init.d/qca-nss-ecm
	$(INSTALL_BIN) ./files/usr/bin/ecm_dump.sh $(1)/usr/bin/
	$(INSTALL_BIN) ./files/lib/netifd/offload/on-demand-down $(1)/lib/netifd/offload/on-demand-down
	$(INSTALL_DATA) ./files/etc/config/ecm $(1)/etc/config/ecm
	$(INSTALL_DATA) ./files/etc/uci-defaults/99-qca-nss-ecm $(1)/etc/uci-defaults/99-qca-nss-ecm
	$(INSTALL_BIN) ./files/etc/sysctl.d/qca-nss-ecm.conf $(1)/etc/sysctl.d/qca-nss-ecm.conf
endef

define KernelPackage/qca-nss-ecm-wifi-plugin
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  TITLE:=QCA NSS ECM Wi-Fi plugin
  DEPENDS:=+kmod-qca-nss-ecm-premium +kmod-qca-wifi-lowmem-profile-vendor
  FILES:=$(PKG_BUILD_DIR)/ecm_wifi_plugins/ecm-wifi-plugin.ko
endef

define KernelPackage/qca-nss-ecm-wifi-plugin/Description
  QCA NSS ECM Wi-Fi plugin for FSE and MSCS classification.
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/include
	$(CP) ./include/* $(PKG_BUILD_DIR)/include/
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/qca-nss-ecm
	$(CP) $(PKG_BUILD_DIR)/exports/* $(1)/usr/include/qca-nss-ecm/
endef

ECM_MAKE_OPTS:= \
	SoC="ipq53xx" \
	ECM_FRONT_END_PPE_ENABLE=y \
	ECM_FRONT_END_SFE_ENABLE=y \
	ECM_MHT_ENABLE=y \
	ECM_INTERFACE_IPSEC_ENABLE=y \
	ECM_INTERFACE_PPTP_ENABLE=y \
	ECM_INTERFACE_L2TPV2_ENABLE=y \
	ECM_INTERFACE_GRE_TAP_ENABLE=y \
	ECM_INTERFACE_GRE_TUN_ENABLE=y \
	ECM_INTERFACE_SIT_ENABLE=y \
	ECM_INTERFACE_TUNIPIP6_ENABLE=y \
	ECM_INTERFACE_RAWIP_ENABLE=y \
	ECM_INTERFACE_BOND_ENABLE=y \
	ECM_INTERFACE_VXLAN_ENABLE=y \
	ECM_INTERFACE_MAP_T_ENABLE=y \
	ECM_MULTICAST_ENABLE=y \
	ECM_CLASSIFIER_EMESH_ENABLE=y \
	ECM_CLASSIFIER_MSCS_ENABLE=y \
	ECM_CLASSIFIER_MSCS_SCS_ENABLE=y \
	ECM_FRONT_END_FSE_ENABLE=y \
	ECM_IPV6_ENABLE=y \
	BUILD_ECM_WIFI_PLUGIN=y \
	KBUILD_MODPOST_WARN=1

EXTRA_CFLAGS+= \
	-I$(STAGING_DIR)/usr/include \
	-I$(STAGING_DIR)/usr/include/qca-nss-sfe \
	-I$(STAGING_DIR)/usr/include/qca-nss-ppe \
	-I$(STAGING_DIR)/usr/include/emesh-sp \
	-I$(STAGING_DIR)/usr/include/nat46 \
	-I$(STAGING_DIR)/usr/include/qca-mcs \
	-I$(PKG_BUILD_DIR)/include

define Build/Compile
	+$(KERNEL_MAKE) $(PKG_JOBS) $(strip $(ECM_MAKE_OPTS)) \
		M="$(PKG_BUILD_DIR)" \
		EXTRA_CFLAGS="$(EXTRA_CFLAGS)" \
		modules
endef

$(eval $(call KernelPackage,qca-nss-ecm-premium))
$(eval $(call KernelPackage,qca-nss-ecm-wifi-plugin))
