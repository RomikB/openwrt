DTC_FLAGS :=
PREBUILD_PACKAGES := nvram-vendor
QSDK_PACKAGES := uboot-envtools nvram-env
SECURITY_PACKAGES := \
	amneziawg-tools luci-proto-amneziawg \
	zapret2 luci-app-zapret2
RUANTIBLOCK_PACKAGES := \
	-dnsmasq dnsmasq-full \
	ruantiblock luci-app-ruantiblock \
	https-dns-proxy luci-app-https-dns-proxy \
	$(SECURITY_PACKAGES)
PODKOP_PACKAGES := \
	sing-box podkop luci-app-podkop \
	kmod-tcp-bbr \
	$(SECURITY_PACKAGES)
DEV_PACKAGES := \
	$(SECURITY_PACKAGES) \
	rd15-dev-mode iperf3 htop tcpdump

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
	DEVICE_PACKAGES := $(PREBUILD_PACKAGES)
endef
TARGET_DEVICES += xiaomi-rd15-prebuild

define Device/xiaomi-rd15-prebuild-ruantiblock
	DEVICE_TITLE := Xiaomi BE3600 (prebuild kernel, ruantiblock)
	KERNEL := copy-file $(TOPDIR)/target/linux/ipq53xx/rd15/kernel
	UBINIZE_PARTS := kernel=:$(TOPDIR)/target/linux/ipq53xx/rd15/kernel
	DEVICE_PACKAGES := $(PREBUILD_PACKAGES) $(RUANTIBLOCK_PACKAGES)
endef
TARGET_DEVICES += xiaomi-rd15-prebuild-ruantiblock

define Device/xiaomi-rd15-prebuild-podkop
	DEVICE_TITLE := Xiaomi BE3600 (prebuild kernel, podkop)
	KERNEL := copy-file $(TOPDIR)/target/linux/ipq53xx/rd15/kernel
	UBINIZE_PARTS := kernel=:$(TOPDIR)/target/linux/ipq53xx/rd15/kernel
	DEVICE_PACKAGES := $(PREBUILD_PACKAGES) $(PODKOP_PACKAGES)
endef
TARGET_DEVICES += xiaomi-rd15-prebuild-podkop

define Build/fit-rd15
	$(call locked,$(TOPDIR)/scripts/mkits.sh \
		-D $(DEVICE_NAME) -o $@.its -k $@ \
		-C $(word 1,$(1)) \
		$(if $(word 2,$(1)),\
			$(if $(findstring 11,$(if $(DEVICE_DTS_OVERLAY),1)$(if $(findstring $(KERNEL_BUILD_DIR)/image-,$(word 2,$(1))),,1)), \
				-d $(KERNEL_BUILD_DIR)/image-$$(basename $(word 2,$(1))), \
				-d $(word 2,$(1)))) \
		-a $(KERNEL_LOADADDR) -e $(if $(KERNEL_ENTRY),$(KERNEL_ENTRY),$(KERNEL_LOADADDR)) \
		$(if $(DEVICE_DTS_DELIMITER),-l $(DEVICE_DTS_DELIMITER)) \
		-c $(if $(DEVICE_DTS_CONFIG),$(DEVICE_DTS_CONFIG),"config-1") \
		-A $(LINUX_KARCH) -v $(LINUX_VERSION))
	sed -i '/kernel@1 {/a \\t\t\tmiwifirom = "1.0.81";' $@.its
	PATH=$(LINUX_DIR)/scripts/dtc:$(PATH) mkimage -f $@.its $@.new
	@mv $@.new $@
endef

define Device/xiaomi-rd15-qsdk
	DEVICE_TITLE := Xiaomi BE3600 (native QSDK kernel)
	DEVICE_DTS := ipq5332-rd15
	DEVICE_DTS_DIR := $(TOPDIR)/target/linux/ipq53xx/rd15
	DEVICE_DTS_DELIMITER := @
	DEVICE_DTS_CONFIG := config@1
	KERNEL_LOADADDR := 0x40008000
	KERNEL_ENTRY := 0x40008000
	KERNEL := kernel-bin | lzma | fit-rd15 lzma $$(KDIR)/image-$$(DEVICE_DTS).dtb
	UBINIZE_PARTS := kernel=:$(KDIR)/$$(DEVICE_NAME)-kernel.bin
	DEVICE_PACKAGES := $(QSDK_PACKAGES)
endef
TARGET_DEVICES += xiaomi-rd15-qsdk

define Device/xiaomi-rd15-qsdk-ruantiblock
	DEVICE_TITLE := Xiaomi BE3600 (native QSDK kernel, ruantiblock)
	DEVICE_DTS := ipq5332-rd15
	DEVICE_DTS_DIR := $(TOPDIR)/target/linux/ipq53xx/rd15
	DEVICE_DTS_DELIMITER := @
	DEVICE_DTS_CONFIG := config@1
	KERNEL_LOADADDR := 0x40008000
	KERNEL_ENTRY := 0x40008000
	KERNEL := kernel-bin | lzma | fit-rd15 lzma $$(KDIR)/image-$$(DEVICE_DTS).dtb
	UBINIZE_PARTS := kernel=:$(KDIR)/$$(DEVICE_NAME)-kernel.bin
	DEVICE_PACKAGES := $(QSDK_PACKAGES) $(RUANTIBLOCK_PACKAGES)
endef
TARGET_DEVICES += xiaomi-rd15-qsdk-ruantiblock

define Device/xiaomi-rd15-qsdk-podkop
	DEVICE_TITLE := Xiaomi BE3600 (native QSDK kernel, podkop)
	DEVICE_DTS := ipq5332-rd15
	DEVICE_DTS_DIR := $(TOPDIR)/target/linux/ipq53xx/rd15
	DEVICE_DTS_DELIMITER := @
	DEVICE_DTS_CONFIG := config@1
	KERNEL_LOADADDR := 0x40008000
	KERNEL_ENTRY := 0x40008000
	KERNEL := kernel-bin | lzma | fit-rd15 lzma $$(KDIR)/image-$$(DEVICE_DTS).dtb
	UBINIZE_PARTS := kernel=:$(KDIR)/$$(DEVICE_NAME)-kernel.bin
	DEVICE_PACKAGES := $(QSDK_PACKAGES) $(PODKOP_PACKAGES)
endef
TARGET_DEVICES += xiaomi-rd15-qsdk-podkop

define Device/xiaomi-rd15-qsdk-dev
	DEVICE_TITLE := Xiaomi BE3600 (native QSDK kernel, dev profile)
	DEVICE_DTS := ipq5332-rd15
	DEVICE_DTS_DIR := $(TOPDIR)/target/linux/ipq53xx/rd15
	DEVICE_DTS_DELIMITER := @
	DEVICE_DTS_CONFIG := config@1
	KERNEL_LOADADDR := 0x40008000
	KERNEL_ENTRY := 0x40008000
	KERNEL := kernel-bin | lzma | fit-rd15 lzma $$(KDIR)/image-$$(DEVICE_DTS).dtb
	UBINIZE_PARTS := kernel=:$(KDIR)/$$(DEVICE_NAME)-kernel.bin
	DEVICE_PACKAGES := $(QSDK_PACKAGES) $(DEV_PACKAGES)
endef
TARGET_DEVICES += xiaomi-rd15-qsdk-dev
