#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qca-cnss-daemon
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/qca-cnss-daemon
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QCA Linux QMI sotware
  DEPENDS:=@TARGET_ipq53xx +libnl +qca-qmi-framework
endef

define Package/qca-cnss-daemon/install
  true
endef

$(eval $(call BuildPackage,qca-cnss-daemon))
