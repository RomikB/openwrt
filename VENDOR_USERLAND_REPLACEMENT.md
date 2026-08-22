# Xiaomi Router BE3600 (RD15) — Нативный Userland OpenWrt 24 на ядре Linux 5.4.213

## 1. Цель проекта и архитектурная концепция

Проект переводит маршрутизатор **Xiaomi Router BE3600 (RD15)** (SoC Qualcomm IPQ5332, свитч Motorcomm YT9215S, ядро 5.4.213) на стандартный открытый стек **OpenWrt 24 (master / 24.10)** с полным сохранением аппаратных возможностей:
- **Оригинальное ядро Linux 5.4.213** и все проприетарные модули ядра (`qca-nss-dp`, `qca-ssdk`, `qca-nss-ppe`, `yt_switch`, `yt_phy_module`, `ecm`, `umac`, `wifi_3_0`).
- **Аппаратное ускорение маршрутизации (Qualcomm PPE / NSS ECM)** — Line Rate 2.5 Gbps при околонулевой нагрузке на CPU (~0–1%).
- **Беспроводной стек Wi-Fi 6 / 7 (Qualcomm Direct Connect)** — полоса 160 МГц (`HE160` / `EHT160`), WPA2/WPA3 Mixed с PMF, аппаратный оффлоад Wi-Fi трафика.
- **Изоляция вендорного окружения** через механизм динамического версионирования библиотек (`ld-vendor.so.1`, `v_lc.so`, `v_lssl.so.1.1` и др.), исключающий конфликты между Musl libc / OpenSSL 3.x в OpenWrt 24 и стоковыми бинарниками.

---

## 2. Схема архитектуры гибридного окружения

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Ядро Linux 5.4.213                              │
│  qca-nss-dp.ko ─── Сетевые интерфейсы eth0 (WAN/LAN), eth1 (2.5G LAN)  │
│  yt_switch.ko, yt_phy_module.ko ─── Коммутатор YT9215S & Ethernet PHY  │
│  qca-nss-ppe.ko, qca-ssdk.ko, ecm.ko ─── Аппаратный акселератор PPE/ECM │
│  umac.ko, qca_ol.ko, wifi_3_0.ko, ecm-wifi-plugin.ko ─── Wi-Fi 6/7     │
│  bootconfig.ko, pwm-rgb.ko, gpio-button-hotplug.ko ─── Периферия       │
└────────────────────────────────────────────────────────────────────────┘
                                   ↕
┌────────────────────────────────────────────────────────────────────────┐
│                  OpenWrt 24 Нативный Userland (Musl)                   │
│                                                                        │
│  • Системный менеджер & Init: /sbin/init, /sbin/procd (PID 1)          │
│  • Системная шина & IPC: /sbin/ubusd, /bin/ubus (Libubus 2025.x)       │
│  • Сетевой стек: /sbin/netifd, /lib/network/config.sh, packet-steering │
│  • Управление конфигурацией: /sbin/uci, /etc/config/*                  │
│  • Сетевой экран & NAT: /sbin/fw3, /usr/sbin/iptables, xtables         │
│  • DNS & DHCP: /usr/sbin/dnsmasq (v2.90, LAN пул 192.168.1.100-249)    │
│  • PPPoE & IPv6: /usr/sbin/pppd (2.5.1), odhcp6c, odhcpd-ipv6only      │
│  • Веб-интерфейс: LuCI (ucode stack), /usr/sbin/uhttpd, /sbin/rpcd     │
│  • Пакетный менеджер & TLS: /bin/opkg, mbedtls, /sbin/urngd (CSPRNG)   │
│  • Утилиты & Shell: /bin/busybox (1.36.1-r2, PIE, SUID, 30+ апплетов)  │
│  • Файловые системы: /sbin/mount_root, /sbin/block, ubi-utils, ext4    │
│  • Индикация & Кнопки: /sbin/xqled (RGB LED), /etc/rc.button/reset     │
│  • Системные хелперы: /sbin/kmodloader, /sbin/logd, jsonfilter, usign  │
│  • Wi-Fi интеграция: /lib/wifi/hostapd_config.sh, /sbin/wifi, iwinfo   │
└────────────────────────────────────────────────────────────────────────┘
                                   ↕
┌────────────────────────────────────────────────────────────────────────┐
│              Vendor Userland (Изолирован через ld-vendor)              │
│                                                                        │
│  • /sbin/phyhelper ─── Управление питанием и режимами Ethernet PHY     │
│  • /usr/sbin/switch_ctl ─── Аппаратный контроль коммутатора YT9215S    │
│  • /usr/sbin/ssdk_sh ─── Qualcomm Switch SDK & PPE Control Shell       │
│  • /usr/sbin/nvram ─── Чтение заводских MAC-адресов и калибровок       │
│  • /usr/sbin/hostapd ─── Аутентификатор Qualcomm Direct Connect        │
│  • /usr/sbin/cnssdaemon ─── Демон шины PCIe радиомодуля QCN6432        │
│  Линковка: ld-vendor.so.1 → v_lc.so, v_lssl.so.1.1, v_lcrypto.so.1.1   │
└────────────────────────────────────────────────────────────────────────┘
```

### Механизм изоляции и запуска вендорных библиотек (ELF-версионирование)

Для запуска закрытых вендорных бинарников без пересборки и исключения конфликтов с Musl libc и OpenSSL 3.x из OpenWrt 24 реализована схема полной изоляции:
1. **Префикс вендорных библиотек**: Все разделяемые библиотеки стоковой системы переименованы с префиксом `v_l*` (например, `libc.so` $\to$ `v_lc.so`, `libubox.so` $\to$ `v_lubox.so`, `libssl.so.1.1` $\to$ `v_lssl.so.1.1`, `libcrypto.so.1.1` $\to$ `v_lcrypto.so.1.1`, `libgcc_s.so.1` $\to$ `v_lgcc_s.so.1`).
2. **Изолированный динамический компоновщик**: Интерпретатор `PT_INTERP` во всех исполняемых бинарниках вендора перенаправлен на `/lib/ld-vendor.so.1`.
3. **Обновление заголовков ELF**: Поля `DT_SONAME` и `DT_NEEDED` во всех ELF-файлах модифицированы на имена с префиксом `v_l*`, что гарантирует связывание зависимостей строго внутри изолированного вендорного дерева.
4. **Утилиты и симлинки**: Библиотечные симлинки перенаправлены на `v_l*` цели, а вендорный `ldd` переименован в `vldd`.

---

## 3. Реализованные системные компоненты

### 1. Базовый стек ОС и инициализация:
* **`procd` (PID 1) и `init`**: Стандартный диспетчер процессов OpenWrt 24 со скриптами `/etc/rc.common`, валидацией `uci_load_validate()` и диспетчером `/etc/hotplug.json`.
* **`ubus` и `ubox`**: IPC-шина `ubusd`, утилита `ubus`, системный загрузчик модулей ядра `/sbin/kmodloader`, демоны системного логирования `/sbin/logd` и `/sbin/logread`.
* **`busybox` (v1.36.1-r2)**: Скомпилирован с поддержкой `CONFIG_BUSYBOX_DEFAULT_PIE=y` и `CONFIG_BUSYBOX_DEFAULT_FEATURE_SUID=y` (требование ASLR ядра Qualcomm), включены 30 расширенных апплетов (`timeout`, `stat`, `devmem`, `watch`, `arping`, `wget`, `xz` и др.) и поддержка опции `udhcpc -a` (ARP Ping).
* **Файловая система и память**: Нативный `base-files` с оверлеем `rd15` (`target/linux/ipq53xx/rd15/base-files/`). Preinit-монтирование RAMFS поверх `/etc` и UBIFS поверх `/data`.

### 2. Сетевая подсистема и маршрутизация:
* **`netifd` (2025.x)**: Сетевой демон OpenWrt со скриптом SMP Packet Steering `/usr/libexec/network/packet-steering.uc`. Мост `br-lan` объединяет порты `eth0.2`, `eth0.3`, `eth1` (IP `192.168.1.1/24`), WAN поднят на `eth0.1` (`proto dhcp`).
* **`swconfig`**: Управление коммутатором Motorcomm YT9215S (`switch1`) с аппаратными хуками `switch_ctl forward 0 / 1`.
* **`dnsmasq` (v2.90)**: Локальный DNS-резолвер (`openwrt.lan`) и DHCP-сервер LAN с пулом `192.168.1.100` – `192.168.1.249`.
* **`firewall` (fw3) & `iptables`**: Межсетевой экран Firewall3, трансляция адресов NAT Masquerade, защита зон, правила доступа SSH и LuCI.
* **PPPoE & IPv6**: Пакет `ppp` (v2.5.1) со связкой `pppd` / `rp-pppoe.so`, клиент `odhcp6c` (интерфейс `wan6`) и сервер `odhcpd-ipv6only` (SLAAC, RA, DHCPv6).

### 3. Веб-интерфейс LuCI и утилиты:
* **LuCI**: Современный интерфейс управления на базе `ucode` и JS (`luci-mod-admin-full`, тема `luci-theme-bootstrap`, приложения `luci-app-firewall`, `luci-app-package-manager`, `luci-proto-ppp`, `luci-proto-ipv6`). Веб-сервер `uhttpd` и демон `rpcd` настроены на доступ как через LAN, так и через WAN (порты 80/443).
* **Пакетный менеджер и криптография**: Нативный `opkg` со связкой `uclient-fetch`, библиотека `libustream-mbedtls` (mbedTLS 3.6.x), корневые сертификаты `ca-bundle`, генератор энтропии `urngd` (Jitter Entropy CSPRNG).
* **Диагностика и бенчмарк**: Интегрированы `iperf3` (v3.17.1) и `htop` (v3.4.1) для профилирования пропускной способности и per-core нагрузки CPU.
* **Периферия**: Управление RGB светодиодом `/sbin/xqled` (`kmod-pwm-rgb`, индикация загрузки и работы в `/etc/diag.sh`), обработка кнопок Reset и Mesh (`kmod-gpio-button-hotplug`, скрипт сброса `/etc/rc.button/reset`).

---

## 4. Аппаратное ускорение маршрутизации (Qualcomm PPE / NSS ECM)

В прошивке активирован полнофункциональный кремниевый оффлоад сетевого трафика:
* **Диспетчер ECM**: Модуль `ecm.ko` (`kmod-qca-nss-ecm-premium-vendor`) отслеживает Conntrack-сессии и передает их на аппаратную обработку в движок Qualcomm PPE.
* **Драйверы акселератора PPE**: `qca-ssdk.ko`, `qca-nss-ppe.ko`, `qca-nss-ppe-vp.ko`, `qca-nss-ppe-rule.ko`, `qca-nss-ppe-bridge-mgr.ko`, `qca-nss-ppe-vlan-mgr.ko`, `qca-nss-ppe-pppoe-mgr.ko`, `qca-nss-ppe-lag-mgr.ko`, `qca-nss-sfe.ko`.
* **Производительность**: При стресс-тестировании маршрутизации LAN ↔ WAN через `iperf3` обеспечивается полная утилизация полосы пропускания (Line Rate 2.5 Gbps) при загрузке CPU ~0–1%.

---

## 5. Беспроводной стек Wi-Fi 6 / 7

Беспроводной стек построен на проприетарных драйверах **Qualcomm Direct Connect** и изолированном аутентификаторе `hostapd`:
* **Аппаратные радиомодули**:
  * 2.4 GHz On-SoC IPQ5312 (VAP `ath0`, ширина 20/40 МГц `HE40`, 2x2 MIMO).
  * 5.0 GHz PCIe QCN6432 (VAP `ath1`, широкая полоса 160 МГц `HE160` / `EHT160`, 2x2 MIMO).
* **Минимальный набор пакетов Wi-Fi с аппаратным ускорением** (входит в [packages.list](vendor_scripts/packages.list)):
  1. `kmod-qca-nss-ecm-wifi-plugin` — плагин оффлоада Wi-Fi трафика в движок Qualcomm PPE/ECM (FSE классификация и MSCS QoS).
  2. `qca-cnss-daemon` — демон шины PCIe и загрузки прошивки для радиомодуля QCN6432.
  3. `qca-firmware` — бинарные прошивки и микрокод радиочипов.
  4. `qca-hostap` — изолированный WPA2/WPA3 аутентификатор hostapd под супервизором `procd`.
  5. `qca-hostapd-cli` — CLI-утилита опроса и управления hostapd.
  6. `qca-wifi-scripts` — скрипты инициализации радиомодулей.
  7. `qca-wpa-cli` и `qca-wpa-supplicant` — клиентские компоненты WPA.
  8. `wififw_mount_script` — монтирование заводских BDF-калибровок `caldata.bin` из раздела `0:ART`.
  *(Транзитивно драйвер ядра `kmod-qca-wifi-lowmem-profile` подтягивается автоматически).*
* **Интеграция с LuCI и управление**: Конфигурация через `/etc/config/wireless`, служба `/lib/netifd/wireless/mac80211.sh` и CLI `/sbin/wifi`.

> 📖 **Полная техническая документация по Wi-Fi**: Подробное описание архитектуры радиомодулей, параметров 160 МГц, DFS CAC, MLO, патчей `libiwinfo` и работы hostapd вынесено в отдельный специализированный документ — **[WIFI_ROADMAP.md](WIFI_ROADMAP.md)**.

---

## 6. Модификации системных пакетов и патчи фидов

В процессе интеграции OpenWrt 24 на монолитном ядре 5.4.213 были внедрены следующие патчи и адаптации:

### 1. Системные патчи в дереве `package/`:
* **`procd`** (`package/system/procd/patches/001-compat-ubus-symlink.patch`):
  * Выставление прав доступа `01777` на `/tmp/run` при раннем монтировании в `initd/early.c`.
  * Создание симлинка `/var/run/ubus.sock -> /var/run/ubus/ubus.sock` от имени `root` при старте `procd` до перехода `ubusd` под пользователя `ubus`.
* **`ubus`** (`package/system/ubus/patches/001-compat-symlink.patch`):
  * Поддержка обратной совместимости сокета для устаревших вендорных клиентов (`switch_ctl`, `nvram`).
* **`netifd`** (`package/network/config/netifd/patches/`):
  * `001-fix-ifname-fixup-for-non-bridges.patch` — корректная обработка `ifname -> ports` только для мостов.
  * `002-fix-bridge-netlink-attrs.patch` — предотвращение отправки неподдерживаемых Netlink-атрибутов моста (`IFLA_BR_VLAN_FILTERING`) в ядро 5.4 без VLAN Filtering и fallback на `ioctl(SIOCBRADDBR)`.

### 2. Адаптация сборочных Makefiles:
* **`package/network/config/firewall/Makefile`** и **`package/network/utils/iptables/Makefile`**:
  * Зависимости на ядро перенаправлены со стандартного нескомпилированного ядра 6.6 на вендорные модули ядра 5.4.213 (`+kmod-ipt-*-vendor`), добавлен `+libgcc` для библиотек `libxtables`, `libip4tc`, `libip6tc`, `libiptext`.
* **`package/network/services/ppp/Makefile`**:
  * Зависимости перенаправлены на `+kmod-ppp-vendor`, `+kmod-pppoe-vendor`, добавлен `+libgcc`.
* **`package/libs/ncurses/Makefile`**:
  * Добавлена явная зависимость `+libgcc` для `Package/libncurses`.

### 3. Автоматизированный патчинг внешних фидов (`vendor_scripts/patch_feeds.py`):
* `feeds/luci/contrib/package/lucihttp/Makefile` — добавление `DEPENDS:=+libgcc`.
* `feeds/packages/net/iperf3/Makefile` — добавление `DEPENDS:=+libatomic +libgcc`.

### 4. Патчи служб вендорного фида (`vendor_scripts/patch_package.py`):
* **Патч службы аппаратного оффлоада `qca-nss-ecm` (`files/etc/init.d/qca-nss-ecm`)**:
  * Исправление заголовка rc.common `#!/bin/sh  /etc/rc.common` на `#!/bin/sh /etc/rc.common`.
  * Замена условия ожидания Wi-Fi `[ -f /tmp/.wifi-config-done ]` на проверку загрузки модуля ядра `[ -d /sys/module/wifi_3_0 ]`.
*(Патчи служб Wi-Fi `qca-hostap` и `load_cnss2` описаны в [WIFI_ROADMAP.md](WIFI_ROADMAP.md)).*

---

## 7. Состав вендорного фида и механизм генерации

Главным инструментом создания вендорного фида является скрипт **[vendor_scripts/prepare_feed.sh](vendor_scripts/prepare_feed.sh)**. Он полностью автоматизирует сборочный конвейер:
1. Распаковывает UBI-образ стоковой прошивки (`ubireader_extract_images` и `unsquashfs`).
2. Извлекает стоковый образ ядра в `target/linux/ipq53xx/rd15/kernel`.
3. Запускает автоматический анализ зависимостей модулей ядра (`extract_kmod_deps.py`).
4. Формирует структуру фида с предварительной валидацией в памяти (`generate_feed.py`).
5. Пропатчивает сгенерированные пакеты (`patch_package.py`).
6. Автоматически регистрирует фид `src-link vendor_feed ../vendor_feed` в `feeds.conf`.

### 1. Обязательный минимум проводного роутера с оффлоадом ([vendor_scripts/required.list](vendor_scripts/required.list)):
Список из **13 пакетов**, необходимых для гарантированной работы роутера как проводного маршрутизатора с аппаратным ускорением:
```text
kmod-bootconfig
kmod-gpio-button-hotplug
kmod-ipt-conntrack-extra
kmod-ipt-ipopt
kmod-ipt-offload
kmod-pwm-rgb
kmod-qca-nss-ecm-premium
kmod-qca-nss-ppe-pppoe-mgr
kmod-yt-9215s-driver
kmod-yt-phy-driver
nvram
qca-ssdk-shell
yt-9215s-client
```

### 2. Входной список пакетов сборки ([vendor_scripts/packages.list](vendor_scripts/packages.list)):
Список из **26 ключевых точек входа**, включающий компоненты Wi-Fi, из которого автоматически разворачиваются все 87 пакетов фида:
```text
kmod-bootconfig
kmod-gpio-button-hotplug
kmod-ipt-conntrack-extra
kmod-ipt-extra
kmod-ipt-filter
kmod-ipt-ipopt
kmod-ipt-nat6
kmod-ipt-offload
kmod-ipt-raw
kmod-pwm-rgb
kmod-qca-nss-ecm-wifi-plugin
kmod-qca-nss-ppe-lag-mgr
kmod-qca-nss-ppe-pppoe-mgr
kmod-yt-9215s-driver
kmod-yt-phy-driver
nvram
qca-cnss-daemon
qca-firmware
qca-hostap
qca-hostapd-cli
qca-ssdk-shell
qca-wifi-scripts
qca-wpa-cli
qca-wpa-supplicant
wififw_mount_script
yt-9215s-client
```

*Пакеты `kmod-qca-nss-dp`, `kmod-qca-nss-ecm-premium` и `kmod-qca-wifi-lowmem-profile` автоматически разрешаются и генерируются через транзитивные зависимости.*

### 3. Вспомогательные скрипты генерации фида:
- **`vendor_scripts/extract_kmod_deps.py`**: Выполняет бинарный анализ экспортируемых и импортируемых символов всех `.ko` файлов распакованного rootfs и формирует карту зависимостей `tmp/kmod_deps.json`.
- **`vendor_scripts/generate_feed.py`**: Считывает `opkg status` и `kmod_deps.json`, строит полный граф зависимостей в памяти, проверяет наличие всех 13 пакетов из `required.list` и генерирует дерево пакетов в `vendor_feed/`.
- **`vendor_scripts/patch_package.py`**: Обрабатывает каждый пакет в сгенерированном фиде — выполняет ELF-версионирование библиотек (`v_l*.so`), перенаправляет интерпертатор на `ld-vendor.so.1` и патчит сервисные init-скрипты (`qca-nss-ecm`, `load_cnss2`, `qca-hostapd`).

---

## 8. Ключевые скрипты сборки и автоматизации

- **`vendor_scripts/prepare_feed.sh`**: Главный скрипт разворачивания вендорного фида из стоковой прошивки.
- **`vendor_scripts/patch_feeds.py`**: Идемпотентный скрипт наложения сборочных зависимостей на внешние фиды OpenWrt (`luci`, `iperf3`).
- **`upload_ubi_rd15.sh`**: Скрипт автоматической загрузки и прошивки собранного образа `factory.ubi` на роутер по SSH/SFTP.

---

## 9. Сводный статус компонентов

| Компонент | Роль | Статус | Реализация |
|---|---|---|---|
| **`dropbear`** | SSH-сервер | ✅ Работает | Нативный OpenWrt 24, RSA 2048-bit |
| **`uci` / `libuci`** | Конфигурация | ✅ Работает | Нативный OpenWrt 24 (2025.x) |
| **`swconfig`** | Свитч YT9215S | ✅ Работает | Нативный OpenWrt 24 + хуки `switch_ctl` |
| **`busybox`** | Coreutils / Shell | ✅ Работает | 1.36.1-r2 (PIE, SUID, 30+ апплетов, UDHCPC ARPING) |
| **`ubus` / `ubusd`** | IPC шина | ✅ Работает | Нативный OpenWrt 24 + symlink compat |
| **`ubox` / `kmodloader`** | Загрузка модулей | ✅ Работает | Нативный OpenWrt 24, `/sbin/logd` |
| **`fstools` / `ubi-utils`**| Файловые системы | ✅ Работает | Нативный OpenWrt 24, UBIFS / SquashFS |
| **`procd` / `init`** | PID 1 менеджер | ✅ Работает | Нативный OpenWrt 24, `hotplug.json` |
| **`netifd`** | Сетевой демон | ✅ Работает | Нативный OpenWrt 24 (2025.x, ucode, packet-steering) |
| **`base-files`** | Базовая система | ✅ Работает | Нативный OpenWrt 24 + оверлей `rd15` (RAMFS /etc, UBIFS /data) |
| **`opkg` / `mbedtls`** | Пакетный менеджер | ✅ Работает | Нативный `opkg`, `uclient-fetch`, TLS, `urngd` |
| **`dnsmasq`** | DNS / DHCP | ✅ Работает | Нативный 2.90, пул `192.168.1.100-249` |
| **`kmod-pwm-rgb` / `diag.sh`** | Светодиодная индикация | ✅ Работает | RGB LED (`/sys/class/leds/rgb`), утилита `/sbin/xqled` |
| **`kmod-gpio-button-hotplug`** | Кнопки Reset & Mesh | ✅ Работает | Аппаратный сброс настроек `/etc/rc.button/reset` |
| **`firewall` / `iptables`** | Firewall3 / NAT | ✅ Работает | Нативный `fw3`, `iptables-legacy`, `xtables`, Netfilter kmods |
| **`ppp` / `pppoe`** | PPPoE клиент | ✅ Работает | Нативный `pppd` 2.5.1, `rp-pppoe.so` |
| **`odhcp6c` / `odhcpd`** | IPv6 клиент / сервер | ✅ Работает | Нативный OpenWrt 24 (SLAAC, RA, DHCPv6) |
| **`luci`** | Веб-интерфейс | ✅ Работает | Нативный LuCI ucode stack, Bootstrap UI, LAN+WAN |
| **`iperf3` / `htop`** | Бенчмарк & Мониторинг | ✅ Работает | Нативные `iperf3` (3.17.1) и `htop` (3.4.1) |
| **`kmod-qca-nss-ppe*` / `ecm`** | Аппаратный оффлоад | ✅ Работает | Qualcomm PPE / NSS ECM, Line Rate 2.5G (~0% CPU) |
| **`kmod-qca-wifi` / `hostapd`** | Wi-Fi 6 / 7 & UCI | ✅ Работает | Qualcomm Direct Connect, `hostapd`, HE160, LuCI UI |

---

## 10. Дорожная карта дальнейшей разработки (Next Steps)

```
┌────────────────────────────────────────────────────────────────────────┐
│ ✅ Шаг 0: Базовая ОС + SSH (Завершено)                                 │
│ • Ядро 5.4.213 + qca-nss-dp + yt_switch/yt_phy                         │
│ • Нативный OpenWrt 24 userland (procd, ubus, ubox, netifd, uci)        │
│ • RAMFS /etc, UBIFS /data, swconfig, DHCP-клиент br-lan, SSH           │
├────────────────────────────────────────────────────────────────────────┤
│ ✅ Шаг 1: Базовый проводной маршрутизатор (Завершено)                  │
│ • opkg + ca-bundle + libustream-mbedtls (TLS-стек)                     │
│ • dnsmasq (DHCP/DNS LAN 192.168.1.1), firewall3 + iptables-legacy      │
│ • urandom-seed / urngd, ppp + pppoe, odhcp6c + odhcpd (IPv6)           │
├────────────────────────────────────────────────────────────────────────┤
│ ✅ Шаг 2: Веб-интерфейс управления LuCI (Завершено)                   │
│ • luci, rpcd, uhttpd + JSON-RPC proxy, firewall/package-manager UI     │
│ • LAN (80) и WAN (80/443) доступ, скрипт patch_feeds.py               │
├────────────────────────────────────────────────────────────────────────┤
│ ✅ Шаг 3: Аппаратная периферия и индикация (Завершено)                 │
│ • kmod-pwm-rgb + /sbin/xqled (RGB LED индикация), diag.sh              │
│ • kmod-gpio-button-hotplug (обработка кнопок Reset и Mesh)             │
├────────────────────────────────────────────────────────────────────────┤
│ ✅ Шаг 4: Аппаратное ускорение маршрутизации (Завершено)               │
│ • kmod-qca-nss-ppe + kmod-qca-nss-ecm-premium + kmod-qca-ssdk         │
│ • Интеграция ECM в netifd / firewall, Line Rate 2.5G (~0% CPU)         │
├────────────────────────────────────────────────────────────────────────┤
│ ✅ Шаг 5: Беспроводной стек Wi-Fi 6/7 и LuCI (Завершено)               │
│ • Qualcomm Direct Connect (umac, qca_ol, wifi_3_0, ipq_cnss2)          │
│ • UCI /etc/config/wireless, /lib/wifi/hostapd_config.sh (HE160/PMF)    │
│ • /sbin/wifi, procd qca-hostapd, патч libiwinfo для мониторинга в LuCI │
│ • Аппаратный Wi-Fi оффлоад kmod-qca-nss-ecm-wifi-plugin (FSE/MSCS)     │
├────────────────────────────────────────────────────────────────────────┤
│ 🔄 Шаг 6: Расширенный функционал и пакеты экосистемы OpenWrt           │
│ • [ ] Интеграция модулей IPset (kmod-ipt-ipset) для списков обхода     │
│ • [ ] Интеграция TPROXY (kmod-ipt-tproxy) для прозрачного прокси       │
│ • [ ] Интеграция Traffic Control / QoS (kmod-sched) для SQM CAKE       │
│ • [ ] Тонкая настройка Multi-Link Operation (MLO mld-wifi0)            │
└────────────────────────────────────────────────────────────────────────┘
```
