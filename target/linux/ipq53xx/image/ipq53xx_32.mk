DTC_FLAGS :=
QSDK_PACKAGES := uboot-envtools nvram-env
SECURITY_PACKAGES := \
	amneziawg-tools luci-proto-amneziawg \
	zapret2 luci-app-zapret2
SINGBOX_PACKAGES := \
	sing-box \
	coreutils-base64 bind-dig \
	kmod-tcp-bbr \
	kmod-nft-tproxy kmod-nft-socket kmod-nft-nat \
	kmod-inet-diag kmod-netlink-diag kmod-tun \
	$(SECURITY_PACKAGES)
DEV_PACKAGES := \
	$(SECURITY_PACKAGES) \
	rd15-dev-mode iperf3 htop tcpdump

define Image/Prepare
	@echo "-=RB=-Image/Prepare: Cleaning up modules.builtin* for ipq53xx_32"
	rm -f $(TARGET_DIR)/lib/modules/*/modules.builtin*
	rm -f $(TARGET_DIR_ORIG)/lib/modules/*/modules.builtin*
	rm -f $(KDIR)/target-dir-*/lib/modules/*/modules.builtin*
	rm -f $(KDIR)/root.*/lib/modules/*/modules.builtin*
	$(CP) $(LINUX_DIR)/vmlinux $(KDIR)/$(IMG_PREFIX)-vmlinux.elf
endef

define Device/Default
	DEVICE_VENDOR := Xiaomi
	BLOCKSIZE := 128k
	PAGESIZE := 2048
	VID_HDR_OFFSET := 2048
	ROOTFS_NAME := ubi_rootfs
	IMAGES := factory.ubi sysupgrade.bin
	IMAGE/factory.ubi := append-ubi
	IMAGE/sysupgrade.bin := append-ubi | append-metadata
endef

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
	sed -i '/kernel@1 {/a \\t\t\tmiwifirom = "1.0.87";' $@.its
	PATH=$(LINUX_DIR)/scripts/dtc:$(PATH) mkimage -f $@.its $@.new
	@mv $@.new $@
endef

define Build/fit-rd16
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
	sed -i '/kernel@1 {/a \\t\t\tmiwifirom = "1.0.34";' $@.its
	PATH=$(LINUX_DIR)/scripts/dtc:$(PATH) mkimage -f $@.its $@.new
	@mv $@.new $@
endef

define Device/xiaomi-rd15
	DEVICE_MODEL := Router BE3600 (RD15)
	SUPPORTED_DEVICES := qcom,ipq5332-ap-mi04.1-c2 xiaomi,be3600 xiaomi,rd15
	DEVICE_DTS := ipq5332-rd15
	DEVICE_DTS_DIR := $(TOPDIR)/target/linux/ipq53xx/ipq53xx_32
	DEVICE_DTS_DELIMITER := @
	DEVICE_DTS_CONFIG := config@1
	KERNEL_LOADADDR := 0x40008000
	KERNEL_ENTRY := 0x40008000
	KERNEL := kernel-bin | lzma | fit-rd15 lzma $$(KDIR)/image-$$(DEVICE_DTS).dtb
	UBINIZE_PARTS := kernel=:$(KDIR)/$$(DEVICE_NAME)-kernel.bin
	DEVICE_PACKAGES := $(QSDK_PACKAGES) kmod-yt-phy-driver qca-firmware-vendor-rd15
endef

define Device/xiaomi-rd16
	DEVICE_MODEL := Router BE3600 (RD16)
	SUPPORTED_DEVICES := qcom,ipq5332-ap-mi04.1-c2 xiaomi,be3600-rd16 xiaomi,rd16
	DEVICE_DTS := ipq5332-rd16
	DEVICE_DTS_DIR := $(TOPDIR)/target/linux/ipq53xx/ipq53xx_32
	DEVICE_DTS_DELIMITER := @
	DEVICE_DTS_CONFIG := config@1
	KERNEL_LOADADDR := 0x40008000
	KERNEL_ENTRY := 0x40008000
	KERNEL := kernel-bin | lzma | fit-rd16 lzma $$(KDIR)/image-$$(DEVICE_DTS).dtb
	UBINIZE_PARTS := kernel=:$(KDIR)/$$(DEVICE_NAME)-kernel.bin
	DEVICE_PACKAGES := $(QSDK_PACKAGES) qca-firmware-vendor-rd16
endef

# --- Xiaomi Router BE3600 (RD15 with 2.5G port) ---
define Device/xiaomi-rd15-qsdk
	$(call Device/xiaomi-rd15)
	DEVICE_TITLE := Xiaomi BE3600 (native QSDK kernel)
endef
TARGET_DEVICES += xiaomi-rd15-qsdk

define Device/xiaomi-rd15-qsdk-singbox
	$(call Device/xiaomi-rd15)
	DEVICE_TITLE := Xiaomi BE3600 (native QSDK kernel, singbox)
	DEVICE_PACKAGES += $(SINGBOX_PACKAGES)
endef
TARGET_DEVICES += xiaomi-rd15-qsdk-singbox

define Device/xiaomi-rd15-qsdk-dev
	$(call Device/xiaomi-rd15)
	DEVICE_TITLE := Xiaomi BE3600 (native QSDK kernel, dev profile)
	DEVICE_PACKAGES += $(DEV_PACKAGES)
endef
TARGET_DEVICES += xiaomi-rd15-qsdk-dev

# --- Xiaomi Router BE3600 (RD16 with 4x 1G ports) ---
define Device/xiaomi-rd16-qsdk
	$(call Device/xiaomi-rd16)
	DEVICE_TITLE := Xiaomi BE3600 RD16 (native QSDK kernel)
endef
TARGET_DEVICES += xiaomi-rd16-qsdk

define Device/xiaomi-rd16-qsdk-singbox
	$(call Device/xiaomi-rd16)
	DEVICE_TITLE := Xiaomi BE3600 RD16 (native QSDK kernel, singbox)
	DEVICE_PACKAGES += $(SINGBOX_PACKAGES)
endef
TARGET_DEVICES += xiaomi-rd16-qsdk-singbox
