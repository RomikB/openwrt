include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=pwm-rgb
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define KernelPackage/pwm-rgb
  SUBMENU:=LED modules
  TITLE:=Xiaomi PWM RGB LED driver
  DEPENDS:=@TARGET_ipq53xx_rd15
  FILES:=$(PKG_BUILD_DIR)/pwm-rgb.ko
  AUTOLOAD:=$(call AutoLoad,60,pwm-rgb)
endef

define KernelPackage/pwm-rgb/description
  Kernel module driver for multi-channel PWM RGB LEDs on Xiaomi routers (BE3600 / RD15).
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(KERNEL_MAKE) M="$(PKG_BUILD_DIR)" modules
endef

$(eval $(call KernelPackage,pwm-rgb))
