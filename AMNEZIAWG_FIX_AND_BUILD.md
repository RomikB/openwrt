# Сборка и адаптация AmneziaWG для ядра Linux 5.4.213 (Xiaomi BE3600 / RD15)

## 1. Контекст и архитектура

* **Целевое устройство:** Xiaomi Router BE3600 (RD15)
* **Архитектура:** ARM Cortex-A7 (IPQ5332, 32-bit `arm_cortex-a7_neon-vfpv4`, `arm-openwrt-linux-muslgnueabi`)
* **Ядро:** 5.4.213 (Вендорное ядро Qualcomm)
* **Юзерленд:** Native OpenWrt 24 (Musl libc, GCC 13.3.0)
* **Тулчейн ядра:** GCC 7.5.0 (`staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel`)
* **Стек пакетов:**
  * `kmod-amneziawg` — модуль ядра (`amneziawg.ko`)
  * `amneziawg-tools` — утилита командной строки `awg`, скрипты `amneziawg.sh` для `netifd`, сторожевой таймер `amneziawg_watchdog`
  * `luci-proto-amneziawg` — Web-интерфейс LuCI

---

## 2. Анализ проблем совместимости AmneziaWG с ядром 5.4

При компиляции современных версий `kmod-amneziawg` (v1.0.20260611+) на ядре Linux 5.4.213 возникают две критические ошибки:

### Проблема 1: Ошибка неявного объявления функций в `src/main.c`
```text
src/main.c:25:13: error: implicit declaration of function 'chacha20_mod_init' [-Werror=implicit-function-declaration]
src/main.c:25:44: error: implicit declaration of function 'poly1305_mod_init'
src/main.c:26:13: error: implicit declaration of function 'chacha20poly1305_mod_init'
src/main.c:26:52: error: implicit declaration of function 'blake2s_mod_init'
src/main.c:27:13: error: implicit declaration of function 'curve25519_mod_init'
```
* **Причина:** Для ядер `< 5.10` в `compat.h` включается флаг `COMPAT_INIT_CRYPTO`, запускающий инициализацию и самотестирование криптомодулей Zinc в `wg_mod_init()`. Однако `src/main.c` не подключает заголовок `crypto/zinc.h`, где объявлены их прототипы.

### Проблема 2: Коллизия библиотеки BLAKE2s ядра и Zinc
* **Причина:** Начиная с версии **Linux 5.4.200** (включая **5.4.213**), апстрим ядра бэкпортировал `blake2s` прямо в ядро (`include/crypto/blake2s.h` и `lib/crypto/blake2s.o` в `vmlinux` с экспортом `blake2s_update` и `blake2s_final`).
* Одновременная сборка Zinc `crypto/zinc/blake2s/blake2s.o` приводит к:
  1. Конфликту определений: заголовок ядра объявляет `static inline void blake2s_init(...)`, а Zinc пытается скомпилировать `void zinc_blake2s_init(...)` (non-static).
  2. Макрос совместимости аргументов `blake2s(...)` в `compat.h` ломает вызовы внутри `src/crypto/zinc/selftest/blake2s.c`.
* **Решение:** Ядро 5.4.213 уже предоставляет готовый BLAKE2s. Сборка `blake2s/blake2s.o` из состава Zinc исключается, `blake2s_mod_init()` глушится как no-op `static inline int blake2s_mod_init(void) { return 0; }`, а основной код AmneziaWG (`noise.c`, `cookie.c`) использует ядерный BLAKE2s через безопасный макрос в `compat.h`.

---

## 3. Содержимое патча (`001-fix-kernel-5.4-compat.patch`)

Файл располагается в `feeds/amneziawg/kmod-amneziawg/patches/001-fix-kernel-5.4-compat.patch`. Включает исключительно необходимые исправления совместимости криптографии ядра и заголовков (без лишнего отладочного логирования):

```diff
--- a/src/compat/compat.h
+++ b/src/compat/compat.h
@@ -896,10 +896,6 @@
 
 #if (LINUX_VERSION_CODE >= KERNEL_VERSION(5, 4, 200) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 20, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 249)) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 15, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 14, 285)) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 10, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 9, 320))) && LINUX_VERSION_CODE < KERNEL_VERSION(5, 10, 0) && !defined(ISUBUNTU2004)
 #define COMPAT_INIT_CRYPTO
-#define blake2s_init zinc_blake2s_init
-#define blake2s_init_key zinc_blake2s_init_key
-#define blake2s_update zinc_blake2s_update
-#define blake2s_final zinc_blake2s_final
 #endif
 #if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 5, 0) && LINUX_VERSION_CODE < KERNEL_VERSION(5, 10, 0)
 #define blake2s_hmac zinc_blake2s_hmac
@@ -1404,7 +1400,7 @@
 #include <crypto/blake2s.h>
 #define blake2s_ctx blake2s_state
 #define blake2s(key, keylen, in, inlen, out, outlen) \
-	blake2s(out, in, key, outlen, inlen, keylen)
+	(blake2s)((u8 *)(out), (const u8 *)(in), (const u8 *)(key), (size_t)(outlen), (size_t)(inlen), (size_t)(keylen))
 #endif
 
 #endif /* _WG_COMPAT_H */
--- a/src/crypto/Kbuild.include
+++ b/src/crypto/Kbuild.include
@@ -31,8 +31,10 @@
 
 zinc-y += chacha20poly1305.o
 
+ifeq ($(wildcard $(srctree)/include/crypto/blake2s.h),)
 zinc-y += blake2s/blake2s.o
 zinc-$(CONFIG_ZINC_ARCH_X86_64) += blake2s/blake2s-x86_64.o
+endif
 
 zinc-y += curve25519/curve25519.o
 zinc-$(CONFIG_ZINC_ARCH_ARM) += curve25519/curve25519-arm.o
--- a/src/crypto/zinc.h
+++ b/src/crypto/zinc.h
@@ -9,7 +9,11 @@
 int chacha20_mod_init(void);
 int poly1305_mod_init(void);
 int chacha20poly1305_mod_init(void);
+#if (LINUX_VERSION_CODE >= KERNEL_VERSION(5, 4, 200) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 20, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 249)) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 15, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 14, 285)) || (LINUX_VERSION_CODE < KERNEL_VERSION(4, 10, 0) && LINUX_VERSION_CODE >= KERNEL_VERSION(4, 9, 320))) && LINUX_VERSION_CODE < KERNEL_VERSION(5, 10, 0)
+static inline int blake2s_mod_init(void) { return 0; }
+#else
 int blake2s_mod_init(void);
+#endif
 int curve25519_mod_init(void);
 
 #endif
--- a/src/main.c
+++ b/src/main.c
@@ -11,6 +11,7 @@
 #include "ratelimiter.h"
 #include "netlink.h"
 #include "uapi/wireguard.h"
+#include "crypto/zinc.h"
 
 #include <linux/init.h>
 #include <linux/module.h>
```

---

## 4. Автоматизация в `vendor_scripts/patch_feeds.py`

Для сохранения воспроизводимости при обновлении feeds логика генерации патча и настройки `Makefile` включена в `vendor_scripts/patch_feeds.py`:

```python
def patch_amneziawg_feed(repo_root):
    amneziawg_dir = os.path.join(repo_root, "feeds/amneziawg/kmod-amneziawg")
    makefile_path = os.path.join(amneziawg_dir, "Makefile")
    if not os.path.isdir(amneziawg_dir) or not os.path.isfile(makefile_path):
        return False

    # 1. Makefile с правильными зависимостями под ядро:
    # +kmod-udptunnel4, +kmod-udptunnel6
    ...
    # 2. Создание patches/001-fix-kernel-5.4-compat.patch
    ...
```

## 5. Включение AmneziaWG в общую сборку OpenWrt

### 1. Добавление и установка фида
В файл `feeds.conf` (или `feeds.conf.default`) добавляется репозиторий фида AmneziaWG:
```text
src-git amneziawg https://github.com/Slava-Shchipunov/awg-openwrt.git
```

Затем выполняется загрузка и регистрация пакетов фида:
```bash
./scripts/feeds update amneziawg
./scripts/feeds install -a -p amneziawg
```

### 2. Патчинг фида под ядро 5.4 QSDK
Запустите скрипт автоматической адаптации фидов:
```bash
python3 vendor_scripts/patch_feeds.py
```
*(Скрипт настроит зависимости `kmod-amneziawg` на нативные модули `kmod-udptunnel4`/`kmod-udptunnel6` и сгенерирует патч совместимости криптографии под ядро 5.4)*.

### 3. Выбор пакетов через `make menuconfig`
Запустите конфигуратор:
```bash
make menuconfig
```
И выберите следующие компоненты для встраивания в прошивку (`<*>`) или сборки отдельными `.ipk` (`<M>`):
* **Kernel modules $\to$ Network Support:**
  * `<*> kmod-amneziawg` — модуль ядра Linux
* **Network $\to$ VPN:**
  * `<*> amneziawg-tools` — CLI-утилита `awg` и скрипты протокола `netifd`
* **LuCI $\to$ Protocols:**
  * `<*> luci-proto-amneziawg` — интеграция и Web UI в панели управления LuCI

*(Либо активируйте их в `.config` командной строкой):*
```bash
./scripts/config --enable CONFIG_PACKAGE_kmod-amneziawg
./scripts/config --enable CONFIG_PACKAGE_amneziawg-tools
./scripts/config --enable CONFIG_PACKAGE_luci-proto-amneziawg
```

### 4. Запуск сборки
* **Сборка всей прошивки с AmneziaWG:**
  ```bash
  make -j$(nproc)
  ```

* **Или отдельная компиляция только пакетов AmneziaWG:**
  ```bash
  make package/feeds/amneziawg/kmod-amneziawg/compile -j$(nproc)
  make package/feeds/amneziawg/amneziawg-tools/compile -j$(nproc)
  make package/feeds/amneziawg/luci-proto-amneziawg/compile -j$(nproc)
  ```

