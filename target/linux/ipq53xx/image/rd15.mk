define Image/Prepare
	@echo "-=RB=-Image/Prepare: Cleaning up modules.builtin* for rd15"
	rm -f $(TARGET_DIR)/lib/modules/*/modules.builtin*
	rm -f $(KDIR)/target-dir-*/lib/modules/*/modules.builtin*
	rm -f $(KDIR)/root.*/lib/modules/*/modules.builtin*
endef

define Image/BuildKernel
	@echo "-=RB=-Image/BuildKernel"
endef

define Image/BuildKernel/Initramfs
	@echo "-=RB=-Image/BuildKernel/Initramfs"
endef

define Device/xiaomi-rd15-prebuild
	DEVICE_VENDOR := Xiaomi
	DEVICE_MODEL := Router BE3600 (RD15)
	DEVICE_TITLE := Xiaomi BE3600 (prebuild kernel)
	KERNEL := copy-file $(TOPDIR)/target/linux/ipq53xx/rd15/kernel
	BLOCKSIZE := 128k
	PAGESIZE := 2048
	VID_HDR_OFFSET := 2048
	UBINIZE_PARTS := kernel=:$(TOPDIR)/target/linux/ipq53xx/rd15/kernel
	ROOTFS_NAME := ubi_rootfs
	IMAGES := factory.ubi
	IMAGE/factory.ubi := append-ubi
endef
TARGET_DEVICES += xiaomi-rd15-prebuild
