include $(TOPDIR)/rules.mk

PKG_NAME:=qca-hostapd-cli
PKG_VERSION:=2022-09-19
PKG_RELEASE:=1

PKG_SOURCE:=hostapd-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=http://w1.fi/hostap.git
PKG_HASH:=0fdb06de719e7a6bdb25dfb9c30973ba79ea77268cd50f4e1819c84ac28c61de

PKG_BUILD_DIR:=$(BUILD_DIR)/hostapd-$(PKG_VERSION)

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
