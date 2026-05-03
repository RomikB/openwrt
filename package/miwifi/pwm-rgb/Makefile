#
# Copyright (C) 2026 RomikB <romikb@mail.ru>
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=pwm-rgb
PKG_VERSION:=1.0
PKG_RELEASE:=1.0

PKG_FORCE_PREBUILT:=y

include $(INCLUDE_DIR)/package.mk

define KernelPackage/pwm-rgb
  SECTION:=kernel
  SUBMENU:=MiWiFi modules
  TITLE:=RGB controled by pwm
  DEPENDS:=@TARGET_ipq53xx
endef

define KernelPackage/pwm-rgb/install
  true
endef

$(eval $(call KernelPackage,pwm-rgb))
