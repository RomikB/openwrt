#
# Makefile for building dedicated Linux 5.4 kernel module toolchain (GCC 7.5.0 + Binutils 2.31.1)
#
# Target: ARM Cortex-A7 (Hard Float / NEON-VFPv4), matching Xiaomi BE3600 (RD15) vendor kernel
#

SHELL := /bin/bash
TOPDIR ?= $(abspath $(CURDIR)/..)
DL_DIR ?= $(TOPDIR)/dl
BUILD_DIR ?= $(TOPDIR)/build_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0
STAGING_DIR_HOST ?= $(TOPDIR)/staging_dir/host
TOOLCHAIN_DIR ?= $(TOPDIR)/staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel

TARGET_TRIPLE ?= arm-openwrt-linux-muslgnueabi
TARGET_ALIAS ?= arm-openwrt-linux

CPU_TYPE ?= cortex-a7
FPU ?= neon-vfpv4
FLOAT ?= hard

BINUTILS_VERSION := 2.31.1
BINUTILS_SOURCE := binutils-$(BINUTILS_VERSION).tar.xz
BINUTILS_URL := https://ftp.gnu.org/gnu/binutils/$(BINUTILS_SOURCE)
BINUTILS_SHA256 := 5d20086ecf5752cc7d9134246e9588fa201740d540f7eb84d795b1f7a93bca86

GCC_VERSION := 7.5.0
GCC_SOURCE := gcc-$(GCC_VERSION).tar.xz
GCC_URL := https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/$(GCC_SOURCE)
GCC_SHA256 := b81946e7f01f90528a1f7352ab08cc602b9ccc05d4e44da4bd501c5a189ee661

JOBS ?= $(shell nproc 2>/dev/null || echo 4)

HOST_PATH := $(STAGING_DIR_HOST)/bin:$(PATH)
TOOLCHAIN_PATH := $(TOOLCHAIN_DIR)/bin:$(STAGING_DIR_HOST)/bin:$(PATH)

HOST_CFLAGS := -O2 -I$(STAGING_DIR_HOST)/include
HOST_LDFLAGS := -L$(STAGING_DIR_HOST)/lib -Wl,-rpath,$(STAGING_DIR_HOST)/lib

.PHONY: all binutils gcc clean distclean verify info

all: info binutils gcc symlinks verify
	@echo ""
	@echo "================================================================="
	@echo " Dedicated Kernel Module Toolchain (GCC $(GCC_VERSION)) successfully built!"
	@echo " Installed to: $(TOOLCHAIN_DIR)"
	@echo ""
	@echo " To build kernel modules for Linux 5.4.213, export:"
	@echo "   export PATH=\"$(TOOLCHAIN_DIR)/bin:\$$PATH\""
	@echo "   export CROSS_COMPILE=\"$(TARGET_ALIAS)-\""
	@echo "   export ARCH=\"arm\""
	@echo "================================================================="
	@echo ""

info:
	@echo "=== Building Kernel Module Toolchain ==="
	@echo "  Target Triple:   $(TARGET_TRIPLE)"
	@echo "  Target Alias:    $(TARGET_ALIAS)"
	@echo "  Architecture:    ARM ($(CPU_TYPE) / $(FPU) / $(FLOAT))"
	@echo "  GCC Version:     $(GCC_VERSION)"
	@echo "  Binutils:        $(BINUTILS_VERSION)"
	@echo "  Toolchain Dir:   $(TOOLCHAIN_DIR)"
	@echo "  Build Dir:       $(BUILD_DIR)"
	@echo "  Host Tools Dir:  $(STAGING_DIR_HOST)"
	@echo "  Parallel Jobs:   $(JOBS)"
	@echo "========================================"

#
# 1. Binutils
#
$(DL_DIR)/$(BINUTILS_SOURCE):
	@mkdir -p $(DL_DIR)
	@echo "Downloading $(BINUTILS_SOURCE)..."
	@if command -v curl >/dev/null 2>&1; then \
		curl -f -L -o "$@.tmp" "$(BINUTILS_URL)" || wget -O "$@.tmp" "$(BINUTILS_URL)"; \
	else \
		wget -O "$@.tmp" "$(BINUTILS_URL)"; \
	fi
	@echo "$(BINUTILS_SHA256)  $@.tmp" | sha256sum -c - || { echo "SHA256 mismatch for $(BINUTILS_SOURCE)!"; rm -f "$@.tmp"; exit 1; }
	@mv "$@.tmp" "$@"

$(BUILD_DIR)/binutils-$(BINUTILS_VERSION)/.prepared: $(DL_DIR)/$(BINUTILS_SOURCE)
	@mkdir -p $(BUILD_DIR)
	@rm -rf $(BUILD_DIR)/binutils-$(BINUTILS_VERSION)
	@echo "Unpacking $(BINUTILS_SOURCE)..."
	@tar -xJf $(DL_DIR)/$(BINUTILS_SOURCE) -C $(BUILD_DIR)
	@echo "Applying patches to binutils-$(BINUTILS_VERSION)..."
	@cd $(BUILD_DIR)/binutils-$(BINUTILS_VERSION) && \
	for p in $(CURDIR)/binutils/patches/*; do \
		[ -f "$$p" ] || continue; \
		echo "Applying patch: $$(basename $$p)"; \
		patch -p1 -N -r - < "$$p" || exit 1; \
	done
	@touch $@

$(BUILD_DIR)/binutils-$(BINUTILS_VERSION)/.configured: $(BUILD_DIR)/binutils-$(BINUTILS_VERSION)/.prepared
	@echo "Configuring binutils-$(BINUTILS_VERSION)..."
	@mkdir -p $(BUILD_DIR)/binutils-build
	@cd $(BUILD_DIR)/binutils-build && \
	export PATH="$(HOST_PATH)" && \
	CC="gcc" CXX="g++" CFLAGS="$(HOST_CFLAGS)" CXXFLAGS="$(HOST_CFLAGS)" LDFLAGS="$(HOST_LDFLAGS)" \
	$(BUILD_DIR)/binutils-$(BINUTILS_VERSION)/configure \
		--prefix="$(TOOLCHAIN_DIR)" \
		--build="$(shell gcc -dumpmachine)" \
		--host="$(shell gcc -dumpmachine)" \
		--target="$(TARGET_TRIPLE)" \
		--with-sysroot="$(TOOLCHAIN_DIR)" \
		--disable-multilib \
		--disable-werror \
		--disable-nls \
		--disable-sim \
		--disable-gdb \
		--enable-deterministic-archives \
		--enable-plugins
	@touch $@

$(BUILD_DIR)/binutils-$(BINUTILS_VERSION)/.built: $(BUILD_DIR)/binutils-$(BINUTILS_VERSION)/.configured
	@echo "Compiling binutils-$(BINUTILS_VERSION)..."
	@export PATH="$(HOST_PATH)" && \
	$(MAKE) -C $(BUILD_DIR)/binutils-build -j$(JOBS)
	@touch $@

$(BUILD_DIR)/binutils-$(BINUTILS_VERSION)/.installed: $(BUILD_DIR)/binutils-$(BINUTILS_VERSION)/.built
	@echo "Installing binutils-$(BINUTILS_VERSION)..."
	@export PATH="$(HOST_PATH)" && \
	$(MAKE) -C $(BUILD_DIR)/binutils-build install
	@touch $@

binutils: $(BUILD_DIR)/binutils-$(BINUTILS_VERSION)/.installed

#
# 2. GCC 7.5.0
#
$(DL_DIR)/$(GCC_SOURCE):
	@mkdir -p $(DL_DIR)
	@echo "Downloading $(GCC_SOURCE)..."
	@if command -v curl >/dev/null 2>&1; then \
		curl -f -L -o "$@.tmp" "$(GCC_URL)" || wget -O "$@.tmp" "$(GCC_URL)"; \
	else \
		wget -O "$@.tmp" "$(GCC_URL)"; \
	fi
	@echo "$(GCC_SHA256)  $@.tmp" | sha256sum -c - || { echo "SHA256 mismatch for $(GCC_SOURCE)!"; rm -f "$@.tmp"; exit 1; }
	@mv "$@.tmp" "$@"

$(BUILD_DIR)/gcc-$(GCC_VERSION)/.prepared: $(DL_DIR)/$(GCC_SOURCE)
	@mkdir -p $(BUILD_DIR)
	@rm -rf $(BUILD_DIR)/gcc-$(GCC_VERSION)
	@echo "Unpacking $(GCC_SOURCE)..."
	@tar -xJf $(DL_DIR)/$(GCC_SOURCE) -C $(BUILD_DIR) \
		--exclude-from="$(CURDIR)/gcc/exclude-testsuite" \
		--exclude='gcc/ada/*.ad*' --exclude='libjava'
	@echo "Applying patches to gcc-$(GCC_VERSION)..."
	@cd $(BUILD_DIR)/gcc-$(GCC_VERSION) && \
	for p in $(CURDIR)/gcc/patches/*; do \
		[ -f "$$p" ] || continue; \
		echo "Applying patch: $$(basename $$p)"; \
		patch -p1 -N -r - < "$$p" || exit 1; \
	done
	@cd $(BUILD_DIR)/gcc-$(GCC_VERSION) && \
	sed -i 's,^MULTILIB_OSDIRNAMES,# MULTILIB_OSDIRNAMES,' gcc/config/*/t-* && \
	sed -i 'd' gcc/DEV-PHASE && \
	sed -i 's, DATESTAMP,,' gcc/version.c && \
	sed -i 's,gcc_no_link=yes,gcc_no_link=no,' libstdc++-v3/configure
	@touch $@

$(BUILD_DIR)/gcc-$(GCC_VERSION)/.configured: $(BUILD_DIR)/gcc-$(GCC_VERSION)/.prepared binutils
	@echo "Configuring gcc-$(GCC_VERSION)..."
	@mkdir -p $(BUILD_DIR)/gcc-build
	@cd $(BUILD_DIR)/gcc-build && \
	export PATH="$(TOOLCHAIN_PATH)" && \
	CC="gcc" CXX="g++" CFLAGS="$(HOST_CFLAGS)" CXXFLAGS="$(HOST_CFLAGS)" LDFLAGS="$(HOST_LDFLAGS)" \
	$(BUILD_DIR)/gcc-$(GCC_VERSION)/configure \
		--prefix="$(TOOLCHAIN_DIR)" \
		--build="$(shell gcc -dumpmachine)" \
		--host="$(shell gcc -dumpmachine)" \
		--target="$(TARGET_TRIPLE)" \
		--with-sysroot="$(TOOLCHAIN_DIR)" \
		--with-gnu-as \
		--with-gnu-ld \
		--enable-target-optspace \
		--disable-libgomp \
		--disable-libmudflap \
		--disable-multilib \
		--disable-libmpx \
		--disable-nls \
		--disable-libssp \
		--without-isl \
		--without-cloog \
		--with-host-libstdcxx=-lstdc++ \
		--with-system-zlib="$(STAGING_DIR_HOST)" \
		--with-gmp="$(STAGING_DIR_HOST)" \
		--with-mpfr="$(STAGING_DIR_HOST)" \
		--with-mpc="$(STAGING_DIR_HOST)" \
		--disable-decimal-float \
		--with-cpu="$(CPU_TYPE)" \
		--with-fpu="$(FPU)" \
		--with-float="$(FLOAT)" \
		--enable-languages=c \
		--disable-shared \
		--disable-threads \
		--with-newlib \
		--disable-libsanitizer \
		--disable-libquadmath \
		--disable-libvtv
	@touch $@

$(BUILD_DIR)/gcc-$(GCC_VERSION)/.built: $(BUILD_DIR)/gcc-$(GCC_VERSION)/.configured
	@echo "Compiling gcc-$(GCC_VERSION) (core compiler & target libgcc)..."
	@export PATH="$(TOOLCHAIN_PATH)" && \
	$(MAKE) -C $(BUILD_DIR)/gcc-build -j$(JOBS) all-gcc all-target-libgcc
	@touch $@

$(BUILD_DIR)/gcc-$(GCC_VERSION)/.installed: $(BUILD_DIR)/gcc-$(GCC_VERSION)/.built
	@echo "Installing gcc-$(GCC_VERSION)..."
	@export PATH="$(TOOLCHAIN_PATH)" && \
	$(MAKE) -C $(BUILD_DIR)/gcc-build install-gcc install-target-libgcc
	@touch $@

gcc: $(BUILD_DIR)/gcc-$(GCC_VERSION)/.installed

#
# 3. Convenience Symlinks (arm-openwrt-linux-* alias)
#
symlinks:
	@echo "Setting up convenience symlinks..."
	@mkdir -p $(TOOLCHAIN_DIR)/bin
	@for tool in gcc cpp ar as ld nm objcopy objdump ranlib readelf size strings strip; do \
		if [ -f "$(TOOLCHAIN_DIR)/bin/$(TARGET_TRIPLE)-$$tool" ]; then \
			ln -sf "$(TARGET_TRIPLE)-$$tool" "$(TOOLCHAIN_DIR)/bin/$(TARGET_ALIAS)-$$tool"; \
		fi; \
	done
	@ln -sf "$(TARGET_TRIPLE)-gcc" "$(TOOLCHAIN_DIR)/bin/$(TARGET_ALIAS)-gcc-$(GCC_VERSION)"
	@ln -sf "$(TARGET_TRIPLE)-gcc" "$(TOOLCHAIN_DIR)/bin/$(TARGET_TRIPLE)-gcc-$(GCC_VERSION)"

#
# 4. Verification
#
verify:
	@echo "Verifying toolchain..."
	@"$(TOOLCHAIN_DIR)/bin/$(TARGET_ALIAS)-gcc" -v 2>&1 | grep "gcc version $(GCC_VERSION)" >/dev/null && \
	echo "  [OK] $(TARGET_ALIAS)-gcc $(GCC_VERSION) is operational." || \
	{ echo "  [ERROR] $(TARGET_ALIAS)-gcc verification failed!"; exit 1; }

#
# Cleanup
#
clean:
	@echo "Cleaning build directory..."
	@rm -rf $(BUILD_DIR)

distclean: clean
	@echo "Removing installed kernel toolchain..."
	@rm -rf $(TOOLCHAIN_DIR)
