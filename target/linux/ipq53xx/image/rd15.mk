#define Image/BuildKernel
#	@echo "-=RB=-Image/BuildKernel"
#endef

define Image/BuildKernel/Initramfs
	@echo "-=RB=-Image/BuildKernel/Initramfs"
endef

define Device/xiaomi-rd15-prebuild
	DEVICE_TITLE := Xiaomi BE3600 (prebuild kernel)
	KERNEL_CONFIG += CONFIG_ARM_PMU=y
	TARGET_KCONFIG := CONFIG_KERNEL_ARM_PMU=y
	CONFIG_KERNEL_ARM_PMU=y
	CONFIG_KERNEL_PERF_EVENTS=y
endef
TARGET_DEVICES += xiaomi-rd15-prebuild
