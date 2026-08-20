include $(TOPDIR)/rules.mk

ARCH:=aarch64
BOARD:=ipq53xx
BOARDNAME:=Qualcomm Technologies, Inc IPQ53xx
FEATURES:=ubifs squashfs fpu ramdisk nand pcie usbgadget
CPU_TYPE:=cortex-a53
CPU_SUBTYPE:=neon-vfpv4
MAINTAINER:=John Crispin <blogic@openwrt.org>
SUBTARGETS:=generic ipq53xx_32 rd15

KERNELNAME:=zImage Image dtbs

KERNEL_PATCHVER:=6.6

include $(INCLUDE_DIR)/target.mk

$(eval $(call BuildTarget))
