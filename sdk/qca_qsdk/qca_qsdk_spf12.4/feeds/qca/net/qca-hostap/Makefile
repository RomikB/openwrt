#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qca-hostap
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/qca-hostap
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=This package contains the IEEE 802.1x/WPA/EAP/RADIUS Authenticator.
  DEPENDS:=@TARGET_ipq53xx +libnl +libopenssl
endef

define Package/qca-hostapd-cli
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=This package contains a command line utility to control the IEEE 802.1x/WPA/EAP/RADIUS Authenticator.
  DEPENDS:=@TARGET_ipq53xx +librt +libnl +libopenssl
endef

define Package/qca-wpa-cli
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=WPA Supplicant command line interface
  DEPENDS:=@TARGET_ipq53xx +librt +libopenssl +libnl
endef

define Package/qca-wpa-supplicant
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=WPA Supplicant
  DEPENDS:=@TARGET_ipq53xx +libopenssl +libnl
endef

define Package/qca-hostap/install
  true
endef

define Package/qca-hostapd-cli/install
  true
endef

define Package/qca-wpa-cli/install
  true
endef

define Package/qca-wpa-supplicant/install
  true
endef

$(eval $(call BuildPackage,qca-hostap))
$(eval $(call BuildPackage,qca-hostapd-cli))
$(eval $(call BuildPackage,qca-wpa-cli))
$(eval $(call BuildPackage,qca-wpa-supplicant))
