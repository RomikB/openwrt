DTC_FLAGS :=

define Image/Prepare
	@echo "-=RB=-Image/Prepare: Cleaning up modules.builtin* for rd15"
	rm -f $(TARGET_DIR)/lib/modules/*/modules.builtin*
	rm -f $(KDIR)/target-dir-*/lib/modules/*/modules.builtin*
	rm -f $(KDIR)/root.*/lib/modules/*/modules.builtin*
	$(CP) $(LINUX_DIR)/vmlinux $(KDIR)/$(IMG_PREFIX)-vmlinux.elf
endef

define Device/Default
	DEVICE_VENDOR := Xiaomi
	DEVICE_MODEL := Router BE3600 (RD15)
	BLOCKSIZE := 128k
	PAGESIZE := 2048
	VID_HDR_OFFSET := 2048
	ROOTFS_NAME := ubi_rootfs
	IMAGES := factory.ubi
	IMAGE/factory.ubi := append-ubi
endef

define Device/xiaomi-rd15-prebuild
	DEVICE_TITLE := Xiaomi BE3600 (prebuild kernel)
	KERNEL := copy-file $(TOPDIR)/target/linux/ipq53xx/rd15/kernel
	UBINIZE_PARTS := kernel=:$(TOPDIR)/target/linux/ipq53xx/rd15/kernel
	DEVICE_PACKAGES := nvram-vendor
endef
TARGET_DEVICES += xiaomi-rd15-prebuild

define Device/xiaomi-rd15-qsdk
	DEVICE_TITLE := Xiaomi BE3600 (native QSDK kernel)
	DEVICE_DTS := ipq5332-rd15
	DEVICE_DTS_DIR := $(TOPDIR)/target/linux/ipq53xx/rd15
	DEVICE_DTS_DELIMITER := @
	DEVICE_DTS_CONFIG := config@1
	KERNEL_LOADADDR := 0x40008000
	KERNEL_ENTRY := 0x40008000
	KERNEL := kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(DEVICE_DTS).dtb
	UBINIZE_PARTS := kernel=:$(KDIR)/$$(DEVICE_NAME)-kernel.bin
	DEVICE_PACKAGES := uboot-envtools
endef
TARGET_DEVICES += xiaomi-rd15-qsdk
