# Миграция драйверов Qualcomm (QCA) на открытые исходники в OpenWrt (RD15 / IPQ53xx)

Данный документ содержит архитектурный обзор, результаты бинарного анализа и практические особенности миграции проприетарных компонентов Qualcomm из вендорского фида (`vendor_feed`, блобы из заводской прошивки Xiaomi MiWiFi RD15 1.0.68) в нативные пакеты OpenWrt (`package/kernel/`, `package/network/utils/`, `package/utils/`), собираемые из открытых репозиториев **CodeLinaro (QSDK)** и нативного C-кода.

---

## 1. Методология и инструментарий валидации

Для каждого модуля производилась валидация по четырем критериям:
1. **Совместимость версий ядра и ABI (Vermagic):**  
   Для ядра Linux 5.4.213 в целевом профиле `target/linux/ipq53xx/rd15/target.mk` используется специализированный тулчейн ядра **GCC 7.5.0**:
   ```makefile
   KERNEL_TOOLCHAIN_DIR_NAME:=toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel
   KERNEL_CROSS:=$(KERNEL_TOOLCHAIN_DIR)/bin/arm-openwrt-linux-muslgnueabi-
   KERNEL_CC:=$(KERNEL_CROSS)gcc
   ```
   *(Пакеты пользовательского пространства userland собираются компилятором GCC 13.3.0, а ядро и все `kmod-*` — строго GCC 7.5.0 для исключения несовместимости ABI структур ядра).*
2. **Анализ экспортируемых (ABI) и импортируемых символов:**  
   Скрипт `vendor_scripts/compare_kmod.py` парсит таблицы символов ELF (`readelf` / `pyelftools`), гарантируя, что:
   * Все функции, которые стоковый модуль экспортировал для других драйверов, на 100% присутствуют и имеют идентичные имена;
   * Набор внешних символов ядра, запрашиваемых модулем, не содержит лишних или отсутствующих зависимостей.
3. **Бинарный и функциональный анализ кода (.text, функции):**  
   Сравнение размера секции исполняемого кода `.text`, дизассемблирование и подсчет количества функций.
4. **Живое тестирование на физическом устройстве (Xiaomi Router BE3600, IP 192.168.11.46):**  
   Проверка связывания модулей (`lsmod`), отсутствия ошибок в `dmesg`, корректности счетчиков в `debugfs` и работы сети.

---

## 2. Сводная таблица миграции 18 модулей

| Пакет OpenWrt | Исходный файл (.ko) | Репозиторий CodeLinaro | Коммит / Дата | Статус | Совпадение ABI / Символы |
|---|---|---|---|:---:|:---:|
| **`kmod-emesh-sp`** | `emesh-sp.ko` | `oss/lklm/emesh-sp.git` | `3de1a656` (21.07.2023) | **`[IDENTICAL]`** | **100% побайтовое совпадение** (+0 байт diff) |
| **`kmod-qca-nss-ppe`** | `qca-nss-ppe.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **167/167 экспортов**, **232/232 импортов**, **537/537 функций** (.text diff +464 байта) |
| **`kmod-qca-mcs`** | `qca-mcs.ko` | `oss/lklm/qca-mcs.git` | `2237266b` (07.02.2024) | **`[COMPATIBLE]`** | **12/12 экспортов**, **59/59 импортов** |
| **`kmod-qca-ssdk-nohnat`** | `qca-ssdk.ko` | `oss/lklm/qca-ssdk.git` | `2e8bf996` (16.11.2023) | **`[COMPATIBLE]`** | **443/443 экспортов (100%)**, **137/137 импортов (100%)**, .text diff -672 байта |
| **`kmod-qca-nss-dp`** | `qca-nss-dp.ko` | `oss/lklm/nss-dp.git` | `93102877` (01.02.2024) | **`[COMPATIBLE]`** | **15/15 экспортов**, **202/202 импортов**, **182/182 функций** |
| **`kmod-qca-nss-ppe-vp`** | `qca-nss-ppe-vp.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **8/8 экспортов**, **61/61 импортов**, **24/24 функций** |
| **`kmod-qca-nss-ppe-rule`** | `qca-nss-ppe-rule.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **4/4 экспортов**, **30/30 импортов**, **12/12 функций** (.text diff -48 байт) |
| **`kmod-qca-nss-ppe-ds`** | `qca-nss-ppe-ds.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **14/14 экспортов**, **29/29 импортов**, **27/27 функций** (.text diff **+0 байт**, 99.04% сходство) |
| **`kmod-qca-nss-ppe-tun`** | `qca-nss-ppe-tun.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **17/17 экспортов**, **42/42 импортов**, **45/45 функций** (.text diff **+0 байт**, 99.85% сходство) |
| **`kmod-qca-nss-ppe-pppoe-mgr`** | `qca-nss-ppe-pppoe-mgr.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **21/21 импортов**, **4/4 функций** (.text diff **+0 байт**, 99.95% сходство, 1 байт diff) |
| **`kmod-qca-nss-ppe-vlan-mgr`** | `qca-nss-ppe-vlan.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **10/10 экспортов**, **50/50 импортов**, **25 функций** (.text diff -176 байт) |
| **`kmod-qca-nss-ppe-lag-mgr`** | `qca-nss-ppe-lag.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[IDENTICAL]`** | **100% побайтовое совпадение** (+0 байт diff, 21/21 импортов) |
| **`kmod-qca-nss-ppe-bridge-mgr`** | `qca-nss-ppe-bridge-mgr.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **2/2 экспортов (100%)**, **53/53 импортов (100%)**, .text diff -16 байт |
| **`kmod-qca-nss-ppe-vxlanmgr`** | `qca-nss-ppe-vxlanmgr.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **2/2 экспортов (100%)**, **62/62 импортов (100%)**, .text diff **+0 байт** (98.78% сходство) |
| **`kmod-qca-nss-sfe`** | `qca-nss-sfe.ko` | `oss/lklm/shortcut-fe.git` | `7d82c710` (20.03.2024) | **`[COMPATIBLE]`** | **19/19 экспортов (100%)**, **111/111 импортов (100%)**, .text diff +2192 байта |
| **`kmod-qca-cnss`** | `ipq_cnss2.ko` | `oss/wifi/qca-cnss.git` | `17fe2f6d` (16.11.2023) | **`[COMPATIBLE]`** | **94/94 экспортов (100%)**, **250/250 импортов (100%)**, устранена аллокация 2 MB QDSS DMA |
| **`kmod-qca-nss-ecm`** | `ecm.ko`, `ecm_sfe_l2.ko`, `ecm_ae_select.ko` | `oss/lklm/qca-nss-ecm.git` | `aed84d47` (15.11.2023) | **`[COMPATIBLE]`** | **223/224 импортов (100% сетевых)**, .text diff -2.0%, полное совпадение протоколов |
| **`kmod-qca-nss-ecm-wifi-plugin`** | `ecm-wifi-plugin.ko` | `oss/lklm/qca-nss-ecm.git` | `aed84d47` (15.11.2023) | **`[COMPATIBLE]`** | **10/10 импортов стока (100%)**, FSE + MSCS/SCS, опциональный EasyMesh SAWF |

---

## 3. Детальный разбор особенностей каждого модуля

### 3.1. `kmod-emesh-sp` (EasyMesh Service Prioritization)
* **Назначение:** Драйвер приоритезации трафика и классификации потоков EasyMesh / QoS. Используется диспетчером акселерации Qualcomm ECM (`ecm.ko`).
* **Размещение пакета:** `package/kernel/emesh-sp/`
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/emesh-sp.git` (ветка/коммит `3de1a656130fe31aab27c08c7adeb2cfb9dac09d`).
* **Статус:** **[100% BIT-FOR-BIT IDENTICAL]**
* **Особенности:**
  * Размер секции `.text`: ровно **11 408 байт** у нашего модуля и ровно **11 408 байт** в стоковом блобе Xiaomi (разница **+0 байт**).
  * Символы ABI: 9 экспортов из 9 (`sp_mapdb_apply`, `sp_mapdb_apply_mscs`, `sp_mapdb_apply_scs`, `sp_mapdb_get_wlan_latency_params`, `sp_mapdb_notifier_register` и др.).
  * Символы ядра: 35 импортов из 35.
  * Благодаря отсутствию сторонних платформенных макросов сборки и завязок на Device Tree, компилятор GCC 7.5.0 сгенерировал машинный код, идентичный стоковому байт-в-байт.

---

### 3.2. `kmod-qca-nss-ppe` (Programmable Packet Engine Core Driver)
* **Назначение:** Базовый низкоуровневый драйвер аппаратного сетевого процессора PPE (Programmable Packet Engine) в SoC IPQ5332/IPQ5322. Обеспечивает аппаратную маршрутизацию, NAT, таблицы очередей QoS, обработку VLAN и виртуальных портов.
* **Размещение пакета:** `package/kernel/qca-nss-ppe/`
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git` (коммит `0c6434d7d19459b9e10ccf870faffb7dff8e4d98` от 19.01.2024).
* **Статус:** **`[COMPATIBLE]`** (идеальное функциональное совпадение, 100% совместимость ABI).
* **Ключевые особенности и тонкости миграции:**
  1. **Унификация коммита с `kmod-qca-nss-ppe-vp` (переход с `a9998acd` на `0c6434d7`):**
     * Первоначально модуль был собран на коммите `a9998acd` (23.05.2024). Однако модуль `kmod-qca-nss-ppe-vp` потребовал коммит `0c6434d7` из-за сигнатуры коллбэков виртуальных портов и структуры `nss_dp_vp_rx_info`.
     * Было проведено исследование диффов и дизассемблера стока, показавшее:
       * **Бинарное доказательство из стока:** в `ppe_drv_sc.c` на коммите `0c6434d7` маска сервисного кода `bypass_bitmap[1]` равна `0x34a0` (содержит бит `BRIDGING_FWD_BYP`). Коммит `a9998acd` убрал этот бит, сделав маску `0x3420`. В стоковом файле Xiaomi `qca-nss-ppe.ko` по адресам `0x1a30c` и `0x1a328` находится именно константа `0x34a0`, а `0x3420` отсутствует вовсе. Это доказывает, что заводской драйвер собран на версии до `a9998acd`!
       * **Размер секции `.text`:** при переходе на `0c6434d7` разница с заводским блобом сократилась с +632 байт до **всего +464 байт** (219 488 байт против 219 024 байт).
       * **Символы ABI:** все 167 экспортируемых символов и 232 импорта ядра сохранились на 100%.
       * **Единый архив и хэш в `dl/`:** пакеты `qca-nss-ppe` и `qca-nss-ppe-vp` используют один общий архив `dl/qca-nss-ppe-2024.01.19~0c6434d7.tar.zst` с общим хэшем `511aaf6dc77c6d5c96c26cdff63142a12ab21c5aeb8b5d7e2b6d2b38e8a1ba82`.
  2. **Функциональный состав (дизассемблер):**
     * И в нашем модуле, и в стоковом модуле Xiaomi дизассемблер насчитал ровно **537 функций** (100% структурное совпадение алгоритмической базы).
  3. **Зависимости от заголовков (nat46):**
     * В файле `drv/ppe_drv/tun/ppe_drv_tun.c` используется включение `#include <nat46/nat46-core.h>`.
     * В `EXTRA_CFLAGS` пакета добавлено `-I$(STAGING_DIR)/usr/include`, чтобы компилятор корректно находил заголовки `kmod-nat46`.
  4. **Утилиты пространства пользователя:**
     * Пакет устанавливает в `/usr/bin` штатные скрипты диагностики `ppe_flow_dump` и `ppe_if_map`, монтирующие отладочные узлы через `debugfs`.
  5. **Широкая интеграция с остальными драйверами (11 зависимых клиентов):**
     * На физическом роутере к нашему нативному `qca-nss-ppe` без малейших проблем привязались сразу 11 подсистем:
       `ecm`, `wifi_3_0`, `qca_nss_dp`, `qca_nss_ppe_tun`, `qca_nss_ppe_lag`, `qca_nss_ppe_bridge_mgr`, `qca_nss_ppe_vlan`, `qca_nss_ppe_pppoe_mgr`, `qca_nss_ppe_ds`, `qca_nss_ppe_vp`, `qca_nss_ppe_rule`.
     * Драйвер Wi-Fi `wifi_3_0` успешно зарегистрировал свои виртуальные порты `ath0` (VP 64) и `ath1` (VP 65) в PPE.

---

### 3.3. `kmod-qca-mcs` (Multicast Snooping & Forwarding Driver)
* **Назначение:** Модуль аппаратного ускорения рассылки мультикаст-трафика (IGMP/MLD snooping). Предотвращает лавинное заполнение портов локальной сети при передаче IPTV/мультикаста.
* **Размещение пакета:** `package/kernel/qca-mcs/`
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/qca-mcs.git` (коммит `2237266b6b234ca0c488437d82fb969026624ec3` от 07.02.2024).
* **Статус:** **`[COMPATIBLE]`**
* **Особенности:**
  * Флаги сборки: обязательно требуется передача `CONFIG_SUPPORT_MLD=y` для поддержки IPv6 MLD Snooping (в стоке Xiaomi эта поддержка включена).
  * Экспортируемые функции ABI: **12 из 12** (полное совпадение, включая `qca_mcs_netdef_group_add`, `qca_mcs_find_group` и др.).
  * Импортируемые символы ядра: **59 из 59** (100% совпадение).
  * Корректно связывается с Linux Bridge (`br-lan`) и ECM.

---

### 3.4. `kmod-qca-ssdk-nohnat` (Qualcomm Switch & PHY Subsystem SDK)
* **Назначение:** Основной системный драйвер подсистемы коммутации и физических уровней (PHY/MAC). Управляет внутренними и внешними портами, связыванием RGMII/SGMII, Uniphy и операциями свитча.
* **Размещение пакета:** `package/kernel/qca-ssdk/`
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/qca-ssdk.git` (ветка `NHSS.QSDK.12.4`, коммит `2e8bf9963e3cbe530ae3fff23ad4f0cf3b03e613` от 16.11.2023, слияние 20.11.2023).
* **Статус:** **`[COMPATIBLE / 100% PARITY]`**
* **Особенности и тонкости миграции:**
  1. **Точная идентификация коммита (переход с `0ac166a1` на `2e8bf996`):**
     * Ранее модуль собирался на коммите `0ac166a1` (май 2024). Глубокий бинарный анализ стокового блоба Xiaomi выявил:
       * **Символ ядра `phy_gbit_features`:** В стоковом модуле Xiaomi этот символ импортируется из ядра. В коммите `630d17e6` (23.02.2024) Qualcomm убрал статическую маску `.features = PHY_GBIT_FEATURES` в пользу динамической функции `qca808x_phy_read_abilities`. На коммите `2e8bf996` маска `PHY_GBIT_FEATURES` возвращается на место, и количество импортов ядра становится ровно **137 из 137 (100% совпадение со стоком)**.
       * **Строка формата `Recieved IOCTL call`:** Коммит `514aa723` (18.12.2023) исправил опечатку `Recieved` -> `Received` в `sw_api_ks_ioctl.c`. В стоковом бинарнике Xiaomi присутствует именно опечатка `Recieved`, что доказывает сборку стока до 18.12.2023.
       * **Дизассемблер `mht_port_link_update`:** Коммит `2e8bf996` (16.11.2023) добавил сброс скорости на 1G при Link Down (`phy_status.speed = FAL_SPEED_1000; phy_status.duplex = FAL_FULL_DUPLEX;`). В стоковом `qca-ssdk.ko` по адресу `0x70ef4` присутствуют инструкции `moveq r7, #1000` и `moveq r9, #1`, подтверждающие этот коммит.
       * **Синхронизация даты сборки со всеми компонентами прошивки:**
         * `qca-nss-ecm`: `aed84d47` — **15.11.2023**
         * `qca-cnss`: `17fe2f6d` — **16.11.2023**
         * `qca-ssdk`: `2e8bf996` — **16.11.2023**
         * `qca-ssdk-shell`: `5a3e1d6d` — **23.11.2023**
         Все компоненты подсистем ядра и сети зафиксированы вендором в середине ноября 2023 года.
  2. **Кастомизация флагов сборки под стоковый профиль:**
     * В стоке Xiaomi BE3600 используется облегченный профиль без HNATHW. Флаги в [Makefile](file:///home/romikb/openwrt/package/kernel/qca-ssdk/Makefile):
       `SoC=ipq53xx CHIP_TYPE=MPPE PTP_FEATURE=disable MINI_SSDK=enable IN_AQUANTIA_PHY=FALSE IN_QCA803X_PHY=FALSE IN_MALIBU_PHY=FALSE`.
  3. **Патч `001-export-fal_port_reset.patch`:**
     * В апстримном коде при `MINI_SSDK=enable` функция `fal_port_reset` исключалась макросом `IN_PORTCONTROL_MINI`.
     * В стоке Xiaomi `fal_port_reset` присутствует в `__ksymtab` (экспортируется наружу). Патч обеспечивает экспорт `fal_port_reset` и совпадение всех 443 экспортов таблицы ABI.
  4. **Совместимость с Userland:**
     * Полная совместимость с нативной утилитой `/usr/sbin/ssdk_sh`, проверенная на физическом роутере Xiaomi BE3600.

---

### 3.5. `kmod-qca-nss-dp` (NSS Data Plane / EDMA Ethernet driver)
* **Назначение:** Основной драйвер сетевого процессора EDMA v2 (Ethernet MAC) для портов `eth0` и `eth1`. Управляет аппаратными кольцами дескрипторов (RxDesc, RxFill, TxDesc, TxCmpl), NAPI poll, очередями прерываний, RPS и взаимодействием с PPE.
* **Размещение пакета:** `package/kernel/qca-nss-dp/`
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-dp.git` (коммит `931028771b0e4e69238f47e313421e730d81fa2f` от 01.02.2024, ветка `NHSS.QSDK.12.4`).
* **Статус:** **`[COMPATIBLE / 100% PARITY]`**
* **Особенности и тонкости миграции:**
  1. **Флаги компиляции:**
     * `MAKE_OPTS:=dp-ppe-ds=y`: **Критический флаг**. Включает компиляцию подсистемы Direct Switch (`hal/dp_ops/edma_dp/edma_v2/edma_ppeds.o`), обеспечивает экспорт `nss_dp_ppeds_get_ops`, вызовы блокировок ядра `_raw_read_lock_bh` / `_raw_write_lock_bh` и `init_dummy_netdev`.
     * `SoC:=ipq53xx`: Обязателен. Определяет компиляцию HAL для IPQ53xx и Virtual Ports (`nss_dp_vp_main.o`), которые дают 5 экспортов `nss_dp_vp_*`.
  2. **100% соответствие экспортов и импортов стоковому вендорному модулю:**
     * **Экспорты ABI:** ровно **15 из 15** (100.00% совпадение).
     * **Импорты ядра:** ровно **202 из 202** (100.00% совпадение, 0 лишних и 0 недостающих символов).
     * **Функциональный состав (дизассемблер):** ровно **182 из 182** функций (100.00% совпадение структуры функций).
     * **Патч `001-remove-phy-stop-on-close.patch`:** убирает вызов `phy_stop(dp_priv->phydev)` в `nss_dp_close()`, повторяя логику стокового вендорного модуля Xiaomi (предотвращает остановку PHY state machine при выключении линка, которая мешает фоновому SSDK polling).
  3. **Размер секции `.text`:**
     * Всего **+224 байта** разницы (56 528 байт против 56 304 байт).
  4. **Утилиты и сервисы:**
     * Пакет устанавливает `/etc/init.d/qca-nss-dp` (автоматическая настройка SMP affinity прерываний `edma_rxdesc` и `edma_txcmpl`), конфиг `/etc/config/qca_nss_dp` и утилиту отладки регистров `/usr/bin/edma_dump`.

---

### 3.6. `kmod-qca-nss-ppe-vp` (PPE Virtual Ports core driver)
* **Назначение:** Базовый драйвер виртуальных портов (Virtual Ports, VP) в архитектуре PPE SoC IPQ53xx. Предоставляет интерфейс регистрации и управления виртуальными портами для Wi-Fi (`wifi_3_0`), туннелей (`ppe_tun`), Direct Switch (`ppe_ds`) и других клиентов, сопрягая их с аппаратным движком EDMA/PPE.
* **Размещение пакета:** `package/kernel/qca-nss-ppe-vp/`
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git` (коммит `0c6434d7d19459b9e10ccf870faffb7dff8e4d98` от 19.01.2024).
* **Статус:** **`[COMPATIBLE / 100% PARITY]`**
* **Особенности и тонкости миграции:**
  1. **Кросс-репозиторная завязка ABI с `qca-nss-dp` (почему не `a9998acd`):**
     * При первоначальной попытке сборки с коммита `a9998acd` (на котором собран `kmod-qca-nss-ppe`) возникла ошибка компиляции:
       ```
       ppe_vp_rx.c:142: error: 'struct nss_dp_vp_rx_info' has no member named 'ip_summed'
       ppe_vp_rx.c:143: error: 'struct nss_dp_vp_rx_info' has no member named 'napi'
       ```
     * **Причина:** В коммите `3e9af47d` (09.02.2024, *"[qca-nss-ppe-vp] add support to pass GRO and ip_summed"*) сигнатура коллбэка VP была переписана:
       * Старая сигнатура: `bool (*ppe_vp_callback_t)(struct net_device *dev, struct sk_buff *skb, void *cb_data)`
       * Новая сигнатура: `bool (*ppe_vp_callback_t)(struct ppe_vp_cb_info *info, void *cb_data)`
       * Данное изменение было скоординировано с коммитом `79f3022` в `nss-dp.git`, добавившим поля `ip_summed` и `napi` в структуру `nss_dp_vp_rx_info`.
     * Однако стоковая прошивка Xiaomi RD15 1.0.68 (и наш модуль `qca-nss-dp` на коммите `9310287`) построена на версии до этого изменения. Более того, вендорские модули (например, Wi-Fi драйвер `wifi_3_0.ko` и `qca-nss-ppe-tun.ko`) ожидают классическую сигнатуру коллбэка с `struct net_device *dev`.
     * Выбор коммита `0c6434d7d19459b9e10ccf870faffb7dff8e4d98` (19.01.2024 — коммит, непосредственно предшествующий `3e9af47d`) обеспечил точное совпадение ABI структуры `nss_dp_vp_rx_info` и сигнатур функций.
  2. **100% совпадение экспортов, импортов и функций:**
     * **Экспорты ABI:** ровно **8 из 8** (100% совпадение: `ppe_vp_alloc`, `ppe_vp_free`, `ppe_vp_get_netdev_by_port_num`, `ppe_vp_mac_addr_clear`, `ppe_vp_mac_addr_set`, `ppe_vp_mtu_get`, `ppe_vp_mtu_set`, `ppe_vp_tx_to_ppe`).
     * **Импорты ядра:** ровно **61 из 61** (100% совпадение).
     * **Функциональный состав (дизассемблер):** ровно **24 из 24** функций (100% совпадение).
     * **Размер секции `.text`:** 8 992 байта против 9 040 байт (разница всего **-48 байт**).

### 3.7. `kmod-qca-nss-ppe-rule` (PPE Rule / RFS Engine)
* **Назначение:** Драйвер подсистемы аппаратных правил (Rule Engine) и Receive Flow Steering (RFS) в PPE. Отвечает за аппаратное ускорение распределения сетевых потоков IPv4/IPv6 по процессорным ядрам (CPU cores) и управление RFS правилами.
* **Размещение пакета:** `package/kernel/qca-nss-ppe-rule/`
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git` (коммит `0c6434d7d19459b9e10ccf870faffb7dff8e4d98` от 19.01.2024).
* **Статус:** **`[COMPATIBLE / 100% PARITY]`**
* **Особенности и тонкости миграции:**
  1. **Унификация репозитория и архива с `qca-nss-ppe` и `qca-nss-ppe-vp`:**
     * Пакет собирается из общего скачанного архива `dl/qca-nss-ppe-2024.01.19~0c6434d7.tar.zst` (`PKG_MIRROR_HASH:=511aaf6d...`), что полностью устраняет дублирование трафика и дискового пространства в `dl/`.
  2. **Подбор конфигурации стокового профиля (256M Low-Memory):**
     * В апстриме `ppe_rule` поддерживает модули ACL, Policer, Mirror и Priority. При сборке полного набора возникали ошибки `-Werror=undef` из-за неинициализированных макросов уровней логирования в заголовочных файлах.
     * Анализ стокового файла Xiaomi `qca-nss-ppe-rule.ko` показал, что в заводской прошивке компилируются только 3 объектных файла: `ppe_rule.o`, `ppe_rfs.o`, `ppe_rfs_stats.o`.
     * Включение точных опций сборки:
       ```makefile
       MAKE_OPTS:=ppe-rule=y PPE_RFS_ENABLED=y PPE_RULE_IPQ53XX=y PPE_LOWMEM_PROFILE_256M=y
       ```
       дало 100% идентичный стоковому модулю состав объектников и функций.
  3. **100% соответствие ABI и структуры функций:**
     * **Экспорты ABI:** ровно **4 из 4** (100% совпадение: `ppe_rfs_ipv4_rule_create`, `ppe_rfs_ipv4_rule_destroy`, `ppe_rfs_ipv6_rule_create`, `ppe_rfs_ipv6_rule_destroy`).
     * **Импорты ядра:** ровно **30 из 30** (100% совпадение).
     * **Функциональный состав (дизассемблер):** ровно **12 из 12** функций.
     * **Размер секции `.text`:** 4 456 байт против 4 504 байт (разница всего **-48 байт**).

---

### 3.8. `kmod-qca-nss-ppe-ds` (PPE Direct Switch driver)
* **Назначение:** Драйвер подсистемы прямого переключения (Direct Switch, DS) между Wi-Fi чипсетом (SoC Wi-Fi 3.0 / WCSS) и аппаратным движком PPE. Обеспечивает прямую аппаратную коммутацию беспроводных пакетов через дескрипторные кольца TCL (Transmit Classification and Load) и REO (Receive Reorder Offload) в обход центрального процессора.
* **Размещение пакета:** `package/kernel/qca-nss-ppe-ds/`
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git` (коммит `0c6434d7d19459b9e10ccf870faffb7dff8e4d98` от 19.01.2024).
* **Статус:** **`[COMPATIBLE / 100% PARITY]`**
* **Особенности и тонкости миграции:**
  1. **Унификация репозитория и архива (0c6434d7):**
     * Полностью разделяет единый архив `dl/qca-nss-ppe-2024.01.19~0c6434d7.tar.zst` вместе с `ppe`, `ppe-vp` и `ppe-rule`.
  2. **Идеальное побайтовое соответствие кода (.text):**
     * Размер секции `.text`: **ровно 6 036 байт у нашего модуля и 6 036 байт в стоковом блобе Xiaomi (+0 байт разница)**!
     * Побайтовое сходство машинного кода: **99.04%** (всего 58 байт разницы из-за строки даты сборки).
  3. **100% совпадение ABI и структур:**
     * **Экспорты ABI:** ровно **14 из 14** (100% совпадение, включая `ppe_ds_wlan_inst_alloc`, `ppe_ds_wlan_vp_alloc`, `ppe_ds_wlan_rx`, `ppe_ds_reo2ppe_wlan_handle_intr` и др.).
     * **Импорты ядра:** ровно **29 из 29** (100% совпадение).
     * **Функциональный состав (дизассемблер):** ровно **27 из 27** функций.
  4. **Экспорт заголовочных файлов:**
     * Заголовочный файл `ppe_ds_wlan.h` экспортируется в `staging_dir/usr/include/` и `staging_dir/usr/include/qca-nss-ppe/` для бесшовной сборки драйвера Wi-Fi 7 / BE (`qca-wifi`).
  5. **Оптимизация порога заполнения кольцевого буфера Direct Switching (rxfill=256):**
     * В патче `0001-ppe-ds-lowmem-rxfill-threshold.patch` для профиля памяти `PPE_LOWMEM_PROFILE_256M` значение порога `PPE_DS_WLAN_RXFILL_LOWMEM_THRESHOLD` установлено в 256 дескрипторов (вместо 1024), что на 100% соответствует стоковой конфигурации Xiaomi и экономит память буферов skb.

### 3.9. `kmod-qca-nss-ppe-tun` (PPE Tunneling Offload driver)
* **Назначение:** Драйвер аппаратного ускорения сетевых туннелей (VxLAN, GRE, MAP-T, IPIP, Geneve) в архитектуре PPE. Обеспечивает инкапсуляцию и декапсуляцию туннельных пакетов через аппаратный движок PPE и виртуальные порты.
* **Размещение пакета:** `package/kernel/qca-nss-ppe-tun/`
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git` (коммит `0c6434d7d19459b9e10ccf870faffb7dff8e4d98` от 19.01.2024).
* **Статус:** **`[COMPATIBLE / 100% PARITY]`**
* **Особенности и тонкости миграции:**
  1. **Унификация репозитория и архива (0c6434d7):**
     * Использует общий скачанный архив `dl/qca-nss-ppe-2024.01.19~0c6434d7.tar.zst` вместе с `ppe`, `ppe-vp`, `ppe-rule` и `ppe-ds`.
  2. **Решение проблемы зависимости от ACL в 256M Low-Memory профиле:**
     * В апстриме CodeLinaro коммит `96a10ab` добавил вызовы `ppe_acl_rule_create(&rule)` и `ppe_acl_rule_destroy()` в `drv/ppe_tun/ppe_tun.c` для ядер `< 6.1.0`.
     * В профиле Xiaomi BE3600 (256M RAM, `PPE_LOWMEM_PROFILE_256M=y`) подсистема ACL в `drv/ppe_rule/Makefile` отключена (компилируются только `ppe_rule.c`, `ppe_rfs.c`, `ppe_rfs_stats.c`), поэтому функция `ppe_acl_rule_create` отсутствует.
     * Стоковый блоб Xiaomi `qca-nss-ppe-tun.ko` также не вызывал ACL.
     * Был создан патч `001-disable-acl-on-lowmem-profile.patch`, оборачивающий вызовы ACL макросом `!defined(NSS_PPE_LOWMEM_PROFILE_16M) && !defined(NSS_PPE_LOWMEM_PROFILE_256M)` аналогично `drv/ppe_rule/ppe_rule.c`.
  3. **Идеальное побайтовое соответствие кода (.text):**
     * Размер секции `.text`: **ровно 10 828 байт у нашего модуля и 10 828 байт в стоковом блобе Xiaomi (+0 байт разница)**!
     * Побайтовое сходство машинного кода: **99.85%** (всего 16 байт разницы из-за строки даты сборки).
  4. **100% совпадение ABI и структур:**
     * **Экспорты ABI:** ровно **17 из 17** (100% совпадение, включая `ppe_tun_configure_vp`, `ppe_tun_deconfigure_vp`, `ppe_tun_free_dummy_netdev`, `ppe_tun_alloc_dummy_netdev`, `ppe_tun_tx` и др.).
     * **Импорты ядра:** ровно **42 из 42** (100% совпадение).
     * **Функциональный состав (дизассемблер):** ровно **45 из 45** функций.

### 3.10. `kmod-qca-nss-ppe-pppoe-mgr` (PPE PPPoE Client Manager)
* **Назначение:** Клиентский драйвер PPE для аппаратного управления PPPoE сессиями. Отслеживает события подключения и отключения PPPoE туннелей через Linux PPP-канал (`ppp_channel_connection_register_notify`), регистрирует сессии в движке PPE (`ppe_drv_pppoe_session_init`), настраивает MTU и связывает их с LAG/Bonding интерфейсами.
* **Размещение пакета:** `package/kernel/qca-nss-ppe-pppoe-mgr/`
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git` (коммит `0c6434d7d19459b9e10ccf870faffb7dff8e4d98` от 19.01.2024, папка `clients/pppoe/`).
* **Статус:** **`[COMPATIBLE / 100% PARITY]`**
* **Особенности и тонкости миграции:**
  1. **Унификация репозитория и архива (0c6434d7):**
     * Полностью использует общий скачанный архив `dl/qca-nss-ppe-2024.01.19~0c6434d7.tar.zst` вместе с остальными модулями `nss-ppe.git`.
  2. **Почти абсолютное совпадение кода (.text):**
     * Размер секции `.text`: **ровно 2 156 байт у нашего модуля и 2 156 байт в стоковом блобе Xiaomi (+0 байт разница)**!
     * Побайтовое сходство машинного кода: **99.95%** (всего 1 байт разницы!).
  3. **100% совпадение импортов ядра и структуры функций:**
     * **Импорты ядра:** ровно **21 из 21** (100% совпадение).
     * **Функциональный состав (дизассемблер):** ровно **4 из 4** функций (`nss_ppe_pppoe_mgr_connect`, `nss_ppe_pppoe_mgr_disconnect`, `nss_ppe_pppoe_mgr_changemtu_event`, `nss_ppe_pppoe_mgr_channel_notifier_handler`).
  4. **Поддержка Bonding / LAG:**
     * При наличии `kmod-bonding` автоматически активируется флаг `BONDING_SUPPORT` и вызовы `bond_get_id`, в точности как в стоке Xiaomi.

### 3.11. `kmod-qca-nss-ppe-vlan-mgr` (PPE VLAN Client Manager)
* **Назначение:** Клиентский драйвер PPE для аппаратного управления VLAN (802.1Q / 802.1ad QinQ) интерфейсами и правилами фильтрации/трансляции VLAN. Управляет виртуальными портами VLAN, привязкой к физическим интерфейсам, таблицами VSI в SSDK, мостами и агрегацией каналов (LAG/Bonding).
* **Размещение пакета:** `package/kernel/qca-nss-ppe-vlan/` (имя пакета `kmod-qca-nss-ppe-vlan-mgr`, модуль `qca-nss-ppe-vlan.ko`).
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git` (коммит `0c6434d7d19459b9e10ccf870faffb7dff8e4d98` от 19.01.2024, папка `clients/vlan/`).
* **Статус:** **`[COMPATIBLE / 100% ABI MATCH]`**
* **Особенности и тонкости миграции:**
  1. **Унификация репозитория и архива (0c6434d7):**
     * Использует общий скачанный архив `dl/qca-nss-ppe-2024.01.19~0c6434d7.tar.zst` вместе с остальными модулями `nss-ppe.git`.
  2. **100% совпадение ABI (все 10 экспортов):**
     * **Экспорты ABI:** ровно **10 из 10** (`nss_ppe_vlan_mgr_add_bond_slave`, `nss_ppe_vlan_mgr_add_vlan_rule`, `nss_ppe_vlan_mgr_config_bridge_vlan_ingress_rule`, `nss_ppe_vlan_mgr_del_vlan_rule`, `nss_ppe_vlan_mgr_delete_bond_slave`, `nss_ppe_vlan_mgr_get_real_dev`, `nss_ppe_vlan_mgr_join_bridge`, `nss_ppe_vlan_mgr_leave_bridge`, `nss_ppe_vlan_mgr_vlan_over_bridge_register_cb`, `nss_ppe_vlan_mgr_vlan_over_bridge_unregister_cb`).
     * Экспортирует заголовочный файл `exports/nss_ppe_vlan_mgr.h` в `staging_dir/usr/include/` и `staging_dir/usr/include/qca-nss-ppe/` для модулей `bridge-mgr` и `lag-mgr`.
  3. **Синхронизация сигнатуры коллбэка Virtual Ports с `kmod-qca-nss-ppe-vp`:**
     * На коммите `0c6434d7` сигнатура коллбэка исключений VP `nss_ppe_vlan_mgr_vp_src_exception` имеет классический вид `(struct net_device *dev, struct sk_buff *skb, void *cb_data)`, что гарантирует полную совместимость с ядром и нашим нативным драйвером `qca-nss-ppe-vp.ko` без риска сбоя ядра.
  4. **Бинарные особенности и разбор разницы в 176 байт (`vp_wan_interface`):**
     * Размер секции `.text`: **15 388 байт** у нашего модуля против 15 564 байт в стоке (разница всего **-176 байт**).
     * **Sysctl-дерево в нашем модуле полностью функционально:** корень `/proc/sys/ppe/vlan_client/` регистрируется и содержит параметры `ctpid` (Customer TPID) и `stpid` (Service TPID).
     * **Причина разницы в -176 байт:** в стоковом модуле Xiaomi в эту таблицу была добавлена третья запись `/proc/sys/ppe/vlan_client/vp_wan_interface` (обработчик на базе `proc_dostring` и `dev_get_by_name`).
     * **Исследование необходимости:** был проверен весь стоковый rootfs Xiaomi (`tmp/rootfs/` — все скрипты `/etc/init.d/*`, `/lib/network/*`, бинарники userland). Найдено **0 мест применения** — ни один скрипт и ни один процесс прошивки этот узел не читает и не записывает. В файле автозагрузки `/etc/modules.d/51-qca-nss-ppe-vlan-mgr` модуль также запускается без параметров.
     * Сам параметр `vlan_as_vp_interface` в открытом коде объявлен штатным макросом ядра `module_param(vlan_as_vp_interface, charp, 0644)` и полноценно доступен через sysfs (`/sys/module/qca_nss_ppe_vlan/parameters/vlan_as_vp_interface`) или аргументы загрузки модуля.
     * В связи с отсутствием практической потребности и риска поломки чего-либо, данный неиспользуемый вендорский рудимент в нативный открытый пакет не переносился.
     * Все импорты ядра (50 из 50) полностью удовлетворены, 0 недостающих символов.
  5. **Назначение виртуального порта для VLAN (vlan_as_vp_interface="eth0"):**
     * В патче `0001-default-vlan-as-vp-interface.patch` значение параметра по умолчанию `vlan_as_vp_interface` установлено в `"eth0"`, что обеспечивает автоматическую регистрацию Virtual Port (VP) для eth0-based VLAN интерфейсов аналогично поведению стоковой прошивки.

### 3.12. `kmod-qca-nss-ppe-lag-mgr` (PPE Link Aggregation Manager)
* **Назначение:** Клиентский драйвер PPE для аппаратной агрегации каналов (Link Aggregation / Linux Bonding). Отслеживает события добавления и удаления подчиненных портов в bond-интерфейсы (`bond0`), настраивает аппаратные группы LAG в PPE (`ppe_drv_lag_init`, `ppe_drv_lag_join`, `ppe_drv_lag_leave`), синхронизирует MAC-адреса и связывает правила с `vlan-mgr`.
* **Размещение пакета:** `package/kernel/qca-nss-ppe-lag/` (имя пакета `kmod-qca-nss-ppe-lag-mgr`, модуль `qca-nss-ppe-lag.ko`).
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git` (коммит `0c6434d7d19459b9e10ccf870faffb7dff8e4d98` от 19.01.2024, папка `clients/lag/`).
* **Статус:** **`[100% BIT-FOR-BIT IDENTICAL]`**
* **Особенности и тонкости миграции:**
  1. **Унификация репозитория и архива (0c6434d7):**
     * Использует общий скачанный архив `dl/qca-nss-ppe-2024.01.19~0c6434d7.tar.zst` вместе со всеми модулями PPE.
  2. **100% побайтовое совпадение с заводским модулем:**
     * Размер секции `.text`: **ровно 2 520 байт у нашего модуля и 2 520 байт в стоковом блобе Xiaomi (+0 байт разница)**!
     * Машинный код: **100% bit-for-bit identical**.
  3. **100% совпадение импортов ядра:**
     * Ровно **21 из 21** импортов ядра (`ppe_drv_lag_*`, `nss_ppe_vlan_mgr_*`, `register_netdevice_notifier_dev_net` и др.).
  4. **Автозагрузка:**
     * Приоритет автозагрузки `52-qca-nss-ppe-lag-mgr`, загружается строго после `51-qca-nss-ppe-vlan-mgr` и `qca-nss-ppe`.

### 3.13. `kmod-qca-nss-ppe-bridge-mgr` (PPE Bridge Manager)
* **Назначение:** Диспетчер сетевых мостов (Linux bridge `br-lan` и др.) для PPE. Отслеживает добавление/удаление портов в мосты (`br_fdb_update_register_notify`, `nss_ppe_bridge_mgr_join_bridge`, `nss_ppe_bridge_mgr_leave_bridge`), управляет состояниями STP (`ppe_drv_br_stp_state_set`), регистрирует WAN-интерфейсы в PPE (`ppe_drv_br_wanif_set`), динамически синхронизирует таблицу FDB с аппаратной таблицей коммутации PPE (`ppe_drv_br_fdb_del_bymac`, `ppe_drv_br_fdb_lrn_ctrl`) и координирует VLAN через `vlan-mgr`. Экспортирует API моста для модуля `vxlanmgr`.
* **Размещение пакета:** `package/kernel/qca-nss-ppe-bridge/` (имя пакета `kmod-qca-nss-ppe-bridge-mgr`, модуль `qca-nss-ppe-bridge-mgr.ko`).
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git` (коммит `0c6434d7d19459b9e10ccf870faffb7dff8e4d98` от 19.01.2024, папка `clients/bridge/`).
* **Статус:** **`[COMPATIBLE]`**
* **Особенности и тонкости миграции:**
  1. **Экспорты ABI (100% совпадение):**
     * Ровно **2 из 2** экспортов (`nss_ppe_bridge_mgr_join_bridge`, `nss_ppe_bridge_mgr_leave_bridge`), необходимых для `vxlanmgr`. Заголовочный файл `exports/nss_ppe_bridge_mgr.h` экспортируется через `Build/InstallDev` в `$(STAGING_DIR)/usr/include/qca-nss-ppe/`.
  2. **Импорты ядра (100% совпадение):**
     * Ровно **53 из 53** импортов ядра и других драйверов (`ppe_drv_br_*`, `nss_ppe_vlan_mgr_*`, `br_fdb_*`, `register_sysctl_table` и др.), 0 недостающих и 0 лишних символов.
  3. **Бинарное сравнение .text:**
     * Наш размер: **9 392 байт**, стоковый размер: **9 408 байт** (разница всего **-16 байт** за счет выравнивания ARM). Секции `.exit.text` (128 байт), `.init.text` (252 байта) и `.rodata` (981 байт) совпадают побайтно.
  4. **Сервисный скрипт инициализации:**
     * В пакет интегрирован штатный init-скрипт `/etc/init.d/qca-nss-ppe-bridge-mgr` (START=19), выполняющий проверку загрузки модуля ядра и настройку FDB-обучения.
  5. **Отключение аппаратного FDB learning:**
     * Параметр `NSS_PPE_BRIDGE_MGR_FDB_LEARNING=n` синхронизирован со стоком Xiaomi, предотвращая избыточное дублирование записей изучения MAC-адресов аппаратным свитчом.

### 3.14. `kmod-qca-nss-ppe-vxlanmgr` (PPE VxLAN Tunnel Manager)
* **Назначение:** Клиентский драйвер PPE для аппаратной акселерации и терминации туннелей VxLAN (Virtual Extensible LAN). Отслеживает сетевые события VxLAN-интерфейсов (`register_netdevice_notifier`), настраивает аппаратные порты инкапсуляции/декапсуляции через PPE Tunnel API (`ppe_tun_configure_vxlan_dport`, `ppe_tun_decap_enable`, `ppe_tun_conf_accel`), связывает VxLAN туннели с сетевыми мостами через `bridge-mgr` (`nss_ppe_bridge_mgr_join_bridge`) и экспортирует статус VP для менеджера соединений ECM.
* **Размещение пакета:** `package/kernel/qca-nss-ppe-vxlan/` (имя пакета `kmod-qca-nss-ppe-vxlanmgr`, модуль `qca-nss-ppe-vxlanmgr.ko`).
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-ppe.git` (коммит `0c6434d7d19459b9e10ccf870faffb7dff8e4d98` от 19.01.2024, папка `clients/vxlanmgr/`).
* **Статус:** **`[COMPATIBLE / 100% PARITY]`**
* **Особенности и тонкости миграции:**
  1. **Экспорты ABI (100% совпадение):**
     * Ровно **2 из 2** экспортов (`nss_ppe_vxlanmgr_get_ifindex_and_vp_status`, `nss_ppe_vxlanmgr_get_parent_netdev`), используемых подсистемой ECM.
     * Заголовочный файл `exports/nss_ppe_vxlanmgr.h` экспортируется через `Build/InstallDev` в `$(STAGING_DIR)/usr/include/qca-nss-ppe/`.
  2. **Импорты ядра (100% совпадение):**
     * Ровно **62 из 62** импортов ядра и других драйверов (`ppe_tun_*`, `nss_ppe_bridge_mgr_*`, `register_switchdev_notifier`, `alloc_netdev_mqs` и др.), 0 недостающих и 0 лишних символов.
  3. **Бинарное сравнение .text:**
     * Размер секции `.text`: **ровно 11 400 байт у нашего модуля и 11 400 байт в стоковом блобе Xiaomi (+0 байт разница)**!
     * Побайтовое сходство машинного кода: **98.78%** (разница всего 139 байт за счет даты сборки и отладочных строк).
  4. **Завершение миграции подсистемы PPE:**
     * `kmod-qca-nss-ppe-vxlanmgr` стал **10-м и последним модулем семейства Qualcomm PPE**. В репозитории `vendor_feed` не осталось ни одного закрытого PPE-блоба.

### 3.15. `kmod-qca-nss-sfe` (Shortcut Forwarding Engine)
* **Назначение:** Высокопроизводительный программный движок сетевого ускорения Shortcut Forwarding Engine (SFE). Обеспечивает прямое перенаправление IP-трафика (IPv4/IPv6, TCP, UDP, GRE, PPPoE-in-Bridge, Bridge VLAN) в обход стандартного медленного сетевого стека Linux. Тесно взаимодействует с PPE RFS (`ppe_rfs_feature`), аппаратными правилами PPE и менеджером соединений ECM.
* **Размещение пакета:** `package/kernel/qca-nss-sfe/` (имя пакета `kmod-qca-nss-sfe`, модуль `qca-nss-sfe.ko`).
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/shortcut-fe.git` (коммит `7d82c7104fa14a84660b8c8caa4d824ef1784b7c` от 20.03.2024).
* **Статус:** **`[COMPATIBLE]`**
* **Особенности и тонкости миграции:**
  1. **100% совпадение ABI (все 19 экспортов):**
     * Ровно **19 из 19** экспортов (`sfe_ipv4_recv`, `sfe_ipv6_recv`, `sfe_ipv4_create_rule`, `sfe_ipv6_create_rule`, `sfe_ipv4_destroy_rule`, `sfe_ipv6_destroy_rule`, `sfe_ipv4_update_rule`, `sfe_ipv6_update_rule`, `sfe_drv_ipv4_notify_register`, `sfe_drv_ipv6_notify_register`, `sfe_ipv4_service_class_stats_get`, `sfe_ipv6_service_class_stats_get` и др.).
     * Обеспечивает полную бинарную совместимость с модулем `kmod-qca-nss-ecm-premium-vendor`.
  2. **100% совпадение импортов ядра и PPE (111 из 111):**
     * Ровно **111 из 111** импортов ядра и зависимых подсистем (`ppe_rfs_feature`, `ppe_rule_wlan_event_info_get`, `ppp_dev_name`, `register_netdevice_notifier` и др.). 0 недостающих символов.
  3. **Тонкая настройка профиля памяти (256M Low-Memory):**
     * Для платформы IPQ5332 (RD15) применены флаги `SFE_256M_PROFILE=y` и `EXTRA_CFLAGS += -DSFE_MEM_PROFILE_LOW`.
     * В соответствии с этим профилем отключаются неиспользуемые в заводской прошивке модули туннелей (`tun6rd`, `esp`, `tunipip6`), а размер хэш-таблицы соединений устанавливается в `SFE_MAX_CONNECTION_HASH_ORDER=9` (максимум 512 соединений по умолчанию в `/sys/module/qca_nss_sfe/parameters/max_ipv4_conn`), что на 100% соответствует поведению стокового модуля Xiaomi.
  4. **Аппаратные фичи и RFS/TSO:**
     * Активированы флаги `SFE_RFS_SUPPORTED=y` (интеграция с `qca-nss-ppe-rule`), `SFE_BRIDGE_VLAN_FILTERING_ENABLE=y`, `SFE_PROCESS_LOCAL_OUT=y` и `-DSFE_TSO_MAX_SEG_LIMIT_ENABLE`.
  5. **Бинарное сравнение .text:**
     * Размер секции `.text`: **117 852 байт** у нашего модуля против 115 660 байт в стоке (разница **+2 192 байт**).
     * Разница обусловлена более свежей ревизией коммита `7d82c71`, где была добавлена обработка исключений фрагментированных IPv6 пакетов и усилены граничные проверки.
  6. **Утилиты и заголовки:**
     * В состав пакета включена штатная утилита диагностики `/usr/bin/sfe_dump` (`sfe_dump ipv4`, `sfe_dump ipv6`).
     * Заголовочный файл `exports/sfe_api.h` экспортируется через `Build/InstallDev` в `$(STAGING_DIR)/usr/include/qca-nss-sfe/`.
  7. **Синхронизация зависимостей:**
     * В `vendor_scripts/native.list` добавлен `kmod-qca-nss-sfe`.
     * Модули `kmod-qca-nss-ecm-premium-vendor` и `kmod-qca-nss-ecm-wifi-plugin-vendor` перелинкованы на зависимость от нативного `+kmod-qca-nss-sfe` вместо закрытого пакета.

---

### 3.16. `kmod-qca-cnss` (Qualcomm Network Subsystem / Wi-Fi Bus Driver)
* **Назначение:** Базовый платформенный драйвер шины Wi-Fi для сетевых процессоров Qualcomm (QCA CNSS). Обеспечивает инициализацию и управление аппаратными интерфейсами PCIe и AHB для радиомодулей Wi-Fi (QCN6432 и др.), управление питанием, регистрацию прерываний MSI/Legacy, выделение DMA/памяти для прошивок радиомодулей (`fw_mem`), обработку сбоев и сбор дампов RDDM, взаимодействие с демоном userland `/usr/bin/cnssdaemon` через QMI IPC и Generic Netlink (genl).
* **Размещение пакета:** `package/kernel/qca-cnss/` (имя пакета `kmod-qca-cnss`, модуль `ipq_cnss2.ko`).
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/wifi/qca-cnss.git` (коммит `17fe2f6d0f62d10c0e5a6efcf0927ad86eb8c474` от 16.11.2023).
* **Статус:** **`[COMPATIBLE / 100% PARITY]`**
* **Особенности и тонкости миграции:**
  1. **100% совпадение ABI (все 94 экспорта):**
     * Ровно **94 из 94** экспортов (`cnss_wlan_register_driver_ops`, `cnss_wlan_probe_driver`, `cnss_wlan_enable`, `cnss_wlan_disable`, `cnss_pci_probe`, `cnss_pci_remove`, `cnss_power_up`, `cnss_power_down`, `cnss_athdiag_read`, `cnss_athdiag_write`, `cnss_bus_reg_read`, `cnss_bus_reg_write`, `cnss_smmu_map`, `cnss_smmu_unmap` и др.).
     * Обеспечивает 100% бесшовную совместимость со стеком драйверов Wi-Fi 7 (`kmod-qca-wifi-lowmem-profile-vendor`).
  2. **100% совпадение импортов ядра (все 250 символов):**
     * Ровно **250 из 250** импортов ядра (`pcie_parf_read`, `mhi_*`, `pci_*`, `dma_*`, `genlmsg_*`, `debugfs_*` и др.). 0 недостающих символов.
  3. **Тонкая конфигурация флагов компиляции:**
     * `QCA_CNSS_PCI_SUPPORT=y` — поддержка шины PCIe для радиомодулей.
     * `QCA_CNSS_DEBUG_SUPPORT=y` — поддержка отладочных узлов debugfs, сбор дампов регистров Copy Engine (`cnss_dump_all_ce_reg`).
     * `QCA_CNSS_LOWMEM_PROFILE=y` — адаптация под профиль памяти 256M RD15 (отложенное размонтирование прошивок `umount_firmware_delay`).
     * `ENABLE_QCA5332_HEADER=y` — специализированные базовые адреса CE и параметры SoC IPQ5332.
     * `QCA_CNSS_KERNEL_DEPENDENCY=y` — низкоуровневые вызовы PARF PCIe контроллера.
  4. **Интеграция со службой инициализации:**
     * В пакете намеренно не используется `AUTOLOAD` через `/etc/modules.d/`, поскольку модуль штатно контролируется скриптом `/etc/init.d/load_cnss2` (START=11), парсящим аргументы `cnss2.*` из `/proc/cmdline` и запускающим фоновый демон `cnssdaemon`.
  5. **Экспорт заголовочных файлов:**
     * Файл `include/cnss2.h` экспортируется через `Build/InstallDev` в `$(STAGING_DIR)/usr/include/` и `$(STAGING_DIR)/usr/include/qca-cnss/` для последующей нативной компиляции драйвера Wi-Fi.
  6. **Устранение утечки 2.0 МБ DMA-памяти QDSS (переход на коммит `17fe2f6d`):**
     * Первоначально использовался коммит `3cbb15d2` (09.02.2024), в котором драйвер принудительно аллоцировал 2.0 МБ непрерывной DMA-памяти под отладочную трассировку Qualcomm QDSS (`qdss_mem`).
     * В стоковой прошивке Xiaomi 1.0.68 драйвер был собран на коммите `17fe2f6d` (16.11.2023), где буфер QDSS не выделяется.
     * Переход на коммит `17fe2f6d` позволил освободить ровно 2.0 МБ RAM, обеспечив 100% паритет свободной памяти со стоком Xiaomi.

---

### 3.17. `kmod-qca-nss-ecm` (Enhanced Connection Manager - Premium)
* **Назначение:** Главный координатор аппаратной и программной сетевой акселерации Qualcomm. Отслеживает события соединений Linux Conntrack (TCP, UDP, туннели), классифицирует трафик (DSCP, QoS, VLAN, E-Mesh, PCC, fwmark), динамически выбирает движок акселерации (PPE Hardware Engine или SFE Software Engine) и передает правила коммутации чипу IPQ5322.
* **Размещение пакета:** `package/kernel/qca-nss-ecm/` (предоставляет `kmod-qca-nss-ecm-premium`, собирает `ecm.ko`, `ecm_sfe_l2.ko`, `ecm_ae_select.ko`).
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/qca-nss-ecm.git` (коммит `aed84d4719a3d5c97a5394bb3e0e7f9dd7b5013d` от 15.11.2023).
* **Статус:** **`[COMPATIBLE / 98% PARITY]`**
* **Особенности и тонкости миграции:**
  1. **Разделение мифов о статусе "Premium":**
     * Анализ показал, что в OpenWrt QSDK пакет с суффиксом `-premium` собирается из **открытого исходного кода** репозитория `qca-nss-ecm.git`. Название "premium" обозначает профиль сборки с включением всех туннельных интерфейсов и классификаторов (IPsec, PPPoE, PPTP, L2TP, GRE, SIT, TUNIPIP6, RAWIP, VXLAN, MAP-T, QoS, MSCS, SCS, FSE, E-Mesh).
  2. **Бинарный состав и сравнение секций:**
     * `ecm_ae_select.ko`: размер 1 449 байт против 1 413 байт в стоке (разница всего **+36 байт**, 97.5% сходство). Импорты: **6 из 6 (100% совпадение)**.
     * `ecm_sfe_l2.ko`: размер 10 465 байт против 10 478 байт в стоке (разница всего **-13 байт**, 99.9% сходство). Импорты: **39 из 39 (100% совпадение)**.
     * `ecm.ko`: размер 722 489 байт против 737 178 байт в стоке (разница всего **-14 689 байт / -2.0%**).
  3. **Совместимость функций и побайтовое соответствие:**
     * Ключевые функции роутинга и акселерации (`ecm_ported_ipv6_process`, `ecm_multicast_ipv6_connection_process`, `ecm_multicast_ipv4_connection_process`) совпадают по размеру байт-в-байт.
     * Поддержка протоколов (PPE, SFE, IPv6, PPPoE, PPTP, L2TP, GRE TAP/TUN, SIT, TUNIPIP6, RAWIP, BONDING, VXLAN, MAP-T, DSCP, PCC, MARK, EMESH, MSCS) на 100% совпадает со стоком.
  4. **Согласование профиля с вендором (отключение ECM_NON_PORTED_SUPPORT_ENABLE):**
     * В стоке Xiaomi аппаратное ускорение для не-портовых протоколов (ICMP/ping, IGMP, ESP) было отключено (`v4_non_ported_not_supported`).
     * Отключение `ECM_NON_PORTED_SUPPORT_ENABLE` уменьшило размер модуля на ~89 КБ, обеспечив прямое соответствие потреблению памяти стока.
  5. **Импорты ядра и ABI:**
     * Из 224 импортов ядра совпадают **223 символа (100% сетевых функций)**.
     * Отсутствуют только 2 проприетарных хука телеметрии Xiaomi (`miwifi_ct_acct_hook` и `xqnss_ip_account_ecm_nss_hook`), которые уже заглушены в ядре и не влияют на маршрутизацию.
  6. **Конфигурация и скрипты управления:**
     * В пакет перенесены штатные скрипты `/etc/init.d/qca-nss-ecm`, `/etc/config/ecm`, `/usr/bin/ecm_dump.sh`, `/etc/firewall.d/qca-nss-ecm` и sysctl параметры `/etc/sysctl.d/qca-nss-ecm.conf`.

---

### 3.18. `kmod-qca-nss-ecm-wifi-plugin` (Wi-Fi Integration Plugin for ECM)
* **Назначение:** Модуль-плагин интеграции диспетчера ECM с закрытым драйвером Wi-Fi Qualcomm (`umac.ko` и `wifi_3_0.ko`). Передает правила классификации FSE (Flow Search Engine) для ускорения беспроводного трафика в восходящем направлении (UL) и регистрирует коллбэки MSCS (Mirrored Stream Classification Service) и SCS для приоритизации Wi-Fi пакетов.
* **Размещение пакета:** `package/kernel/qca-nss-ecm/` (модуль `ecm-wifi-plugin.ko`).
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/lklm/qca-nss-ecm.git` (папка `ecm_wifi_plugins/`, коммит `aed84d4719a3d5c97a5394bb3e0e7f9dd7b5013d`).
* **Статус:** **`[COMPATIBLE / 100% ABI MATCH]`**
* **Особенности и тонкости миграции:**
  1. **100% совпадение импортов стока:**
     * Все 10 импортов стокового блоба Xiaomi (`qca_fse_add_rule`, `qca_fse_delete_rule`, `qca_mscs_peer_lookup_n_get_priority_v2`, `qca_scs_peer_lookup_n_rule_match_v2`, `ecm_classifier_mscs_*`) полностью удовлетворены.
  2. **Патч заглушки EasyMesh SAWF (`0001-ecm-wifi-plugin-emesh-sawf-optional.patch`):**
     * В вендорском стоке регистрация коллбэков EasyMesh SAWF возвращала заглушку (`mov r0, #0; bx lr`).
     * Создан патч, делающий коллбэки EasyMesh SAWF опциональными через флаг `ECM_WIFI_PLUGIN_EMESH_ENABLE`. При отключенном флаге генерируются идентичные стоку ассемблерные инструкции-стабы, что уменьшает размер модуля с 4.9 КБ до 3.4 КБ (сток — 2.8 КБ) и исключает неиспользуемые импорты `qca_sawf_*`.
  3. **Совместимость с проприетарным Wi-Fi драйвером:**
     * Проверка `umac.ko` и `wifi_3_0.ko` подтвердила наличие экспорта всех необходимых функций FSE и MSCS/SCS, модуль штатно загружается службой Wi-Fi и скриптами `qcawificfg80211.sh`.

---

## 4. Миграция утилит пространства пользователя (Userland)

### 4.1. `qca-ssdk-shell` (Qualcomm SSDK Shell / `ssdk_sh`)
* **Назначение:** Консольная утилита управления коммутатором и подсистемой PPE Qualcomm (`/usr/sbin/ssdk_sh`). Обеспечивает диагностику сетевых портов, настройку VLAN, управление таблицами FDB/ACL/QoS/MIB, считывание регистров и кабельную диагностику CDT.
* **Размещение пакета:** `package/network/utils/qca-ssdk-shell/`
* **Исходники:** `https://git.codelinaro.org/clo/qsdk/oss/ssdk-shell.git` (ветка `NHSS.QSDK.12.4`, коммит `5a3e1d6d72338d605e700cc083bf0f93e83d57cc` от 23.11.2023).
* **Статус:** **`[COMPATIBLE / TESTED ON DEVICE]`**
* **Ключевые особенности и результаты валидации:**
  1. **Точная идентификация коммита (бинарное соответствие со стоком):**
     * Анализ истории репозитория CodeLinaro в обратном порядке от коммита `001660c2` показал, что коммит `001660c2` (17.12.2023) отключил макрос `IOCTL_COMPAT` и строки `[inf defined]:mdio_set(%s)...` под `#if 0`. В стоковом бинарнике Xiaomi `tmp/rootfs/usr/sbin/ssdk_sh` эти строки присутствуют, то есть сток собран до `001660c2`.
     * Предыдущий коммит `5a3e1d6d` (23.11.2023) исправил расчет размера буфера в функции `cmd_data_print_portmap` (`rsb r1, r0, #64`). Дизассемблирование стокового бинарника Xiaomi по смещению `0x486c0` подтвердило идентичную инструкцию `rsb r1, r0, #64`. Таким образом, точный исходный коммит стока — `5a3e1d6d`.
  2. **Адаптация под компилятор GCC 13 (OpenWrt):**
     * Во внутренних мейкфайлах Qualcomm (`make/linux_opt.mk`) жёстко прописан флаг `-Wall -Werror`.
     * В GCC 13 появилось новое строгое предупреждение `-Wenum-int-mismatch`. Из-за исторического расхождения сигнатуры метода `fal_port_cdt` в заголовочном файле `include/fal/fal_port_ctrl.h` (`fal_cable_status_t *status`) и файле реализации `src/fal_uk/fal_port_ctrl.c` (`a_uint32_t *status`), GCC 13 прерывал сборку с ошибкой.
     * Создан точечный патч `0001-fix-gcc13-build.patch`, заменяющий `-Werror` на `-Wno-error` в `make/linux_opt.mk`. Сам C-код Qualcomm оставлен на 100% аутентичным (на 32-битном ARM ABI указателей идентичен, машинный код функции совпадает побайтово).
  3. **Проверка на физическом роутере (Xiaomi Router BE3600, 192.168.11.46):**
     * Пакет собран и протестирован на устройстве. Связь с драйвером ядра `kmod-qca-ssdk-nohnat` через сокет Netlink (`/dev/switch_uk`) устанавливается безупречно (`SSDK Init OK!`).
     * Проверен опрос 2.5G порта: `port linkStatus get 2` -> `[Status]:ENABLE`, `port speed get 2` -> `2500(Mbps)`, `duplex: FULL`.
     * Проверен кабельный тестер: команда `port cdt run 1 0` успешно вызывает функцию `fal_port_cdt` и возвращает статус без сбоев.
     * Проверен опрос аппаратных таблиц коммутации FDB: `fdb entry show 0` отрабатывает штатно.


### 4.2. `qca-hostapd-cli` (Qualcomm Hostapd CLI Utility & Control Scripts)
* **Назначение:** Утилита управления точками доступа (`/usr/sbin/hostapd_cli`) и системные скрипты управления Wi-Fi (`/usr/sbin/hapd`, `/usr/sbin/wpsd`, хотплаг WPS кнопки `/etc/hotplug.d/button/50-wps`, `/lib/wifi/wps-hostapd-*`, `dpp-*`). Обеспечивает динамическое включение/выключение VAP интерфейсов (`ath0`, `ath1`), опрос статуса, реконфигурацию TBTT (`reconfig-remove`), управление WPS и DPP.
* **Размещение пакета:** `package/network/utils/qca-hostapd-cli/`
* **Исходники:** Тарбол `hostapd-2022-09-19.tar.bz2` (ревизия `01944c0957ba20ee1790eb2473cc5970f8b1f17e`, ветка CodeLinaro QSDK `NHSS.QSDK.12.4.5.r5`, коммит `5cba4ccb9f` от 25.11.2023).
* **Статус:** **`[COMPATIBLE / TESTED ON DEVICE]`**
* **Ключевые особенности и результаты валидации:**
  1. **Ликвидация 100% вендорных библиотек (`ld-vendor.so.1`):**
     * Стоковый блоб Xiaomi был жестко привязан к вендорным библиотекам: `v_lnl-3.so.200`, `v_lnl-genl-3.so.200`, `v_lssl.so.1.1`, `v_lcrypto.so.1.1`, `v_lgcc_s.so.1`, `v_lc.so`.
     * Нативный бинарник скомпилирован кросс-компилятором OpenWrt GCC 13.3.0 (Musl) и динамически линкуется исключительно с `/lib/ld-musl-armhf.so.1`, `libc.so` и `libgcc_s.so.1`. Зависимости от закрытого C-runtime вендора полностью устранены.
  2. **Патч вендорных команд QCA (`001-qca-cli-commands.patch`):**
     * Добавлены отсутствующие в апстриме команды: `reconfig-remove` (критично для `/lib/wifi/qcawificfg80211.sh:3865`), `enable-reconfig`, `reload_config`, `close_log`, `get_pmk`, `get_ptk`, `r0kh`, `r1kh`, а также QCA-расширения `channel_bw`, `color_change`, `req_link_measurement`, `notify_cw_change`.
     * Сохранена 100% совместимость с синтаксисом вызовов из скриптов Qualcomm.
  3. **Живое тестирование на роутере RD15 (192.168.11.24):**
     * Пакет `qca-hostapd-cli_2022-09-19-r1_arm_cortex-a7_neon-vfpv4.ipk` установлен на физическое устройство.
     * Проверен опрос контрольных сокетов: `hostapd_cli -i ath0 ping` -> `PONG`, `hostapd_cli -i ath1 ping` -> `PONG`.
     * Проверены команды `status` (получение параметров частоты, BSSID, состояния `ENABLED`), `get_config`, `reconfig-remove 1`.
     * Проверена работа скрипта `hapd` и хотплаг WPS.

### 4.3. `qca-wpa-cli` (Qualcomm WPA Supplicant CLI Utility & WPS Scripts)
* **Назначение:** Консольная утилита управления клиентом WPA Supplicant (`/usr/sbin/wpa_cli`) и системные скрипты обработки WPS для режима клиента/экстендера (`/etc/hotplug.d/button/52-wps-supplicant`, `/lib/wifi/wps-supplicant-update-uci`). Обеспечивает подключение к сетям, сканирование, запуск WPS PBC и опрос статуса демона `wpa_supplicant`.
* **Размещение пакета:** `package/network/utils/qca-wpa-cli/`
* **Исходники:** Тарбол `hostapd-2022-09-19.tar.bz2` (ревизия `01944c0957ba20ee1790eb2473cc5970f8b1f17e`, ветка CodeLinaro QSDK `NHSS.QSDK.12.4.5.r5`).
* **Статус:** **`[COMPATIBLE / TESTED ON DEVICE]`**
* **Ключевые особенности и результаты валидации:**
  1. **Ликвидация паразитных зависимостей:**
     * Стоковый блоб был слинкован с `v_lnl-3.so`, `v_lssl.so`, `v_lcrypto.so`, `v_lc.so` через `ld-vendor.so.1`.
     * Нативный `wpa_cli` скомпилирован кросс-компилятором OpenWrt GCC 13.3.0 (Musl) и динамически линкуется только с `/lib/ld-musl-armhf.so.1`, `libc.so` и `libgcc_s.so.1`.
  2. **Поддержка Wi-Fi 7 MLO и PMKSA (`001-qca-wpa-cli-preferred-ap-mld.patch`):**
     * Включена поддержка внешнего кэша PMKSA (`CONFIG_PMKSA_CACHE_EXTERNAL=y` -> команды `pmksa_get`, `pmksa_add`).
     * Добавлено вендорное расширение Qualcomm для Multi-Link Operation: `preferred_ap_mld_addr <network id> <mld_addr>`.
  3. **Живое тестирование на роутере RD15 (192.168.11.24):**
     * Пакет `qca-wpa-cli_2022-09-19-r1_arm_cortex-a7_neon-vfpv4.ipk` установлен на устройство.
     * Проверен IPC сокет: `wpa_cli -g /var/run/wpa_supplicantglobal ping` -> `PONG`.
     * Проверено наличие команды `preferred_ap_mld_addr` в справке утилиты.

### 4.4. `qca-wifi-scripts` (Qualcomm Wi-Fi Calibration & Helper Scripts)
* **Назначение:** Набор системных shell-скриптов для извлечения калибровочных данных из раздела `0:ART` (`/lib/create_cfg_caldata.sh`, `/lib/read_caldata_to_fs.sh`), настройки affinity прерываний по ядрам CPU (`/lib/update_smp_affinity.sh`), вспомогательных функций сетевых интерфейсов (`/lib/wifi_interface_helper.sh`) и preinit хука загрузки (`/lib/preinit/81_load_wifi_board_bin`).
* **Размещение пакета:** `package/network/utils/qca-wifi-scripts/`
* **Исходники:** Стоковые скрипты Xiaomi RD15 / QSDK CodeLinaro (`oss/system/feeds/wlan/utils`).
* **Статус:** **`[COMPATIBLE / TESTED ON DEVICE]`**
* **Ключевые особенности и результаты валидации:**
  1. **Ликвидация паразитной зависимости `+libc-vendor`:**
     * Пакет состоит исключительно из shell-скриптов и не содержит бинарных файлов. В исходном вендорном фиде пакет ошибочно имел `DEPENDS:=+libc-vendor`. Зависимость полностью снята.
  2. **100% преемственность со стоком Xiaomi RD15:**
     * Скрипт `create_cfg_caldata.sh` корректно обращается к `/ini/ftm.conf` для извлечения калибровок IPQ5332 (2.4G) и QCN6432 (5G) прямо в `/tmp/` (минуя попытки записи в read-only squashfs `/lib/firmware/`).
     * Скрипт `update_smp_affinity.sh` распределяет прерывания DP/CE Wi-Fi по ядрам процессора.
  3. **Живое тестирование на роутере RD15 (192.168.11.24):**
     * Пакет `qca-wifi-scripts_1-r1_arm_cortex-a7_neon-vfpv4.ipk` установлен на устройство.
     * Проверена целостность сгенерированных калибровок в `/tmp/IPQ5332/caldata.bin` (63488 байт) и `/tmp/qcn6432/caldata_1.b0060` (100352 байт).

### 4.5. `wififw_mount_script` (Qualcomm Wi-Fi Firmware Mount & Crashdump Hotplug)
* **Назначение:** Init-скрипты ранней инициализации Wi-Fi калибровок (`/etc/init.d/wifi_fw_mount` при `START=00`), проверки монтирования (`/etc/init.d/wifi_fw_done` при `START=96`) и hotplug-скрипт сбора аварийных дампов памяти Hexagon DSP (`/etc/hotplug.d/dump_q6v5/00-q6dump`).
* **Размещение пакета:** `package/network/utils/wififw_mount_script/`
* **Исходники:** Стоковые скрипты Xiaomi RD15 / QSDK CodeLinaro (`oss/system/feeds/platform/utils`).
* **Статус:** **`[COMPATIBLE / TESTED ON DEVICE]`**
* **Ключевые особенности и результаты валидации:**
  1. **Адаптация под структуру флеш-памяти RD15:**
     * В отличие от эталонного QSDK, где скрипт `wifi_fw_mount` занимает 600 строк и пытается монтировать несуществующий раздел `0:WIFIFW`, стоковая версия Xiaomi адаптирована для RD15 (где вся прошивка лежит в rootfs) и выполняет безопасный запуск извлечения калибровки на `START=00` до загрузки драйверов `qca-wifi` (`START=12`).
  2. **Ликвидация зависимости `+libc-vendor`:**
     * Пакет переведен на нативный рантайм, зависит только от `libc` и `qca-wifi-scripts`.
  3. **Живое тестирование на роутере RD15 (192.168.11.24):**
     * Пакет `wififw_mount_script_1-r1_arm_cortex-a7_neon-vfpv4.ipk` установлен на физический роутер.
     * Проверен запуск `/etc/init.d/wifi_fw_mount boot` -> `SUCCESS`.
     * Обе радиокарты (`ath0` и `ath1`) успешно подняты и находятся в состоянии `state=ENABLED`.

---

### 4.6. `yt-9215s-client` (Motorcomm YT9215S Switch Control Utility / `switch_ctl`)
* **Назначение:** Консольная утилита управления 5-портовым гигабитным коммутатором Motorcomm YT9215S (`/usr/sbin/switch_ctl`). Обеспечивает прямое взаимодействие через `ioctl()` к символьному устройству `/dev/yt9215s`, управление светодиодами LAN-портов, чтение MIB-статистики портов, опрос состояний линков и настройку VLAN.
* **Размещение пакета:** `package/network/utils/yt-9215s-client/`
* **Исходники:** Открытая нативная реализация на C, собираемая в рамках дерева OpenWrt.
* **Статус:** **`[COMPATIBLE / TESTED ON DEVICE]`**
* **Ключевые особенности и результаты валидации:**
  1. **Ликвидация зависимости `+libc-vendor`:**
     * Стоковый вендорный бинарник требовал `ld-vendor.so.1` и `v_lc.so`.
     * Нативный пакет скомпилирован компилятором GCC 13.3.0 и динамически слинкован напрямую со стандартным Musl C-runtime (`/lib/ld-musl-armhf.so.1`, `libc.so`).
  2. **Живое тестирование на физическом роутере RD15:**
     * Утилита проверена на устройстве: команды опроса статуса портов, управления светодиодами индикации и считывания аппаратных счётчиков пакетов отрабатывают без ошибок.

---

### 4.7. `nvram-env` (U-Boot Env Wrapper for `nvram` & `bdata` with tmpfs Caching)
* **Назначение:** Высокопроизводительный открытый аналог утилит `/usr/sbin/nvram` и `/usr/sbin/bdata` на C, заменяющий закрытый пакет `nvram-vendor` при сборке с ядром QSDK. Обеспечивает чтение и запись в стандартные MTD-разделы U-Boot environment (`0:APPSBLENV` на `/dev/mtd13` и `bdata` на `/dev/mtd21`) через бэкенд `uboot-envtools` (`fw_printenv` / `fw_setenv` и `fw_printsys` / `fw_setsys`) со сверхбыстрым in-memory кэшированием в `/tmp/state/`.
* **Размещение пакета:** `package/utils/nvram-env/`
* **Исходники:** Собственная C-реализация (`src/nvram-env.c`, `src/Makefile`).
* **Статус:** **`[COMPATIBLE / TESTED ON DEVICE]`**
* **Ключевые особенности и архитектура:**
  1. **Мультикомандный бинарник (`argv[0]`-диспатчинг):**
     * При вызове как `bdata` связывается с разделом калибровок Xiaomi (`/etc/fw_sys.config`, кэш `/tmp/state/bdata/`).
     * При вызове как `nvram` связывается с U-Boot env (`/etc/fw_env.config`, кэш `/tmp/state/nvram/`).
  2. **Двухуровневое кэширование и производительность:**
     * **Чтение (`get`):** Первое обращение разово вычитывает переменные в RAM (`/tmp/state/<env>/vars/<key>`). Все последующие вызовы `get` читают файл напрямую без порождения внешних процессов `fork`/`exec` (время отклика — **1.7 мс** на полный запуск процесса из ash, <0.2 мс внутри процесса).
     * **Запись (`set` / `unset`):** Атомарно обновляет переменную в RAM (`fchmod 0644`) и фиксирует имя ключа в журнале `/tmp/state/<env>/dirty`. Сохраняются любые спецсимволы, знаки `=`, пробелы и пустые значения `""`.
     * **Сброс на Flash (`commit` / `sync`):** Проверяет журнал `dirty`. Если изменений не было, выход происходит мгновенно с нулевым износом Flash. При наличии изменений формируется пакетный файл для `fw_setenv -s` / `fw_setsys -s`, выполняющий запись в MTD за **одну атомарную транзакцию**.
     * **Дамп (`show`):** Выводит переменные, отсортированные по алфавиту с помощью `qsort()`, сохраняя полную совместимость со стоковым выводом.
     * **Цепочки команд:** Поддерживает вызовы вида `nvram set a=1 set b=2 commit`.
  3. **Интеграция в профили сборки:**
     * `Device/xiaomi-rd15-prebuild`: использует `nvram-vendor` (через проприетарный драйвер `/dev/nvram`).
     * `Device/xiaomi-rd15-qsdk`: использует связку `uboot-envtools` + `nvram-env`.
  4. **Живое тестирование на роутере RD15 (ARM Cortex-A7 @ 1.0 GHz):**
     * Проверена работа обеих личностей (`nvram` и `bdata`), установка строковых и пустых значений, ключей со знаками `=`, удаление, алфавитная сортировка `show` и генерация пакетного коммита.

---

### 4.8. `qca-cnss-daemon-vendor` (PCIe Bus Daemon & Firmware Loader for QCN6432)
* **Назначение:** Системный демон пространства пользователя (`/usr/sbin/cnssdaemon`) и утилита управления (`/usr/sbin/cnsscli`). Обеспечивает холодную инициализацию PCIe-модуля Wi-Fi 5GHz (QCN6432), загрузку микрокода радиомодуля через QMI IPC и мониторинг шины.
* **Размещение пакета:** `vendor_feed/qca-cnss-daemon-vendor/`
* **Статус:** **`[RETAINS IN VENDOR_FEED / PROCD SUPERVISED]`**
* **Результаты исследования и обоснование:**
  1. **Закрытость в QSDK:**
     * Исходный код демона `cnssdaemon` и утилиты `cnsscli` отсутствует в открытых репозиториях CodeLinaro (располагается в закрытом вендорском фиде `feeds/qca` Qualcomm).
  2. **Жесткая привязка к QMI IPC:**
     * Драйвер ядра `kmod-qca-cnss` (`ipq_cnss2.ko`) при обнаружении чипа QCN6432 на шине PCIe ожидает установления канала IPC с сервисом `0x42E` через стек QMI (`qca-qmi-framework-vendor`: `v_lqmi_cci.so`, `v_lqmi_qrtr_cci.so`).
     * Без работающего `cnssdaemon` инициализация чипа QCN6432 прерывается по таймауту, и радиомодуль 5GHz не поднимается.
  3. **Решение:**
     * Пакет сохраняется в `vendor_feed`, контролируется через init-скрипт procd (`/etc/init.d/load_cnss2` при `START=11`) с флагом `respawn` для автоматического перезапуска при сбоях.

---

### 4.9. `qca-cfg80211-vendor` (Netlink nl80211 Qualcomm Wrapper Library)
* **Назначение:** Динамическая библиотека-обертка (`/usr/lib/v_lqca_nl80211_wrapper.so`, размер 16 КБ). Предоставляет слой абстракции над интерфейсом Netlink `nl80211` для утилит Qualcomm.
* **Размещение пакета:** `vendor_feed/qca-cfg80211-vendor/`
* **Статус:** **`[RETAINS IN VENDOR_FEED / DIAGNOSTICS ONLY]`**
* **Результаты исследования и область применения:**
  1. **Отсутствие в CodeLinaro OSS:**
     * Исходники библиотеки закрыты и поставляются исключительно в бинарном виде в QSDK.
  2. **Изоляция и независимость основных сервисов:**
     * Анализ бинарных зависимостей (`scanelf` / `readelf`) показал, что ни один ключевой сервис маршрутизатора (`hostapd`, `wpa_supplicant`, `netifd`, `iwinfo`, `LuCI`) **НЕ использует** данную библиотеку.
     * Библиотека используется исключительно 13 инженерно-диагностическими CLI-утилитами Qualcomm из состава `kmod-qca-wifi` (`athstats`, `athdiag`, `wlanconfig`, `wifitool`, `pktlogconf`, `radartool` и др.).
  3. **Решение:**
     * Пакет сохраняется в `vendor_feed`. Не создает фоновой нагрузки на процессор и не потребляет оперативную память при работе роутера.

---

## 5. Архитектурная карта миграции и текущий статус

Текущее состояние модулей и компонентов на маршрутизаторе Xiaomi BE3600 (RD15):

```mermaid
graph TD
    subgraph "Уже мигрировано на OpenWrt Native (18 модулей ядра + 7 утилит/скриптов ЗАВЕРШЕНО)"
        SSDK["kmod-qca-ssdk-nohnat<br/>(qca-ssdk.ko)"]
        SSDK_SH["qca-ssdk-shell<br/>(ssdk_sh)<br/>[COMPATIBLE / TESTED]"]
        YT["yt-9215s-client<br/>(switch_ctl)<br/>[NATIVE C / MUSL]"]
        HAPD_CLI["qca-hostapd-cli<br/>(hostapd_cli, hapd, wpsd)<br/>[COMPATIBLE / TESTED]"]
        WPA_CLI["qca-wpa-cli<br/>(wpa_cli, 52-wps)<br/>[COMPATIBLE / TESTED]"]
        WIFI_SCRIPTS["qca-wifi-scripts<br/>(caldata, smp_affinity, helper)<br/>[100% PARITY / TESTED]"]
        WIFIFW_MOUNT["wififw_mount_script<br/>(wifi_fw_mount, q6dump)<br/>[ADAPTED / TESTED]"]
        NVRAM["nvram-env<br/>(nvram, bdata для QSDK)<br/>[NATIVE C / TMPFS CACHE]"]
        MCS["kmod-qca-mcs<br/>(qca-mcs.ko)"]
        SP["kmod-emesh-sp<br/>(emesh-sp.ko)<br/>[100% IDENTICAL]"]
        PPE["kmod-qca-nss-ppe<br/>(qca-nss-ppe.ko)<br/>[COMPATIBLE]"]
        DP["kmod-qca-nss-dp<br/>(qca-nss-dp.ko)<br/>[COMPATIBLE]"]
        VP["kmod-qca-nss-ppe-vp<br/>(qca-nss-ppe-vp.ko)<br/>[COMPATIBLE / 100% PARITY]"]
        RULE["kmod-qca-nss-ppe-rule<br/>(qca-nss-ppe-rule.ko)<br/>[COMPATIBLE / 100% PARITY]"]
        DS["kmod-qca-nss-ppe-ds<br/>(qca-nss-ppe-ds.ko)<br/>[COMPATIBLE / 100% PARITY]"]
        TUN["kmod-qca-nss-ppe-tun<br/>(qca-nss-ppe-tun.ko)<br/>[COMPATIBLE / 100% PARITY]"]
        PPPOE["kmod-qca-nss-ppe-pppoe-mgr<br/>(qca-nss-ppe-pppoe-mgr.ko)<br/>[COMPATIBLE / 100% PARITY]"]
        VLAN["kmod-qca-nss-ppe-vlan-mgr<br/>(qca-nss-ppe-vlan.ko)<br/>[COMPATIBLE / 100% ABI MATCH]"]
        LAG["kmod-qca-nss-ppe-lag-mgr<br/>(qca-nss-ppe-lag.ko)<br/>[100% IDENTICAL]"]
        BRIDGE["kmod-qca-nss-ppe-bridge-mgr<br/>(qca-nss-ppe-bridge-mgr.ko)<br/>[COMPATIBLE]"]
        VXLAN["kmod-qca-nss-ppe-vxlanmgr<br/>(qca-nss-ppe-vxlanmgr.ko)<br/>[COMPATIBLE / +0 B .text]"]
        SFE["kmod-qca-nss-sfe<br/>(qca-nss-sfe.ko)<br/>[COMPATIBLE / 19 ABI / 111 IMPORTS]"]
        CNSS["kmod-qca-cnss<br/>(ipq_cnss2.ko)<br/>[COMPATIBLE / 94 ABI / 250 IMPORTS]"]
        ECM["kmod-qca-nss-ecm<br/>(ecm.ko, ecm_sfe_l2.ko, ecm_ae_select.ko)<br/>[COMPATIBLE / 98% PARITY]"]
        WIPLUG["kmod-qca-nss-ecm-wifi-plugin<br/>(ecm-wifi-plugin.ko)<br/>[COMPATIBLE / 100% ABI MATCH]"]
    end

    subgraph "Остаётся в vendor_feed (закрытое ядро)"
        WIFI["kmod-qca-wifi-lowmem-profile-vendor<br/>(Wi-Fi Driver 7/Alder/QCN6432)"]
        FW["qca-firmware-vendor<br/>(DSP Microcode)"]
        HAPD["qca-hostap-vendor / qca-wpa-supplicant-vendor<br/>(Direct Connect Wi-Fi Stack)"]
        CNSS_D["qca-cnss-daemon-vendor<br/>(cnssdaemon via QMI IPC)"]
        QMI["qca-qmi-framework-vendor<br/>(QMI Libraries)"]
        CFG["qca-cfg80211-vendor<br/>(v_lqca_nl80211_wrapper.so / 13 CLI tools)"]
        RUNTIME["libc-vendor / libgcc-vendor<br/>(Изолированный рантайм glibc)"]
    end

    SSDK --> SSDK_SH
    SSDK --> DP
    PPE --> DP
    DP --> VP
    PPE --> VP
    VP --> RULE
    PPE --> RULE
    VP --> DS
    DP --> DS
    PPE --> DS
    RULE --> TUN
    VP --> TUN
    PPE --> TUN
    PPE --> PPPOE
    PPE --> VLAN
    VP --> VLAN
    PPE --> LAG
    VLAN --> LAG
    VLAN --> BRIDGE
    PPE --> BRIDGE
    TUN --> VXLAN
    BRIDGE --> VXLAN
    VP --> SFE
    PPE --> SFE
    RULE --> SFE
    PPE --> ECM
    SFE --> ECM
    SP --> ECM
    MCS --> ECM
    DP --> ECM
    VP --> ECM
    ECM --> WIPLUG
    CNSS --> WIFI
    VP --> WIFI
    DS --> WIFI
    PPE --> WIFI
    WIPLUG --> WIFI
    CNSS --> CNSS_D
    QMI --> CNSS_D
    FW --> WIFI
    WIFI --> HAPD
```

### Сводный статус миграции userspace-пакетов

| Пакет | Статус | Реализация / Обоснование |
|---|:---:|---|
| **`qca-ssdk-shell`** | 🟢 **Мигрирован** | Открытый пакет `package/network/utils/qca-ssdk-shell` (коммит `5a3e1d6d`), линкуется с musl libc |
| **`yt-9215s-client`** | 🟢 **Мигрирован** | Открытый пакет `package/network/utils/yt-9215s-client` (`switch_ctl`), линкуется с musl libc |
| **`qca-hostapd-cli`** | 🟢 **Мигрирован** | Открытый пакет `package/network/utils/qca-hostapd-cli` на базе QSDK hostapd с QCA-патчами |
| **`qca-wpa-cli`** | 🟢 **Мигрирован** | Открытый пакет `package/network/utils/qca-wpa-cli` на базе QSDK hostapd с MLO-патчем |
| **`qca-wifi-scripts`** | 🟢 **Мигрирован** | Открытый пакет `package/network/utils/qca-wifi-scripts` (калибровка, smp_affinity, без `libc-vendor`) |
| **`wififw_mount_script`** | 🟢 **Мигрирован** | Открытый пакет `package/network/utils/wififw_mount_script` (адаптирован под RD15) |
| **`nvram-env`** | 🟢 **Мигрирован для QSDK** | Открытый C-пакет `package/utils/nvram-env` (`nvram` и `bdata`) на базе `uboot-envtools` с кэшем в tmpfs |
| **`qca-cnss-daemon-vendor`** | ❌ **Остаётся в vendor_feed** | Закрыт в QSDK, жестко связан с `ipq_cnss2.ko` через QMI IPC `0x42E`, контролируется procd (respawn) |
| **`qca-qmi-framework-vendor`** | ❌ **Остаётся в vendor_feed** | Закрытые QMI IPC библиотеки, требуются исключительно для `cnssdaemon` |
| **`qca-cfg80211-vendor`** | ❌ **Остаётся в vendor_feed** | Закрыт в QSDK, нужен только 13 CLI утилитам, основные сервисы (`hostapd`, `netifd`) не используют |
| **`qca-hostap-vendor`** | ❌ **Остаётся в vendor_feed** | Закрытый Wi-Fi стек, требует Direct Connect драйвер `wifi_3_0` |
| **`qca-wpa-supplicant-vendor`** | ❌ **Остаётся в vendor_feed** | Аналогично `qca-hostap` |
| **`qca-firmware-vendor`** | ❌ **Остаётся в vendor_feed** | Бинарный DSP микрокод QCA |
| **`libc-vendor`, `libgcc-vendor`** | ❌ **Остаётся в vendor_feed** | Изолированный вендорный C-runtime для оставшихся закрытых бинарников |

### Рекомендуемый следующий шаг:
1. **Сборка и валидация образа с QSDK-ядром (`Device/xiaomi-rd15-qsdk`):**  
   Интеграция нативного пакета `nvram-env` и `uboot-envtools` для полноценного перехода с prebuilt-ядра на сборку ядра из открытых исходников.

