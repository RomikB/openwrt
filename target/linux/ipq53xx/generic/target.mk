
SUBTARGET:=generic
BOARDNAME:=QTI IPQ53xx(64bit) based boards
CPU_TYPE:=cortex-a53
KERNELNAME:=Image dtbs

DEFAULT_PACKAGES += \
	uboot-envtools kmod-ata-core kmod-ata-ahci kmod-ata-ahci-platform kmod-usb3 \
	kmod-usb-phy-ipq5018 kmod-usb-dwc3-qcom-internal sysupgrade-helper

define Target/Description
	Build images for IPQ53xx 64 bit system.
endef
