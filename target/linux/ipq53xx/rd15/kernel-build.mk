define Kernel/Patch
	$(Kernel/Patch/Default)
	$(call PatchDir,$(LINUX_DIR),$(TOPDIR)/target/linux/ipq53xx/rd15/patches-5.4,subtarget/)
endef

define Kernel/CompileImage
	@echo "-=RB=-Kernel/CompileImage"
endef
