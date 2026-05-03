#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk

PKG_NAME:=messagingagent
PKG_VERSION:=1.3
PKG_RELEASE:=1.2

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define Package/messagingagent
  SECTION:=opt
  CATEGORY:=MiWiFi
  TITLE:=messaging agent
  DEPENDS:=@TARGET_ipq53xx +libcurl +libstdcpp +librt +zlib +libubus +libblobmsg-json +libjson-c +libmbedtls +libev +libopenssl
endef

define Package/messagingagent/install
  true
endef

$(eval $(call BuildPackage,messagingagent))
