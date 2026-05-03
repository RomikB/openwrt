#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=nfnlq-extension
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/nfnlq-extension
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=nfnlq-extension
  DEPENDS:=@TARGET_ipq53xx +kmod-nf-conntrack +kmod-nfnetlink-queue
endef

define Package/nfnlq-extension
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=netfilter netlink queue miwifi extension
  DEPENDS:=@TARGET_ipq53xx +kmod-nfnlq-extension +libubus +libstdcpp +iptables-mod-nfqueue +firewall_cpp +libmnl
endef

define KernelPackage/nfnlq-extension/install
  true
endef

define Package/nfnlq-extension/install
  true
endef

$(eval $(call KernelPackage,nfnlq-extension))
$(eval $(call BuildPackage,nfnlq-extension))
