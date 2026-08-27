LINUX_SOURCE:=linux-ipq-5.4-668bf957bfdcc05253bc3767c149c258ae49f323.tar.gz
LINUX_SITE:=https://git.codelinaro.org/clo/qsdk/oss/kernel/linux-ipq-5.4/-/archive/668bf957bfdcc05253bc3767c149c258ae49f323/
LINUX_KERNEL_HASH:=6da74559d45fd7c9a80d4015b4c8bc721ab97e0de35c4b0011f583bf43f2bef8
LINUX_CAT:=$(STAGING_DIR_HOST)/bin/libdeflate-gzip -dc

TAR_OPTIONS:=--transform 's,^linux-ipq-5.4-[^/]*,linux-$(LINUX_VERSION),' $(TAR_OPTIONS)

define Kernel/Prepare/Default
	$(LINUX_CAT) $(DL_DIR)/$(LINUX_SOURCE) | $(TAR) -C $(KERNEL_BUILD_DIR) $(TAR_OPTIONS)
	$(Kernel/Patch)
	$(if $(QUILT),touch $(LINUX_DIR)/.quilt_used)
endef

define Kernel/Patch
	$(if $(QUILT),rm -rf $(LINUX_DIR)/patches; mkdir -p $(LINUX_DIR)/patches)
	$(if $(FILES_DIR),$(CP) $(foreach dir,$(FILES_DIR),$(dir)/.) $(LINUX_DIR)/)
	find $(LINUX_DIR)/ -name \*.rej -or -name \*.orig | $(XARGS) rm -f
	$(call PatchDir,$(LINUX_DIR),$(TOPDIR)/target/linux/ipq53xx/rd15/patches-5.4,subtarget/)
endef

define Kernel/CompileImage
	@echo "-=RB=-Kernel/CompileImage"
endef
