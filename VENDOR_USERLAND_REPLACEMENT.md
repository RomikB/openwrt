# Xiaomi BE3600 (RD15) — Пошаговая замена Vendor Userland на OpenWrt 24

## 1. Цель проекта

Перевести userland (userspace) роутера **Xiaomi BE3600 (RD15)** (SoC Qualcomm IPQ5332, свитч Motorcomm YT9215S, ядро 5.4.213) на стандартный стек **OpenWrt 24 (master/24.x)** с сохранением:
- Оригинального ядра Linux 5.4.213 и всех вендорных модулей ядра (`qca-nss-dp`, `qca-ssdk`, `qca-nss-ppe`, `yt_switch`, `yt_phy_module`).
- Вендорных бинарников и библиотек через механизм версионирования (`ld-vendor.so.1`, `v_lc.so`, `v_lubox.so` и т.д.).
- Скриптов инициализации аппаратной части (`/sbin/phyhelper`, `switch_ctl`, `/lib/miwifi/*`).

---

## 2. Архитектура и методология миграции

### Принцип строгой поэтапности:
1. Замена строго по **1 пакету за шаг**.
2. Обязательная сборка и проверка работоспособности на реальном оборудовании перед переходом к следующему пакету.
3. Полная автоматизация генерации вендорного фида и наложения патчей через скрипт `prepare_feed.sh`.

### Схема взаимодействия компонентов:
```
┌────────────────────────────────────────────────────────────────────────┐
│                        Ядро Linux 5.4.213                              │
│  qca-nss-dp.ko → eth0, eth1         qca-ssdk.ko → Switch SDK          │
│  yt_switch.ko  → YT9215S (switch1)   yt_phy_module.ko → PHY Driver     │
│  qca-nss-ppe.ko → PPE Engine         bootconfig.ko, nat46.ko и др.     │
└────────────────────────────────────────────────────────────────────────┘
                                  ↕
┌────────────────────────────────────────────────────────────────────────┐
│                  OpenWrt 24 Нативный Userland (Musl)                   │
│                                                                        │
│  [Фаза 10.2] /etc/init.d/boot, base-files ── Базовая система & /data   │
│  [Фаза 10.1] jsonfilter, usign, fwtool ── Системные утилиты            │
│  [Фаза 9] /sbin/netifd ────────────── Network Interface Daemon         │
│  [Фаза 9] /etc/init.d/network ─────── Сетевая служба & swconfig hooks  │
│  [Фаза 9] /usr/libexec/network/* ──── SMP Packet Steering (Ucode)      │
│  [Фаза 8] /sbin/init, /sbin/procd ── Init & Process Manager (PID 1)    │
│  [Фаза 8] /sbin/reload_config, /sbin/service ── Управление службами    │
│  [Фаза 8] /etc/hotplug*.json ─────── Диспетчер системных событий       │
│  [Фаза 7] /sbin/mount_root, /sbin/block ── Файловые системы & UBI      │
│  [Фаза 6] /sbin/kmodloader ───────── Загрузка kmod-* при старте        │
│  [Фаза 6] /sbin/validate_data ────── Валидация UCI типов данных        │
│  [Фаза 6] /sbin/logd, logread ────── Демон системного логирования      │
│  [Фаза 5] /sbin/ubusd, /bin/ubus ─── IPC-шина, Libubus 2025.x          │
│  [Фаза 2] /usr/sbin/dropbear ─────── SSH-сервер (OpenWrt 24)           │
│  [Фаза 3.1] /sbin/uci ────────────── UCI CLI & Libuci 2025.x           │
│  [Фаза 3.2] /sbin/swconfig ───────── Настройка свитча YT9215S          │
│  [Фаза 4] /bin/busybox (v1.36.1) ─── Ash shell, Coreutils, Udhcpc      │
│  [Фаза 4] /bin/ipcalc.sh ─────────── POSIX расчет подсетей              │
│  [Фаза 4] /etc/rc.common ─────────── Системная обвязка init-скриптов    │
└────────────────────────────────────────────────────────────────────────┘
                                  ↕
┌────────────────────────────────────────────────────────────────────────┐
│               Vendor Userland (изолирован через ld-vendor)             │
│                                                                        │
│  /sbin/phyhelper, /usr/sbin/switch_ctl, /usr/sbin/ssdk_sh,             │
│  /usr/sbin/nvram, /lib/miwifi/*                                        │
│  Линковка: ld-vendor.so.1 → v_lc.so, v_lgcc_s.so.1                     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Достигнутые результаты по фазам

### ✅ Фаза 2: Миграция `dropbear`
- **Что сделано**:
  - Пакет `dropbear` переведен на нативный OpenWrt 24 (включен в `target.mk` → `dropbear`, исключен из вендорного списка).
  - Сняты вендорские ограничения на запуск SSH (проверки `ssh_en`, `channel = release`).
  - Обеспечена корректная генерация 2048-битного хост-ключа RSA при старте.
- **Результат**: Нативный SSH-сервер OpenWrt 24 стартует штатно, обеспечивая надежный терминальный доступ.

---

### ✅ Фаза 3.1: Миграция `uci`
- **Что сделано**:
  - Пакет `uci` переведен на нативный OpenWrt 24 (`packages.list` → удален `uci`, `target.mk` → `uci`).
  - В вендорский `lib/functions/procd.sh` добавлен полифил `uci_load_validate()`, необходимый для современных скриптов конфигурации.
- **Результат**: Нативный бинарник `uci` и библиотека `libuci` работают штатно, все вендорные конфигурации считываются и применяются корректно.

---

### ✅ Фаза 3.2: Миграция `swconfig`
- **Что сделано**:
  - Пакет `swconfig` переведен на нативный OpenWrt 24.
  - В `package/network/config/swconfig/files/switch.sh` интегрированы вендорные хуки `switch_ctl forward 0 / 1` для предотвращения широковещательного шторма и сбоев YT9215S при инициализации.
  - Устранены коллизии файлов `switch.sh` между `swconfig` и `base-files-vendor`.
- **Результат**: Свитч `switch0`/`switch1` настраивается без ошибок, изолированные VLAN поднимаются, петли трафика отсутствуют.

---

### ✅ Фаза 4: Миграция `busybox`
- **Что сделано**:
  1. **Настройки безопасности и ELF**:
     - Включены `CONFIG_BUSYBOX_DEFAULT_PIE=y` и `CONFIG_BUSYBOX_DEFAULT_FEATURE_SUID=y` (критично для Qualcomm hardened kernel с включенным ASLR).
  2. **Апплеты и функции**:
     - Включено 30 недостающих апплетов (`timeout`, `vconfig`, `getopt`, `usleep`, `stat`, `base64`, `devmem`, `watch`, `arping`, `lsof`, `pstree`, `renice`, `mpstat`, `wget`, `xz`, `bunzip2`, `telnet`, `telnetd` и др.).
     - Включены расширенные опции шелла (`FEATURE_SH_READ_FRAC`, `FEATURE_SH_MATH_BASE`, `ASH_SLEEP`, `ASH_HELP`).
     - Включены расширенные параметры мониторинга процессов (`FEATURE_PS_LONG`, `FEATURE_PS_TIME`, `FEATURE_TOPMEM`, `FEATURE_SHOW_THREADS`).
  3. **Сетевой стек и DHCP (Критический фикс)**:
     - Включен `BUSYBOX_DEFAULT_FEATURE_UDHCPC_ARPING=y`, обеспечивающий поддержку опции `-a` в `udhcpc` (ARP Ping для проверки уникальности IP перед применением DHCP-аренды).
  4. **POSIX-скрипты и совместимость**:
     - Вендорский сбойный `bin/ipcalc.sh` (падавший на `awk xor`) заменен на чистую POSIX-шелл реализацию OpenWrt 24 и библиотеку `/lib/functions/ipv4.sh`.
     - Вендорский `/etc/rc.common` модифицирован на месте:
       - Добавлен системный `export PATH="/usr/sbin:/usr/bin:/sbin:/bin"`.
       - Добавлена функция `extra_command()`.
       - Сохранены парные вызовы `procd_lock` и `procd_unlock` (исключающие дедлоки на `flock` при вызовах `service restart`).
- **Результат**: Роутер успешно стартует с нативным BusyBox 1.36.1-r2, получает IP-адрес на `br-lan`, SSH доступен.

---

### ✅ Фаза 5: Миграция `ubus`
- **Что сделано**:
  1. **Нативные компоненты**:
     - Пакеты `ubus` и `ubusd` включены в сборку OpenWrt 24 (`target.mk` → `ubus ubusd`).
     - Скомпилированы нативные `/sbin/ubusd`, `/bin/ubus`, `/lib/libubus.so.*`, `/lib/libblobmsg_json.so.*`, `/lib/libubox.so.*`.
  2. **Исключение вендорных дубликатов**:
     - В `vendor_scripts/prepare_feed.sh` добавлен фильтр `IGNORE_VENDOR_PACKAGES="... ubus ubusd"`.
     - Вендорные пакеты `ubus-vendor` и `ubusd-vendor` исключены из фида, устраняя коллизии на путях `/sbin/ubusd` и `/bin/ubus`.
  3. **Изоляция и обратная совместимость сокета**:
     - Сохранена изолированная библиотека `/lib/v_lubus.so` (`libubus-vendor`).
     - Добавлен патч `package/system/ubus/patches/001-compat-symlink.patch`, создающий при старте `ubusd` симлинк `/var/run/ubus.sock -> /var/run/ubus/ubus.sock`. Это позволяет старым вендорным бинарникам (`switch_ctl`, `nvram`) мгновенно подключаться к нативному сокету `ubusd`.
- **Результат**: Собрана прошивка с нативным `ubusd` и полной поддержкой как современных клиентов OpenWrt 24 (`/var/run/ubus/ubus.sock`), так и вендорных клиентов (`/var/run/ubus.sock`).

---

### ✅ Фаза 6: Миграция `ubox`
- **Что сделано**:
  1. **Нативные системные утилиты**:
     - Пакеты `ubox`, `getrandom`, `logd` включены в сборку OpenWrt 24 (`target.mk` → `ubox getrandom logd`).
     - Скомпилированы нативные `/sbin/kmodloader` (с симлинками `lsmod`, `insmod`, `rmmod`, `modprobe`, `modinfo`), `/sbin/validate_data`, `/lib/libvalidate.so`, `/usr/bin/getrandom`, `/sbin/logd`, `/sbin/logread`.
  2. **Исключение вендорных пакетов**:
     - В `vendor_scripts/prepare_feed.sh` добавлен фильтр `IGNORE_VENDOR_PACKAGES="... ubox"`.
     - Пакет `ubox-vendor` исключен из фида.
  3. **Сохранение библиотечной изоляции**:
     - Сохранена библиотека `libubox-vendor` (`/lib/v_lubox.so`), необходимая для работы оставшихся вендорных демонов.
- **Результат**: Модули ядра загружаются через нативный `kmodloader`, доступна валидация UCI-данных и системное логирование `logd` / `logread`.

---

### ✅ Фаза 7: Миграция `fstools` и `ubi-utils`
- **Что сделано**:
  1. **Нативные утилиты файловых систем**:
     - Пакеты `fstools`, `block-mount`, `ubi-utils` включены в сборку OpenWrt 24 (`target.mk` → `fstools block-mount ubi-utils`).
     - Скомпилированы нативные `/sbin/mount_root`, `/sbin/block`, `/lib/libfstools.so`, `/lib/libblkid-tiny.so`, `/usr/sbin/ubiattach`, `/usr/sbin/ubinfo`, `/usr/sbin/ubiformat` (с поддержкой UBIFS / NAND flash).
  2. **Исключение вендорных пакетов**:
     - В `vendor_scripts/prepare_feed.sh` добавлен фильтр `IGNORE_VENDOR_PACKAGES="... fstools ubi-utils"`.
     - Пакеты `fstools-vendor` и `ubi-utils-vendor` исключены из фида.
- **Результат**: Монтирование rootfs/overlayfs на этапе preinit и работа с блочными/UBI устройствами переведены на чистый OpenWrt 24.

---

### ✅ Фаза 8: Миграция `procd`
- **Что сделано**:
  1. **Нативная система инициализации и менеджер процессов (PID 1)**:
     - Пакет `procd` переведен на нативный OpenWrt 24 (`target.mk` → убран `-procd`, добавлен `procd`).
     - Скомпилированы нативные `/sbin/init`, `/sbin/procd`, `/sbin/askfirst`, `/sbin/udevtrigger`, `/sbin/upgraded`, `/sbin/reload_config`, `/sbin/service`, `/lib/libsetlbf.so`.
     - Установлен нативный `/usr/bin/jshn` и `/usr/share/libubox/jshn.sh`.
  2. **Стандартизация скриптов и диспетчера hotplug**:
     - Установлен нативный `/lib/functions/procd.sh` OpenWrt 24 со встроенной валидацией UCI (`uci_load_validate`, `uci_validate_section`) и расширенной поддержкой сервисов (`procd_running`, группы, namespaces).
     - Установлен нативный `/etc/hotplug.json` со стандартной инициализацией POSIX-дескрипторов (`/dev/fd`, `/dev/stdin`, `/dev/stdout`, `/dev/stderr`) и группой `dialout` для TTY.
  3. **Патчи совместимости и права доступа (Критический фикс)**:
     - В `package/system/procd/patches/001-compat-ubus-symlink.patch` реализовано:
       - Установка прав `01777` на `/tmp/run` при раннем монтировании в `initd/early.c`.
       - Гарантированное создание симлинка `/var/run/ubus.sock -> /var/run/ubus/ubus.sock` от имени `root` при старте `procd` (до запуска `ubusd` под непривилегированным пользователем `ubus`).
  4. **Исключение вендорных пакетов**:
     - В `vendor_scripts/prepare_feed.sh` добавлен фильтр `IGNORE_VENDOR_PACKAGES="... procd jshn"`.
     - Пакеты `procd-vendor` и `jshn-vendor` полностью исключены из фида.
- **Результат**: Проверено на реальном роутере Xiaomi BE3600. `init` (PID 1) и `procd` стартуют штатно, супервизор процессов управляет службами, сетевой мост `br-lan` и свитч YT9215S поднимаются, SSH доступен.

---

### ✅ Фаза 9: Миграция `netifd`
- **Что сделано**:
  1. **Нативный сетевой демон и утилиты**:
     - Пакет `netifd` переведен на нативный OpenWrt 24 (`target.mk` → убран `-netifd`, добавлен `netifd`).
     - Скомпилированы нативные `/sbin/netifd`, `/sbin/ifup`, `/sbin/ifdown`, `/sbin/ifstatus`, `/sbin/devstatus`, `/lib/network/config.sh`, `/lib/netifd/netifd-proto.sh`, `/lib/netifd/utils.sh`.
     - Подключены современные библиотеки зависимостей: `libudebug`, `ucode`, `ucode-mod-fs`, `libnl-tiny`.
     - Включен нативный сервис SMP Packet Steering `/etc/init.d/packet_steering` и скрипт `/usr/libexec/network/packet-steering.uc`.
  2. **Аппаратные хуки и совместимость в `/etc/init.d/network`**:
     - В `package/network/config/netifd/files/etc/init.d/network` интегрированы:
       - Вызов `init_arch()` (`/lib/miwifi/miwifi_core_libs.sh network_extra_init`) для аппаратной настройки ускорения ECM PPE, отключения GRO на `eth0`/`eth1` и PHY-контроля.
       - Вызов `init_switch()` (`/lib/network/switch.sh setup_switch`) с хуками `switch_ctl forward 0 / 1` и загрузкой `swconfig dev switch1 load network`.
       - Дополнительная команда `reconfig_switch`.
  3. **Исключение вендорных пакетов и библиотек**:
     - В `vendor_scripts/prepare_feed.sh` добавлен `netifd` в `IGNORE_VENDOR_PACKAGES`.
     - Удален `libblobmsg-json` из `vendor_scripts/packages.list` и `target.mk` (так как все клиенты переведены на нативный `libblobmsg_json`).
     - Пакеты `netifd-vendor` и `libblobmsg-json-vendor` полностью удалены из фида.
  4. **Совместимость с ядром (Критический фикс Netlink & Bridge)**:
     - В ядре 5.4.213 (`CONFIG_BRIDGE_VLAN_FILTERING` не включен) передача атрибута `IFLA_BR_VLAN_FILTERING` (а также multicast-атрибутов) в `system_bridge_addbr()` приводила к отказу ядра с ошибкой `-EOPNOTSUPP` (`-10`), даже если их значение было `0`.
     - В патче `002-fix-bridge-netlink-attrs.patch`:
       - Вырезана безусловная отправка неподдерживаемых атрибутов (передаются только при явном включении).
       - Добавлен автоматический fallback на `ioctl(sock_ioctl, SIOCBRADDBR, bridge->ifname)` и `ioctl(sock_ioctl, SIOCBRDELBR, bridge->ifname)`.
     - В патче `001-fix-ifname-fixup-for-non-bridges.patch` обеспечено разделение fixup `ifname -> ports` только для мостов, что гарантирует работу со стоковым `/etc/config/network`.
- **Результат**: Проверено на роутере Xiaomi BE3600 (со стоковым конфигом). Мост `br-lan` создается штатно, порты `eth0.1`, `eth0.2`, `eth0.3`, `eth1` подключаются и переходят в режим forwarding, DHCP-клиент получает IP `192.168.11.36`, шлюз и DNS применились, SSH и сеть функционируют штатно.

---

### ✅ Фаза 10.1: Замена вспомогательных утилит (`jsonfilter`, `usign`, `openwrt-keyring`, `fwtool`)
- **Что сделано**:
  1. Пакеты `jsonfilter`, `usign`, `openwrt-keyring`, `fwtool` переведены на нативную сборку из открытых исходников OpenWrt 24.
  2. Добавлены в `IGNORE_VENDOR_PACKAGES` в `vendor_scripts/prepare_feed.sh`.
  3. Включены в `DEFAULT_PACKAGES` в `target/linux/ipq53xx/rd15/target.mk`.
  4. Удалены вендорные пребилды `*-vendor` из `vendor_feed/` и очищены зависимости `base-files-vendor`.
- **Результат**: `/usr/bin/jsonfilter`, `/usr/bin/usign`, `/usr/bin/signify`, `/usr/bin/fwtool` и ключи `/etc/opkg/keys/` собираются и работают как нативные компоненты OpenWrt 24.

---

### ✅ Фаза 10.2: Переход на нативный `base-files` и размещение аппаратного слоя в подплатформе `rd15`
- **Что сделано**:
  1. **Создан аппаратный оверлей подплатформы в `target/linux/ipq53xx/rd15/base-files/`**:
     - **Preinit & Ramfs**:
       - `lib/preinit/39_mount_tmpfs` — монтирование RAMFS поверх `/etc` (и других временных каталогов), обеспечивающее возможность записи при read-only корне SquashFS.
       - `lib/preinit/39_mount_ubi_data` — автоматический поиск, привязка `ubi1` и монтирование UBIFS-тома `/data`.
     - **Сеть, PPE и Switch**:
       - `lib/miwifi/miwifi_core_libs.sh`, `lib_network.sh`, `lib_accel.sh`, `lib_phy.sh`, `lib_port_map.sh`, `lib_sp_colls.sh`, `lib_ap_re.sh`, `miwifi_functions.sh` — аппаратные библиотеки (ускорение PPE/ECM, отключение GRO на `eth0`/`eth1`, PHY-контроль, получение MAC-адресов через `getmac`).
       - `lib/miwifi/arch/*` — драйверная обвязка архитектуры IPQ53xx.
     - **Утилиты железа**:
       - `/sbin/phyhelper` — управление питанием и режимами Ethernet PHY.
       - `/sbin/port_map` — маппинг и опрос физических портов для `phyhelper`.
       - `/sbin/getmac`, `/sbin/setmac`, `/sbin/setmac_all` — чтение/запись заводских MAC-адресов.
       - `/sbin/hwversion` — определение аппаратной ревизии.
       - `/sbin/accelctrl` — интерфейс управления ускорением PPE.
       - `/sbin/wifi` — заглушка, предотвращающая сбои при вызове `wifi config`.
     - **Инициализация и LED**:
       - `/etc/init.d/boot` — запуск `boot_phy_control` (`/sbin/phyhelper start`), настройка формата VLAN (`vconfig set_name_type DEV_PLUS_VID_NO_PAD`), запуск `kmodloader` и `reload_config`.
       - `/etc/inittab` — настройка UART-консоли на `ttyMSM0::askfirst:/bin/ash --login`.
       - `/etc/board.d/01_network`, `/etc/diag.sh`, `/etc/hotplug.d/button/51-reset`, `/etc/hotplug.d/button/02-mesh`.
     - **NAND Sysupgrade**:
       - `/lib/upgrade/platform.sh`.
     - **Конфигурация**:
       - Чистые файлы `/etc/config/network`, `/etc/config/port_map`, `/etc/config/system`, `/etc/config/traffic`, `/etc/config/dropbear`.
  2. **Сборочные хуки `target/linux/ipq53xx/base-files.mk`**:
     - В хуке `Package/base-files/install-target` прописано автоматическое добавление:
       - `pi_preinit_ramfs_dir="/etc /lib/wifi /mnt /vendor /ini /cfg /license /lib/firmware/qcn6432"`
       - `pi_overlay_partitions="cfg:/data:"`
       в `/lib/preinit/00_preinit.conf`.
  3. **Очистка от мертвого вендорного кода**:
     - Пакет `base-files` переведен на стандартный OpenWrt 24 (`package/base-files`).
     - Удалено более 200 неиспользуемых вендорных файлов (все `*.lua` скрипты облака Xiaomi, более 50 устаревших конфигов, заглушки служб `/etc/init.d/`).
     - Пакет `base-files-vendor` полностью исключен из фида.
  4. **Состав фида**: В `vendor_feed` остались **ровно 7 аппаратных компонентов из `required.list`**.
- **Результат**: **Успешно проверено на реальном роутере Xiaomi BE3600 (RD15)!**
  - Роутер стартует с чистым нативным `base-files` OpenWrt 24.
  - Каталог `/etc` доступен для записи через RAMFS, том `/data` примонтирован из UBIFS.
  - Ethernet PHY поднимаются штатно через `phyhelper` и `port_map`.
  - Мост `br-lan` и свитч YT9215S работают, получен IP-адрес по DHCP, SSH-сервер доступен.

---

### ✅ Фаза 11: Подключение менеджера пакетов `opkg`, TLS-стека (`mbedtls`, `ca-bundle`) и подсистемы энтропии (`urngd`, `urandom-seed`)
- **Что сделано**:
  1. В `target/linux/ipq53xx/rd15/target.mk` сняты флаги блокировки стандартных пакетов (`opkg`, `ca-bundle`, `libustream-mbedtls`, `urandom-seed`, `urngd`).
  2. В `README.md` очищен шаблон `.config` от блокировок `opkg` / `uclient-fetch`.
  3. Пакеты автоматически включены в сборку через стандартный механизм `make defconfig`:
     - **Менеджер пакетов**: `/bin/opkg`, `/bin/uclient-fetch`, `/usr/lib/libuclient.so`, `/usr/sbin/opkg-key`.
     - **TLS & Безопасность**: `/lib/libustream-ssl.so` (mbedTLS бэкенд), `/usr/lib/libmbedtls.so.*`, `/usr/lib/libmbedcrypto.so.*`, `/usr/lib/libmbedx509.so.*`, корневые сертификаты `/etc/ssl/certs/ca-certificates.crt`.
     - **Энтропия и CSPRNG ядра 5.4.213**: `/sbin/urngd` (демон Jitter Entropy) и сервис `/etc/init.d/urandom_seed` (сохранение/восстановление сида случайных чисел).
- **Результат**: Полноценный нативный стек `opkg` и HTTPS-клиента интегрирован в сборку прошивки.

---

### ✅ Фаза 12: Интеграция `dnsmasq` и настройка стандартной сетевой конфигурации OpenWrt (`192.168.1.1`)
- **Что сделано**:
  1. Пакет `dnsmasq` (v2.90) включен в сборку подплатформы `rd15` (`target.mk` → `DEFAULT_PACKAGES += dnsmasq`).
  2. В `/etc/config/network` зафиксирована топология роутера:
     - **WAN**: Порт 1 (`eth0.1`), протокол `dhcp` (получение IP от провайдера/домашней сети).
     - **LAN**: Порты 2, 3, 4 (`eth0.2 eth0.3 eth1`), мост `br-lan`, статический IP `192.168.1.1/24`.
  3. Создан конфигурационный файл `/etc/config/dhcp`:
     - Настроен локальный DNS-домен `lan` (`openwrt.lan`), кеш DNS на 1000 записей.
     - Настроен DHCPv4-сервер для зоны `lan` с пулом `192.168.1.100` — `192.168.1.249` (аренда 12ч).
     - Выключена раздача DHCP наружу в зону `wan` (`option ignore '1'`).
- **Результат**: Роутер работает как полноценный локальный сервер DNS и DHCP для клиентов в LAN.

---

## 4. Сводный статус миграции пакетов

| Пакет | Роль | Статус | Версия | Фаза | Примечание |
|---|---|---|---|---|---|
| **`dropbear`** | SSH-сервер | ✅ Завершен | OpenWrt 24 | Фаза 2 | Проверено на роутере |
| **`uci`** | Конфигурация | ✅ Завершен | OpenWrt 24 | Фаза 3.1 | Проверено на роутере |
| **`swconfig`** | Свитч YT9215S | ✅ Завершен | OpenWrt 24 | Фаза 3.2 | С хуками `switch_ctl` |
| **`busybox`** | Coreutils / Shell | ✅ Завершен | 1.36.1-r2 | Фаза 4 | PIE, SUID, 30 апплетов, UDHCPC ARPING |
| **`ubus`** | IPC шина / Демон | ✅ Завершен | OpenWrt 24 | Фаза 5 | `ubusd`, `ubus` CLI, `libubus` (2025.x) |
| **`ubox`** | Системные хелперы | ✅ Завершен | OpenWrt 24 | Фаза 6 | `kmodloader`, `logd`, `validate_data` |
| **`fstools`** | Файловые системы | ✅ Завершен | OpenWrt 24 | Фаза 7 | `mount_root`, `block`, `ubi-utils` |
| **`procd`** | Демон инициализации | ✅ Завершен | OpenWrt 24 | Фаза 8 | `init`, `procd`, `service`, `hotplug.json`, PID 1 |
| **`netifd`** | Сетевой демон | ✅ Завершен | OpenWrt 24 | Фаза 9 | `netifd` 2025.x, ucode, packet-steering |
| **`jsonfilter`** | Парсер JSON | ✅ Завершен | OpenWrt 24 | Фаза 10.1 | Слинкован с libubox/libjson-c |
| **`usign`** | Верификатор подписей | ✅ Завершен | OpenWrt 24 | Фаза 10.1 | Нативный `usign` / `signify` |
| **`openwrt-keyring`**| Открытые ключи | ✅ Завершен | OpenWrt 24 | Фаза 10.1 | Ключи OpenWrt 24.10 |
| **`fwtool`** | Метаданные образов | ✅ Завершен | OpenWrt 24 | Фаза 10.1 | Утилита манипуляции образами |
| **`base-files`** | Базовая система | ✅ Завершен | OpenWrt 24 | Фаза 10.2 | Нативный `base-files` + оверлей `rd15` (Проверено на роутере) |
| **`opkg`** | Менеджер пакетов | ✅ Завершен | OpenWrt 24 | Фаза 11 | `opkg`, `uclient-fetch`, `libuclient` |
| **`libustream-mbedtls`** | TLS бэкенд | ✅ Завершен | OpenWrt 24 | Фаза 11 | mbedTLS 3.6.x + `ca-bundle` |
| **`urngd` / `urandom-seed`** | Энтропия CSPRNG | ✅ Завершен | OpenWrt 24 | Фаза 11 | Jitter RNG daemon + urandom seed |
| **`dnsmasq`** | DNS / DHCP сервер | ✅ Завершен | 2.90 | Фаза 12 | Резолвер + DHCP пул `192.168.1.100-249` (Проверено на роутере) |
| **`kmod-pwm-rgb` / `diag.sh`** | Светодиодная индикация | ✅ Завершен | OpenWrt 24 | Фаза 13 | RGB LED (`/sys/class/leds/rgb`), `xqled` CLI (Проверено на роутере) |
| **`kmod-gpio-button-hotplug`** | Кнопки Reset & Mesh | ✅ Завершен | OpenWrt 24 | Фаза 13 | `/etc/rc.button/reset` & `/etc/rc.button/mesh` (Проверено на роутере) |

---

## 5. Финальный состав вендорного фида (`vendor_scripts/packages.list` / `required.list`)

В фиде `vendor_feed` включены необходимые аппаратные компоненты:

```text
kmod-bootconfig
kmod-qca-nss-dp
kmod-yt-9215s-driver
kmod-yt-phy-driver
kmod-pwm-rgb
kmod-gpio-button-hotplug
kmod-leds-gpio
nvram
qca-ssdk-shell
yt-9215s-client
```

### Классификация компонентов:

1. **Модули ядра (`kmod-*`) — Аппаратные драйверы ядра 5.4.213**:
   - `kmod-bootconfig` — чтение параметров bootloader.
   - `kmod-qca-nss-dp` — драйвер NSS Data Path сетевых интерфейсов `eth0`, `eth1`.
   - `kmod-yt-9215s-driver` — драйвер свитча Motorcomm YT9215S (`switch1`).
   - `kmod-yt-phy-driver` — драйвер Ethernet PHY Motorcomm.
   - *Транзитивные kmod*: `kmod-qca-ssdk-nohnat`, `kmod-qca-nss-ppe`, `kmod-nat46`, `kmod-bonding` и др.
   - ⚠️ **Не подлежат замене**, жестко привязаны к ядру Linux 5.4.213.

2. **Аппаратные Vendor Userland утилиты**:
   - `nvram` — `/usr/sbin/nvram` (доступ к разделу параметров factory/bootconfig).
   - `qca-ssdk-shell` — `/usr/sbin/ssdk_sh` (утилита Qualcomm Switch SDK & PPE).
   - `yt-9215s-client` — `/usr/sbin/switch_ctl` (управление режимами аппаратного коммутатора YT9215S).
   - ⚠️ Работают изолированно через механизм версионирования `ld-vendor.so.1` и `v_lc.so` (`libc-vendor`).

---

## 6. Ключевые скрипты сборки

- **`vendor_scripts/prepare_feed.sh`**: Главный скрипт распаковки стоковой прошивки, генерации фида и наложения всех патчей.
- **`vendor_scripts/patch_package.py`**: Модификатор бинарников под `ld-vendor.so.1` и переименованные библиотеки `v_l*.so`.
- **`vendor_scripts/patch_procd.py`**: Добавление `uci_load_validate` в `lib/functions/procd.sh`.
- **`vendor_scripts/patch_dropbear.py`**: Удаление вендорских ограничений доступа и генерация SSH RSA хост-ключа.
- **`upload_ubi_rd15.sh`**: Скрипт автоматической загрузки собранного `factory.ubi` (`bin/targets/ipq53xx/rd15/*factory.ubi`) на роутер по SFTP в `/tmp/root.ubi`.

---

### ✅ Фаза 14: Интеграция Firewall3, iptables и ядерных модулей Netfilter
- **Что сделано**:
  1. **Исследование механизма прокидывания и подмены ядерных модулей OpenWrt**:
     - В OpenWrt пакет `firewall` (и `iptables-zz-legacy`, `xtables-legacy`) по умолчанию зависят от символов `+kmod-ipt-core`, `+kmod-ipt-conntrack`, `+kmod-ipt-nat`.
     - При сборке с предсобранным монолитным ядром 5.4.213 система сборки OpenWrt пытается компилировать нативные `KernelPackage` из нескомпилированного дерева 6.6, что приводило к ошибке отсутствия `.ko` файлов.
     - Для решения:
       - В `vendor_scripts/generate_feed.py` реализована автоматическая генерация `PROVIDES:={pkg}` для всех `kmod-*` пакетов с разрешением транзитивных зависимостей (`EXTRA_KMOD_DEPS`).
       - В Makefiles пакетов `package/network/config/firewall/Makefile` и `package/network/utils/iptables/Makefile` зависимости на `kmod-ipt-*` переведены на вендорские аналоги (`kmod-ipt-core-vendor`, `kmod-ipt-nat-vendor` и т.д.).
       - В `Package/libxtables`, `Package/libip4tc`, `Package/libip6tc`, `Package/libiptext*` добавлена явная зависимость `+libgcc` для прохождения валидации зависимостей `CheckDependencies`.
  2. **Сборка юзерспейс-компонентов**:
     - Собраны нативные `/sbin/fw3`, `/usr/sbin/xtables-legacy-multi`, `/usr/sbin/iptables`, `/usr/sbin/iptables-save`, `/usr/sbin/iptables-restore`, `/usr/sbin/ip6tables`.
     - Библиотеки `libxtables.so.12`, `libip4tc.so.2`, `libip6tc.so.2`, `libiptext.so.0`, `libiptext6.so.0`.
  3. **Конфигурация UCI Firewall**:
     - Создан стандартный `/etc/config/firewall` с зонами `lan` (ACCEPT) и `wan` (REJECT + Masquerading/NAT), правилом `Allow-SSH-WAN` (для предотвращения блокировки доступа при тестировании) и цепочками проброса.
  4. **Ядерные модули Netfilter**:
     - Интегрированы в образ и настроены на автозагрузку в `/etc/modules.d/` все необходимые модули ядра 5.4.213: `ipt_core`, `ipt_nat`, `ipt_conntrack`, `xt_MASQUERADE`, `xt_conntrack`, `xt_state`, `xt_nat`, `nf_nat`, `nf_conntrack`, `nf_reject_ipv4`, `nf_reject_ipv6`, `iptable_filter`, `iptable_nat`, `iptable_raw`, `iptable_mangle`.
- **Результат**: Собран полный образ фабричной прошивки `bin/targets/ipq53xx/rd15/openwrt-ipq53xx-rd15-xiaomi-rd15-prebuild-squashfs-factory.ubi` с поддержкой Firewall3, iptables и NAT Masquerade.

---

## 🗺️ Дорожная карта дальнейшей разработки (Next Steps)

Базовый стратегический план поэтапной доработки функционала роутера:

```
┌────────────────────────────────────────────────────────────────────────┐
│ ✅ Шаг 0 (Фундамент): Базовая ОС + SSH (Завершено)                     │
│ • Ядро 5.4.213 + qca-nss-dp + yt_switch/yt_phy                         │
│ • Нативный OpenWrt 24 userland (procd, ubus, ubox, netifd, uci)        │
│ • RAMFS /etc, UBIFS /data, swconfig, DHCP-клиент br-lan, SSH           │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 🔄 Шаг 1: Базовый проводной маршрутизатор (В процессе)                 │
│ • [x] opkg + ca-bundle + libustream-mbedtls + mbedtls (TLS-стек)       │
│ • [x] dnsmasq — раздача DHCP и DNS клиентам в LAN                      │
│ • [x] firewall3 (fw3) + iptables-legacy — межсетевой экран и NAT (WAN) │
│ • [x] urandom-seed / urngd — подсистема энтропии                       │
│ • [ ] ppp + ppp-mod-pppoe — поддержка PPPoE-подключений провайдера     │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ ✅ Шаг 3: Аппаратная периферия и индикация (Завершено)                 │
│ • kmod-gpio-button-hotplug — обработка кнопок Reset и Mesh             │
│ • kmod-pwm-rgb + /sbin/xqled — RGB светодиодная индикация              │
│ • Интеграция событий кнопок и статуса загрузки в /etc/diag.sh          │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ ⏳ Шаг 2: Аппаратное ускорение маршрутизации (Qualcomm PPE / NSS ECM)   │
│ • kmod-qca-nss-ppe + kmod-qca-nss-ecm-premium + kmod-qca-ssdk-nohnat   │
│ • Интеграция ECM в netifd / firewall (оффлоадинг conntrack потоков)    │
│ • Тестирование multi-gigabit throughput (iperf3 2.5 Gbps, ~0% CPU)     │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ ⏳ Шаг 4: Веб-интерфейс управления (LuCI)                               │
│ • luci-core, rpcd, uhttpd / nginx                                      │
│ • luci-app-firewall, luci-app-opkg                                     │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ ⏳ Шаг 5: Беспроводной стек (Wi-Fi 7 / QCN6432)                         │
│ • Драйверы kmod-qca-wifi / ath12k, прошивки firmware                   │
│ • Стек qca-hostap / wpa_supplicant, конфигурация радиоинтерфейсов      │
└────────────────────────────────────────────────────────────────────────┘
```


