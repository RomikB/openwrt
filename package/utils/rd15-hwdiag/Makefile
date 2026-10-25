include $(TOPDIR)/rules.mk

PKG_NAME:=rd15-hwdiag
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define Package/rd15-hwdiag
  SECTION:=utils
  CATEGORY:=Base system
  TITLE:=Hardware diagnostic collector and dual-boot auto-rollback for Xiaomi RD15
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/rd15-hwdiag/description
  Automatic hardware diagnostic and safety rollback tool for Xiaomi Router BE3600 (RD15).
  Runs on startup, collects comprehensive system, network, switch, wireless, MDIO,
  and PCIe diagnostics into /data, then safely reverts U-Boot rootfs boot slot and reboots.
endef

define Build/Compile
endef

define Package/rd15-hwdiag/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/rd15-hwdiag $(1)/etc/init.d/
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_BIN) ./files/sbin/rd15-hwdiag-run $(1)/sbin/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/rd15-hwdiag $(1)/etc/config/
	$(INSTALL_DIR) $(1)/lib/preinit
	$(INSTALL_BIN) ./files/lib/preinit/95_rd15_hwdiag $(1)/lib/preinit/
endef

$(eval $(call BuildPackage,rd15-hwdiag))
