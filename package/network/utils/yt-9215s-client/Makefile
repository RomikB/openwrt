include $(TOPDIR)/rules.mk

PKG_NAME:=yt-9215s-client
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/yt-9215s-client
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Motorcomm YT9215S Switch Control Utility
  DEPENDS:=@TARGET_ipq53xx_rd15
endef

define Package/yt-9215s-client/description
  Open-source CLI control utility (switch_ctl) for Motorcomm YT9215S switch on Xiaomi Router BE3600 (RD15).
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Package/yt-9215s-client/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/switch_ctl $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,yt-9215s-client))
