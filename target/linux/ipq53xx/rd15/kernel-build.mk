define Kernel/Patch
	@echo "-=RB=-Kernel/Patch"
endef

define Kernel/CompileModules
	@echo "-=RB=-Kernel/CompileModules"
	mkdir -p $(LINUX_DIR)
	[ -f $(TOPDIR)/target/linux/ipq53xx/rd15/modules.builtin ] && cp -f $(TOPDIR)/target/linux/ipq53xx/rd15/modules.builtin $(LINUX_DIR)/modules.builtin || true
endef

define Kernel/CompileImage
	@echo "-=RB=-Kernel/CompileImage"
endef
