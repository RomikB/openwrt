include $(TOPDIR)/rules.mk

PKG_NAME:=qca-wifi-scripts
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define Package/qca-wifi-scripts
  SECTION:=utils
  CATEGORY:=Base system
  TITLE:=QCA Wi-Fi board caldata and helper scripts
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/qca-wifi-scripts/description
  Scripts for QCA Wi-Fi calibration data extraction, interface setup and SMP affinity.
endef

define Build/Compile
endef

define Package/qca-wifi-scripts/install
	$(INSTALL_DIR) $(1)/lib/preinit
	$(INSTALL_BIN) ./files/lib/preinit/81_load_wifi_board_bin $(1)/lib/preinit/
	$(INSTALL_DATA) ./files/lib/create_cfg_caldata.sh $(1)/lib/
	$(INSTALL_DATA) ./files/lib/read_caldata_to_fs.sh $(1)/lib/
	$(INSTALL_DATA) ./files/lib/update_smp_affinity.sh $(1)/lib/
	$(INSTALL_DATA) ./files/lib/wifi_interface_helper.sh $(1)/lib/
endef

$(eval $(call BuildPackage,qca-wifi-scripts))
