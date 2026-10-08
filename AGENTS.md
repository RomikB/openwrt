# Инструкции и архитектурные правила для AI-агентов (AGENTS.md)

Проект: Кастомная прошивка **OpenWrt 24 (24.10 / master)** для маршрутизатора **Xiaomi Router BE3600 (RD15)** на ядре **Linux 5.4.213 (Qualcomm QSDK 12.4)**.

---

## 1. Системный профиль и таргеты

* **SoC**: Qualcomm IPQ5332 (4x Cortex-A7 @ 1.1 GHz).
* **Сетевые интерфейсы**:
  * **RD15**: `eth0` (Uplink 1G к свитчу YT9215S: LAN 1–3, WAN), `eth1` (2.5G LAN 4 к трансиверу QCA8081 / YT8821).
  * **RD16**: `eth0` (Uplink 1G к свитчу YT9215S: все 4 порта LAN 1–3, LAN 4/Port 0 и WAN обслуживаются свитчем YT9215S; порт 2.5G отсутствует).
* **Свитч**: Motorcomm YT9215S (5-портовый GE свитч: LAN 1–3, WAN; на RD16 дополнительно задействован Port 0 как LAN 4).
* **Wi-Fi**: 2.4 GHz On-SoC IPQ5312 (`ath0`, HE40) + 5 GHz PCIe QCN6432 (`ath1`, HE160/EHT160). Раздельные калибровочные файлы BDF `bdwlan.b0060` изолированы по подплатформам.
* **Целевые сабтаргеты**:
  * `target/linux/ipq53xx/rd15/` (Xiaomi Router BE3600 с портом 2.5G)
  * `target/linux/ipq53xx/rd16/` (Xiaomi Router BE3600 без порта 2.5G, 4x GE)
* **Профили сборки RD15 (`target/linux/ipq53xx/image/rd15.mk`)**:
  * `xiaomi-rd15-qsdk` / `xiaomi-rd15-prebuild` — чистые релизные профили без пакетов обхода блокировок. **Основной релизный профиль: `qsdk`**.
  * `xiaomi-rd15-qsdk-ruantiblock` / `xiaomi-rd15-prebuild-ruantiblock` — профили со стеком RuAntiBlock, Zapret2 и AmneziaWG.
  * `xiaomi-rd15-qsdk-podkop` / `xiaomi-rd15-prebuild-podkop` — профили со стеком Podkop (sing-box), Zapret2 и AmneziaWG.
  * `xiaomi-rd15-qsdk-dev` — профиль разработчика (открытый WAN-доступ SSH/HTTP/HTTPS/iperf3, утилиты `iperf3`, `htop`, `tcpdump`, пакет `rd15-dev-mode`, тестовый стенд стокового Wi-Fi `wifi-stock-test`).
  * `xiaomi-rd15-prebuild-diag` — диагностический профиль на prebuild-ядре с пакетом `rd15-hwdiag` (автосбор всех логов в `/data` и автоматический rollback в соседний rootfs при аппаратной несовместимости).
* **Профили сборки RD16 (`target/linux/ipq53xx/image/rd16.mk`)**:
  * `xiaomi-rd16-qsdk` / `xiaomi-rd16-prebuild` — чистые релизные профили.
  * `xiaomi-rd16-qsdk-podkop` / `xiaomi-rd16-prebuild-podkop` — профили со стеком Podkop (sing-box), Zapret2 и AmneziaWG.

---

## 2. Жесткие ограничения (Critical Invariants) — НЕ НАРУШАТЬ!

### 2.1. Лимиты флеш-памяти (Бюджет UBI)
* **`ubi0` (~38 МБ суммарно)**: Содержит SquashFS ROM + оверлей `rootfs_data`.
  * **СТРОГО ЗАПРЕЩЕНО** добавлять тяжелые пакеты (`python`, `samba4`, `transmission`, debug symbols, `valgrind`) в `DEFAULT_PACKAGES` в `target.mk`.
  * Размер сжатого SquashFS образа не должен превышать **24–26 МБ**, иначе у пользователя не останется места под сохранение настроек в overlay.
* **`ubi1` (~20 МБ)**: Монтируется в `/data` и используется для опциональных пакетов пользователя (`opkg -d data`).

### 2.2. Правило двух компиляторов и вермаджик (Vermagic)
* Стоковый вермаджик: **`5.4.213 SMP preempt mod_unload ARMv7 p2v8`**.
* Ядро и ВСЕ модули ядра (`kmod-*`) компилируются **строго выделенным тулчейном ядра GCC 7.5.0** (`vendor_toolchain/`, путь в staging: `staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel`).
* Пакеты пространства пользователя (userland) компилируются **штатным GCC 13.3.0** (OpenWrt).
* **СТРОГО ЗАПРЕЩЕНО** менять компилятор ядра на GCC 13 или модифицировать флаги вермаджика ядра.

### 2.3. Межсетевой экран и аппаратный оффлоад PPE
* В системе штатно используется **`firewall4`** (`nftables 1.1.x` + `ucode`).
* **СТРОГО ЗАПРЕЩЕНО** включать программный `flow_offloading='1'` или `flow_offloading_hw='1'` в `/etc/config/firewall`. Программный `flowtable` перехватывает пакеты на сетевом `ingress` до точки `POST_ROUTING`, лишая `ecm.ko` возможности передать сессии в аппаратный кремниевый акселератор Qualcomm PPE (2.5 Gbps Line Rate).

### 2.4. Изоляция библиотек вендора (`ld-vendor`)
* Закрытые вендорные демоны (`qca-hostapd`, `cnssdaemon`, `nvram-vendor`) работают через изолированный загрузчик `/lib/ld-vendor.so.1` и библиотеки с префиксом `v_l*.so` (`v_lc.so`, `v_lssl.so.1.1`).
* **ЗАПРЕЩЕНО** перелинковывать закрытые бинарники вендора напрямую с системным Musl libc или OpenSSL 3.x.

### 2.5. Регуляторный домен Wi-Fi (CN BDF)
* Заводские калибровки в `0:ART` привязаны к Китаю. В `/lib/wifi/hostapd_config.sh` и `mac80211.sh` задан `country_code=CN` и `ieee80211d=1` (стоковое поведение). Физический регуляторный домен радиомодулей (`wifi0`, `wifi1`) переключается через `cfg80211tool wifiX setCountry CN`, разблокируя каналы 12–13 и мощность до 33 dBm.

### 2.6. Языковые стандарты и стиль коммитов (Language & Commit Policy)
* Комментарии в исходном коде и описания коммитов Git (commit messages) пишутся исключительно на английском языке.
* Сообщения коммитов (commit messages) оформляются строго в стиле OpenWrt: префикс подсистемы/пакета (`<target/subtarget>:`, `<package>:`, `docs:`), краткое описание в повелительном наклонении (imperative mood, e.g. `add`, `fix`, `migrate`), без точки в конце первой строки.
* Основным языком документации является русский (но не единственным).

### 2.7. Скрипты инициализации Preinit
* **СТРОГО ЗАПРЕЩЕНО** использовать `exit 0` в скриптах каталога `/lib/preinit/`. Скрипты preinit подключаются через сорсинг (`. "$file"`), и прямой вызов `exit 0` немедленно завершает процесс PID 1, вызывая панику ядра и bootloop.
* Для досрочного завершения или безопасных заглушек использовать строго: `return 0 2>/dev/null || exit 0`.

### 2.8. Архитектура размещения файлов платформы (`base-files`)
* Все платформенные скрипты, сервисы и конфигурации маршрутизатора RD15 размещаются строго в оверлее сабтаргета `target/linux/ipq53xx/rd15/base-files/`.
* Запрещено модифицировать ванильные системные файлы в апстримных пакетах (`package/base-files/`).

---

## 3. Сборочные команды и скрипты

| Задача | Команда |
| :--- | :--- |
| **Сборка тулчейна ядра GCC 7.5.0** | `./vendor_scripts/build_kmod_toolchain.sh` |
| **Генерация vendor_feed из стока** | `./vendor_scripts/prepare_feed.sh [rd15|rd16] [firmware.bin]` *(по умолчанию RD15)* |
| **Патчинг внешних фидов OpenWrt** | `./vendor_scripts/patch_feeds.py` |
| **Применение defconfig сабтаргета** | `./vendor_scripts/prepare_config.sh [rd15|rd16]` *(по умолчанию RD15)* |
| **Компиляция ядра и образов** | `make target/linux/compile -j$(nproc)` / `make -j$(nproc)` |
| **Путь к собранным UBI-образам** | `bin/targets/ipq53xx/{rd15,rd16}/` |

---

## 4. Индекс-карта документации (Deep-Dive Links)

При выполнении специализированных задач обращайтесь к профильным документам в каталоге `docs/`:

* **Архитектура гибрида, Wi-Fi стек, системные патчи procd/netifd/busybox, BDF**:
  $\to$ [docs/architecture.md](file:///home/romikb/openwrt/docs/architecture.md)
* **Режимы Wi-Fi (AP, Multi-SSID Guest, STA/WISP), LuCI, матрица и статус**:
  $\to$ [docs/wifi_architecture_and_modes.md](file:///home/romikb/openwrt/docs/wifi_architecture_and_modes.md)
* **Трассировка команд вендорного драйвера QSDK (171 вызов cfg80211tool/wlanconfig/hostapd)**:
  $\to$ [docs/stock_wifi_driver_trace.md](file:///home/romikb/openwrt/docs/stock_wifi_driver_trace.md)
* **Коммутатор Motorcomm YT9215S, сетевой стек, ревизии 2.5G PHY (QCA8081 / YT8821), 4 патча драйвера, DSA**:
  $\to$ [docs/switch_yt9215s.md](file:///home/romikb/openwrt/docs/switch_yt9215s.md)
* **Ядро QSDK 12.4, аудит 18 модулей PPE/ECM/SSDK/Switch, конвейер vendor_feed**:
  $\to$ [docs/kernel_and_vendor_feed.md](file:///home/romikb/openwrt/docs/kernel_and_vendor_feed.md)
* **Firewall4 (nftables), аппаратный оффлоад PPE/ECM, стенд и методика iperf3**:
  $\to$ [docs/networking_and_firewall.md](file:///home/romikb/openwrt/docs/networking_and_firewall.md)
* **Безопасность, обход блокировок (Zapret2, RuAntiBlock), VPN (AmneziaWG) и DNS**:
  $\to$ [docs/security_and_bypasses.md](file:///home/romikb/openwrt/docs/security_and_bypasses.md)
* **Дорожная карта, бюджет флеш-памяти и активный бэклог (AmneziaWG, LuCI)**:
  $\to$ [docs/roadmap.md](file:///home/romikb/openwrt/docs/roadmap.md)
* **Архив исторических логов и завершенных отчетов**:
  $\to$ [docs/archive/](file:///home/romikb/openwrt/docs/archive/) (`stock_wifi_bridge_mlo_and_mesh_analysis.md`, `channel_12_13_regulatory.md`, `dmesg_analysis.md`, `amneziawg_kernel54.md`, `qsdk_audit_notes.md`, `migration_to_1081_kernel.md`)


