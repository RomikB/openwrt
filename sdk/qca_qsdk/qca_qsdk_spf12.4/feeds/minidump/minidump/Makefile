#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=minidump
PKG_VERSION:=miwifi_git
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/minidump
  SECTION:=qti
  CATEGORY:=QTI
  TITLE:=QTI minidump
  DEPENDS:=@TARGET_ipq53xx
endef

define Package/minidump/install
  true
endef

$(eval $(call BuildPackage,minidump))
