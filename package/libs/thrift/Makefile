#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=thrift
PKG_VERSION:=0.9.1
PKG_RELEASE:=1

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/libthrift
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=libthrift
  DEPENDS:=@TARGET_ipq53xx +libc +boost-system +libopenssl +libstdcpp +glib2
endef

define Package/libthriftnb
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=libthriftnb
  DEPENDS:=@TARGET_ipq53xx +libthrift +libevent2
endef

define Package/libthrift/install
  true
endef

define Package/libthriftnb/install
  true
endef

$(eval $(call BuildPackage,libthrift))
$(eval $(call BuildPackage,libthriftnb))
