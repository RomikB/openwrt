LINUX_SOURCE:=linux-ipq-5.4-c2ca06284375ae9af06de73ea309065cc1be6e7b.tar.gz
LINUX_SITE:=https://git.codelinaro.org/clo/qsdk/oss/kernel/linux-ipq-5.4/-/archive/c2ca06284375ae9af06de73ea309065cc1be6e7b/
LINUX_KERNEL_HASH:=0b72e6926b630015e348a95bcbbaf9c5dc3c275d71b1dc34b0c74bd1cf54bd56
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
	$(call Kernel/CompileImage/Default)
endef
