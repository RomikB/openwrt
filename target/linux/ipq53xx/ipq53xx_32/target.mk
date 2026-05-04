
ARCH:=arm
SUBTARGET:=ipq53xx_32
BOARDNAME:=QTI IPQ53xx(32bit) based boards
CPU_TYPE:=cortex-a7

DEFAULT_PACKAGES += \
	uboot-envtools kmod-ata-core kmod-ata-ahci kmod-ata-ahci-platform kmod-usb3 \
	kmod-usb-phy-ipq5018 kmod-usb-dwc3-qcom-internal \
	uboot-2016-ipq5332 uboot-2016-ipq5332_tiny uboot-2016-ipq5332_tiny_nor -lk-ipq53xx \
	fwupgrade-tools

define Target/Description
	Build firmware image for IPQ53xx SoC devices.
endef
