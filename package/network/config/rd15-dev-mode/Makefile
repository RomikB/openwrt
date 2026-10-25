include $(TOPDIR)/rules.mk

PKG_NAME:=rd15-dev-mode
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define Package/rd15-dev-mode
  SECTION:=utils
  CATEGORY:=Base system
  TITLE:=Xiaomi Router BE3600 (RD15) Developer Mode Config & Tools
  DEPENDS:=@TARGET_ipq53xx +iperf3 +htop +tcpdump
endef

define Package/rd15-dev-mode/description
  Developer configuration profile for Xiaomi Router BE3600 (RD15).
  Enables WAN management access (SSH, HTTP, HTTPS, iperf3), brings debugging utilities,
  and includes the QSDK vendor Wi-Fi standalone test runner (wifi-stock-test).
endef

define Build/Compile
endef

define Package/rd15-dev-mode/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/* $(1)/etc/uci-defaults/
	$(INSTALL_DIR) $(1)/etc/profile.d
	$(INSTALL_DATA) ./files/etc/profile.d/99-rd15-dev.sh $(1)/etc/profile.d/
	$(INSTALL_DIR) $(1)/sbin
	$(INSTALL_BIN) ./files/sbin/wifi-stock-test $(1)/sbin/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/etc/config/wireless.stock $(1)/etc/config/
endef

define Package/rd15-dev-mode/prerm
#!/bin/sh
uci -q batch << 'EOF'
	delete firewall.allow_ssh_wan
	delete firewall.allow_http_wan
	delete firewall.allow_https_wan
	delete firewall.allow_iperf3_wan
	commit firewall
	set uhttpd.main.rfc1918_filter='1'
	commit uhttpd
EOF
/etc/init.d/firewall reload 2>/dev/null || true
/etc/init.d/uhttpd reload 2>/dev/null || true
exit 0
endef

$(eval $(call BuildPackage,rd15-dev-mode))
