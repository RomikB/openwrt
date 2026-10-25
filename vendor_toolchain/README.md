# Dedicated Kernel Module Toolchain (GCC 7.5.0) for Linux 5.4.213

## English Summary

This directory provides a standalone build system and patches to compile a dedicated cross-toolchain based on **GCC 7.5.0 + Binutils 2.31.1** (ARM Cortex-A7 Hard-Float with NEON-VFPv4).

### Overview & Architecture
* **Main OpenWrt 24 Toolchain**: GCC 13.3.0 + Musl libc (`staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-13.3.0_musl_eabi/`) — builds modern userspace packages.
* **Kernel Module Toolchain**: GCC 7.5.0 + Binutils 2.31.1 (`staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel/`) — compiles out-of-tree kernel modules (`.ko`) matching the stock Linux 5.4.213 kernel vermagic (`5.4.213 SMP preempt mod_unload ARMv7 p2v8`).
* **Isolation**: Fully isolated from OpenWrt 24 `.config`. It reuses prebuilt host libraries (`gmp`, `mpfr`, `mpc`, `zstd`) from `staging_dir/host/`.

### Directory Structure
```text
vendor_toolchain/
├── Makefile                     # Standalone Makefile (download, patch, configure, build)
├── binutils/
│   └── patches/                 # 5 patches for binutils 2.31.1
├── gcc/
│   ├── exclude-testsuite        # Testsuite exclusion list
│   └── patches/                 # 22 patches for gcc 7.5.0
└── README.md
```

### Build Commands
```bash
# Run build script
./vendor_scripts/build_kmod_toolchain.sh

# Or directly using make
make -C vendor_toolchain
```

### Environment Setup for Module Compilation
```bash
export PATH="$(pwd)/staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel/bin:$PATH"
export CROSS_COMPILE="arm-openwrt-linux-"
export ARCH="arm"

# Verify compiler:
arm-openwrt-linux-gcc -v
```

---

## Описание на русском языке

Этот каталог содержит автономное описание и патчи для сборки кросс-компилятора **GCC 7.5.0 + Binutils 2.31.1** (ARM Cortex-A7 Hard-Float, NEON-VFPv4), точно соответствующего компилятору стокового ядра Linux **5.4.213** роутера Xiaomi BE3600 (RD15).

### 1. Назначение и Архитектура

* **Основной тулчейн OpenWrt 24**: GCC 13.3.0 + Musl libc (`staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-13.3.0_musl_eabi/`) — собирает всю современную прошивку и юзерспейс.
* **Выделенный Kernel Toolchain**: GCC 7.5.0 + Binutils 2.31.1 (`staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel/`) — собирает модули ядра (`.ko`), полностью совместимые с vermagic ядра 5.4.213 (`vermagic: 5.4.213 SMP preempt mod_unload ARMv7 p2v8`).
* **Изоляция**: Сборка не затрагивает глобальную конфигурацию `.config` OpenWrt 24 и использует уже скомпилированные хостовые библиотеки (`gmp`, `mpfr`, `mpc`, `zstd`) из `staging_dir/host/`.

### 2. Структура каталога

```text
vendor_toolchain/
├── Makefile                     # Управляющий Makefile (download, patch, configure, build)
├── binutils/
│   └── patches/                 # 5 патчей для binutils 2.31.1 (из OpenWrt 19.07)
├── gcc/
│   ├── exclude-testsuite        # Исключение тестовых наборов GCC при распаковке
│   └── patches/                 # 22 патча для gcc 7.5.0 (из OpenWrt 19.07)
└── README.md
```

### 3. Команды запуска сборки

#### Быстрый запуск через скрипт:
```bash
./vendor_scripts/build_kmod_toolchain.sh
```

#### Или напрямую через Make:
```bash
make -C vendor_toolchain
```

### 4. Использование тулчейна для компиляции модулей ядра

После завершения сборки тулчейн доступен в `staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel/bin`.

Для сборки модулей:
```bash
export PATH="$(pwd)/staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel/bin:$PATH"
export CROSS_COMPILE="arm-openwrt-linux-"
export ARCH="arm"

# Проверка версии компилятора:
arm-openwrt-linux-gcc -v
```
