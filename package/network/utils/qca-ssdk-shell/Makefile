include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=qca-ssdk-shell
PKG_RELEASE:=1

PKG_SOURCE_URL:=https://git.codelinaro.org/clo/qsdk/oss/ssdk-shell.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_DATE:=2023-11-23
PKG_SOURCE_VERSION:=5a3e1d6d72338d605e700cc083bf0f93e83d57cc
PKG_MIRROR_HASH:=f85aedeb0b109ec57ce8f9f8a389170abe5a3ad782ca58cabaf0e430ce189d9a

include $(INCLUDE_DIR)/package.mk

define Package/qca-ssdk-shell
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Routing and Redirection
  TITLE:=Shell application for Qualcomm SSDK
  DEPENDS:=@TARGET_ipq53xx +kmod-qca-ssdk-nohnat
endef

define Package/qca-ssdk-shell/description
  Shell application (ssdk_sh) for Qualcomm SSDK switch and PPE subsystem.
endef

QCASSDK_CONFIG_OPTS+= \
	TOOL_PATH=$(TOOLCHAIN_DIR)/bin \
	SYS_PATH=$(LINUX_DIR) \
	TOOLPREFIX=$(TARGET_CROSS) \
	KVER=$(LINUX_VERSION) \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	ARCH=$(LINUX_KARCH) \
	CPU=arm

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) $(strip $(QCASSDK_CONFIG_OPTS))
endef

define Package/qca-ssdk-shell/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/bin/ssdk_sh $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,qca-ssdk-shell))
