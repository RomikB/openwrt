#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-nss-ecm
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/qca-nss-ecm-premium
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  DEPENDS:=@TARGET_ipq53xx +iptables-mod-extra +kmod-ipt-conntrack +kmod-vxlan \
        +kmod-pppoe +kmod-miwifi-skb-mark +kmod-qca-mcs +kmod-nat46 \
        +kmod-l2tp +kmod-pppol2tp +kmod-pptp +kmod-qca-nss-sfe +kmod-qca-nss-ppe \
        +kmod-qca-nss-ppe-vxlanmgr +kmod-bonding +kmod-emesh-sp
  TITLE:=QCA NSS Enhanced Connection Manager (ECM) (with premium features)
  PROVIDES:=kmod-qca-nss-ecm
  VARIANT:=premium
endef

define KernelPackage/qca-nss-ecm-wifi-plugin
  SECTION:=kernel
  CATEGORY:=Kernel modules
  SUBMENU:=Network Support
  TITLE:= (with no-nss for host mode) (with no-nss for host mode)
  DEPENDS:=@TARGET_ipq53xx +kmod-qca-wifi +kmod-qca-nss-ecm
endef

$(eval $(call KernelPackage,qca-nss-ecm-premium))
$(eval $(call KernelPackage,qca-nss-ecm-wifi-plugin))
