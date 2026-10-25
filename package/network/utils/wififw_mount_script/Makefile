include $(TOPDIR)/rules.mk

PKG_NAME:=wififw_mount_script
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define Package/wififw_mount_script
  SECTION:=utils
  CATEGORY:=Base system
  TITLE:=QCA Wi-Fi firmware mount and crashdump scripts
  DEPENDS:=@TARGET_ipq53xx +qca-wifi-scripts
endef

define Package/wififw_mount_script/description
  Scripts for early QCA Wi-Fi calibration loading and DSP crash dump collection.
endef

define Build/Compile
endef

define Package/wififw_mount_script/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/hotplug.d/dump
	$(INSTALL_DIR) $(1)/etc/hotplug.d/dump_q6v5
	$(INSTALL_BIN) ./files/etc/init.d/wifi_fw_mount $(1)/etc/init.d/
	$(INSTALL_BIN) ./files/etc/init.d/wifi_fw_done $(1)/etc/init.d/
	$(INSTALL_BIN) ./files/etc/hotplug.d/dump_q6v5/00-q6dump $(1)/etc/hotplug.d/dump_q6v5/
	$(LN) /etc/hotplug.d/dump_q6v5/00-q6dump $(1)/etc/hotplug.d/dump/00-q6dump
endef

$(eval $(call BuildPackage,wififw_mount_script))
