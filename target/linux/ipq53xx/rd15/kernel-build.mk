#LINUX_SITE  :=
#LINUX_SOURCE :=

#define Kernel/Prepare
#	@echo "Kernel/Prepare"
#	mkdir -p $(LINUX_DIR)
#endef

#define Kernel/Configure
#	@echo "Kernel/Configure"
#	touch $(LINUX_DIR)/.config
#endef

#define Kernel/CompileModules
#	@echo "Kernel/CompileModules"
#	touch $(LINUX_DIR)/modules.builtin
#endef

#define Kernel/CompileImage
#	@echo "Kernel/CompileImage"
#endef
