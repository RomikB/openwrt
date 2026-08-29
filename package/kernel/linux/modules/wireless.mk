#
# Copyright (C) 2006-2021 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
#

WIRELESS_MENU:=Wireless Drivers

define KernelPackage/cfg80211-linux
  SUBMENU:=$(WIRELESS_MENU)
  TITLE:=cfg80211 - wireless configuration API
  DEPENDS:=@TARGET_ipq53xx_rd15
  KCONFIG:=CONFIG_CFG80211 \
	CONFIG_NL80211_TESTMODE=y \
	CONFIG_CFG80211_DEVELOPER_WARNINGS=n \
	CONFIG_CFG80211_REG_DEBUG=n \
	CONFIG_CFG80211_DEFAULT_PS=n \
	CONFIG_CFG80211_DEBUGFS=n \
	CONFIG_CFG80211_INTERNAL_REGDB=n \
	CONFIG_CFG80211_CRDA_SUPPORT=n \
	CONFIG_ATH_CARDS=n \
	CONFIG_MWIFIEX=n \
	CONFIG_WILC1000_DRIVER=n \
	CONFIG_CFG80211_WEXT=y
  FILES:=$(LINUX_DIR)/net/wireless/cfg80211.ko
  AUTOLOAD:=$(call AutoLoad,30,cfg80211)
endef

define KernelPackage/cfg80211-linux/description
cfg80211 is the Linux wireless LAN (802.11) configuration API.
endef

$(eval $(call KernelPackage,cfg80211-linux))
