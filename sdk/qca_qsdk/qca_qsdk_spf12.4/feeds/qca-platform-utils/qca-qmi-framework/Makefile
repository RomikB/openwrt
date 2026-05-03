#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=qca-qmi-framework
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/qca-qmi-framework
  SECTION:=qca
  CATEGORY:=QCA
  TITLE:=QCA Linux QMI framework software
  DEPENDS:=@TARGET_ipq53xx +libnl +libroxml +iw
endef

define Package/qca-qmi-framework/install
  true
endef

$(eval $(call BuildPackage,qca-qmi-framework))
