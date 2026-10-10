include $(TOPDIR)/rules.mk

PKG_NAME:=qca-hostapd-cli
PKG_RELEASE:=1

PKG_SOURCE_URL:=https://w1.fi/hostap.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_DATE:=2022-09-16
PKG_SOURCE_VERSION:=01944c0957ba20ee1790eb2473cc5970f8b1f17e
PKG_MIRROR_HASH:=53b80142fd6aaaaf385707c9bc8ba447b4f6634a9d64e9e5b8529c79e6dece1c
PKG_SOURCE_SUBDIR:=hostapd-2022.09.16~01944c09
PKG_SOURCE:=hostapd-2022.09.16~01944c09.tar.zst

PKG_BUILD_DIR:=$(BUILD_DIR)/hostapd-2022.09.16~01944c09

include $(INCLUDE_DIR)/package.mk

define Package/qca-hostapd-cli
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Wireless
  TITLE:=Qualcomm hostapd_cli utility and control scripts
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/qca-hostapd-cli/description
  Native hostapd_cli utility with Qualcomm-specific extensions and scripts
  (hapd, wpsd, wps and dpp helpers) for IPQ53xx platforms.
endef

define Build/Configure
	cp $(PKG_BUILD_DIR)/hostapd/defconfig $(PKG_BUILD_DIR)/hostapd/.config
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/hostapd \
		$(TARGET_CONFIGURE_OPTS) \
		EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
		LIBS="$(TARGET_LDFLAGS)" \
		hostapd_cli
endef

define Package/qca-hostapd-cli/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/hostapd/hostapd_cli $(1)/usr/sbin/
	$(if $(wildcard ./files/*),$(CP) ./files/* $(1)/)
endef

$(eval $(call BuildPackage,qca-hostapd-cli))
