include $(TOPDIR)/rules.mk

PKG_NAME:=qca-wpa-cli
PKG_RELEASE:=1

PKG_SOURCE_URL:=https://w1.fi/hostap.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_DATE:=2022-09-16
PKG_SOURCE_VERSION:=01944c0957ba20ee1790eb2473cc5970f8b1f17e
PKG_MIRROR_HASH:=53b80142fd6aaaaf385707c9bc8ba447b4f6634a9d64e9e5b8529c79e6dece1c
PKG_SOURCE_SUBDIR:=hostapd-2022.09.16~01944c09
PKG_SOURCE:=hostapd-2022.09.16~01944c09.tar.zst

PKG_BUILD_DIR:=$(BUILD_DIR)/hostapd-wpa-cli-2022.09.16~01944c09

include $(INCLUDE_DIR)/package.mk

define Package/qca-wpa-cli
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Wireless
  TITLE:=Qualcomm wpa_cli utility and control scripts
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/qca-wpa-cli/description
  Native wpa_cli utility with Qualcomm-specific extensions and scripts
  (WPS button handlers and UCI helpers) for IPQ53xx platforms.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	tar -C $(PKG_BUILD_DIR) --strip-components=1 -xf $(DL_DIR)/$(PKG_SOURCE)
	$(Build/Patch)
endef

define Build/Configure
	cp $(PKG_BUILD_DIR)/wpa_supplicant/defconfig $(PKG_BUILD_DIR)/wpa_supplicant/.config
	echo "CONFIG_PMKSA_CACHE_EXTERNAL=y" >> $(PKG_BUILD_DIR)/wpa_supplicant/.config
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/wpa_supplicant \
		$(TARGET_CONFIGURE_OPTS) \
		EXTRA_CFLAGS="$(TARGET_CFLAGS)" \
		LIBS="$(TARGET_LDFLAGS)" \
		wpa_cli
endef

define Package/qca-wpa-cli/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/wpa_supplicant/wpa_cli $(1)/usr/sbin/
	$(if $(wildcard ./files/*),$(CP) ./files/* $(1)/)
endef

$(eval $(call BuildPackage,qca-wpa-cli))
