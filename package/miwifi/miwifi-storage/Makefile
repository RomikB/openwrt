#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=miwifi-storage
PKG_VERSION:=1.0
PKG_RELEASE:=0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/miwifi-storage
  SECTION:=miwifi
  CATEGORY:=MiWiFi
  TITLE:=miwifi storage service
  DEPENDS:=@TARGET_ipq53xx +block-mount
endef

define Package/miwifi-storage/install
  true
endef

$(eval $(call BuildPackage,miwifi-storage))
