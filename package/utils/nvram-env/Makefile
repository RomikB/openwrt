include $(TOPDIR)/rules.mk

PKG_NAME:=nvram-env
PKG_RELEASE:=1

PKG_BUILD_DIR := $(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/nvram-env
  SECTION:=utils
  CATEGORY:=Base system
  TITLE:=Drop-in C replacement for nvram and bdata tools via uboot-envtools
  DEPENDS:=+uboot-envtools
  PROVIDES:=nvram-vendor
endef

define Package/nvram-env/description
  Drop-in C replacement for stock Xiaomi/Broadcom nvram and bdata utilities.
  Provides /usr/sbin/nvram and /usr/sbin/bdata with in-memory tmpfs caching
  and commits back to U-Boot environment partitions using uboot-envtools.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS) -Wall" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Package/nvram-env/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/nvram-env $(1)/usr/sbin/
	$(LN) nvram-env $(1)/usr/sbin/nvram
	$(LN) nvram-env $(1)/usr/sbin/bdata
endef

$(eval $(call BuildPackage,nvram-env))
