# Ядро Linux 5.4.213 QSDK, модули ядра и миграция vendor_feed (Xiaomi BE3600 / RD15)

## 1. Методология сборки и инструментарий валидации ABI

Маршрутизатор **Xiaomi Router BE3600 (RD15)** работает под управлением монолитного ядра **Linux 5.4.213** (ветка Qualcomm CodeLinaro QSDK 12.4). Для обеспечения полной совместимости со стоковым ядром и закрытыми драйверами вендора в проекте используется строгая методология валидации:

### 1.1. Правило двух компиляторов и вермаджик (Vermagic)
* **Вермаджик ядра стоковой прошивки**: `5.4.213 SMP preempt mod_unload ARMv7 p2v8`.
* **Выделенный тулчейн ядра (GCC 7.5.0 + Binutils 2.31.1)**:
  В каталоге `vendor_toolchain/` содержится автономная система сборки компилятора GCC 7.5.0 (`toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel`). Все модули ядра (`kmod-*`) и само ядро компилируются строго этим компилятором через оверрайд в `target/linux/ipq53xx/rd15/target.mk`:
  ```makefile
  KERNEL_TOOLCHAIN_DIR_NAME:=toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel
  KERNEL_CROSS:=$(KERNEL_TOOLCHAIN_DIR)/bin/arm-openwrt-linux-muslgnueabi-
  KERNEL_CC:=$(KERNEL_CROSS)gcc
  ```
* **Основной тулчейн OpenWrt 24 (GCC 13.3.0 + Musl libc)**:
  Используется для сборки всей системы, демонов и пакетов пространства пользователя (userland). Это исключает баги несовместимости структур ядра при одновременном сохранении современного юзерспейса.

### 1.2. Критерии валидации открытых модулей
1. **Символьный аудит (`vendor_scripts/compare_kmod.py`)**: Парсинг ELF-таблиц (`readelf` / `pyelftools`) гарантирует, что все экспортируемые функции совпадают на 100%, а все запрашиваемые импорты присутствуют в ядре.
2. **Бинарный и дизассемблерный анализ**: Сопоставление размера секции кода `.text` и структуры машинных инструкций стокового блоба и открытого модуля.
3. **Физическая валидация на роутере RD15**: Проверка связывания модулей (`lsmod`), отсутствия ошибок в `dmesg`, корректности счетчиков в `debugfs` и стресс-тестирование скорости передачи данных.

---

## 2. Сводная таблица миграции 18 модулей ядра

Все 18 проприетарных модулей Qualcomm и Motorcomm успешно переведены из бинарного вендорного фида в нативные открытые пакеты OpenWrt (`package/kernel/`):

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
| **`kmod-qca-nss-ppe-pppoe-mgr`** | `qca-nss-ppe-pppoe-mgr.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **21/21 импортов**, **4/4 функций** (.text diff **+0 байт**, 99.95% сходство) |
| **`kmod-qca-nss-ppe-vlan-mgr`** | `qca-nss-ppe-vlan.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **10/10 экспортов**, **50/50 импортов**, **25 функций** (.text diff -176 байт) |
| **`kmod-qca-nss-ppe-lag-mgr`** | `qca-nss-ppe-lag.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[IDENTICAL]`** | **100% побайтовое совпадение** (+0 байт diff, 21/21 импортов) |
| **`kmod-qca-nss-ppe-bridge-mgr`** | `qca-nss-ppe-bridge-mgr.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **2/2 экспортов (100%)**, **53/53 импортов (100%)**, .text diff -16 байт |
| **`kmod-qca-nss-ppe-vxlanmgr`** | `qca-nss-ppe-vxlanmgr.ko` | `oss/lklm/nss-ppe.git` | `0c6434d7` (19.01.2024) | **`[COMPATIBLE]`** | **2/2 экспортов (100%)**, **62/62 импортов (100%)**, .text diff **+0 байт** (98.78% сходство) |
| **`kmod-qca-nss-sfe`** | `qca-nss-sfe.ko` | `oss/lklm/shortcut-fe.git` | `7d82c710` (20.03.2024) | **`[COMPATIBLE]`** | **19/19 экспортов (100%)**, **111/111 импортов (100%)**, .text diff +2192 байта |
| **`kmod-qca-cnss`** | `ipq_cnss2.ko` | `oss/wifi/qca-cnss.git` | `17fe2f6d` (16.11.2023) | **`[COMPATIBLE]`** | **94/94 экспортов (100%)**, **250/250 импортов (100%)**, устранена аллокация 2 MB QDSS DMA |
| **`kmod-qca-nss-ecm`** | `ecm.ko`, `ecm_sfe_l2.ko`, `ecm_ae_select.ko` | `oss/lklm/qca-nss-ecm.git` | `aed84d47` (15.11.2023) | **`[COMPATIBLE]`** | **223/224 импортов (100% сетевых)**, .text diff -2.0%, полное совпадение протоколов |
| **`kmod-qca-nss-ecm-wifi-plugin`** | `ecm-wifi-plugin.ko` | `oss/lklm/qca-nss-ecm.git` | `aed84d47` (15.11.2023) | **`[COMPATIBLE]`** | **10/10 импортов стока (100%)**, FSE + MSCS/SCS, опциональный EasyMesh SAWF |

---

## 3. Детальные заметки о сделанных изменениях и их технических причинах

### 3.1. `kmod-emesh-sp` (EasyMesh Service Prioritization)
* **Размещение**: `package/kernel/emesh-sp/`
* **Исходники**: `oss/lklm/emesh-sp.git` (коммит `3de1a656`).
* **Результат**: **100% Bit-for-bit совпадение**. Размер секции `.text` ровно **11 408 байт** (разница 0 байт со стоком).
* **Причина стабильности**: В модуле отсутствуют платформенные завязки на Device Tree; компилятор GCC 7.5.0 сгенерировал машинный код, идентичный стоковому блобу байт-в-байт.

---

### 3.2. `kmod-qca-nss-ppe` (Programmable Packet Engine Core Driver)
* **Размещение**: `package/kernel/qca-nss-ppe/`
* **Исходники**: `oss/lklm/nss-ppe.git` (коммит `0c6434d7` от 19.01.2024).
* **Ключевые изменения и обоснование**:
  1. **Унификация коммита с `qca-nss-ppe-vp` (отказ от `a9998acd` в пользу `0c6434d7`)**:
     * Изначально модуль собирался на коммите `a9998acd` (май 2024). Однако зависимый модуль `ppe-vp` требовал коммит `0c6434d7` из-за изменения сигнатуры коллбэков виртуальных портов.
     * *Бинарное доказательство из стока:* в `ppe_drv_sc.c` на коммите `0c6434d7` маска сервисного кода `bypass_bitmap[1]` равна `0x34a0` (бит `BRIDGING_FWD_BYP`). Коммит `a9998acd` изменил ее на `0x3420`. В стоковом бинарнике Xiaomi по смещениям `0x1a30c` и `0x1a328` находится именно константа `0x34a0`. Это доказывает, что заводской драйвер собран на версии до `a9998acd`.
     * Разница `.text` сократилась до +464 байт (219 488 байт против 219 024 байт).
  2. **Зависимость от заголовков nat46**:
     * В `drv/ppe_drv/tun/ppe_drv_tun.c` используется `#include <nat46/nat46-core.h>`.
     * В `EXTRA_CFLAGS` пакета добавлено `-I$(STAGING_DIR)/usr/include` для корректного нахождения заголовков `kmod-nat46`.
  3. **Диагностические утилиты**:
     * Пакет устанавливает `/usr/bin/ppe_flow_dump` и `/usr/bin/ppe_if_map`, монтирующие отладочные узлы `debugfs`.

---

### 3.3. `kmod-qca-mcs` (Multicast Snooping & Forwarding Driver)
* **Размещение**: `package/kernel/qca-mcs/`
* **Исходники**: `oss/lklm/qca-mcs.git` (коммит `2237266b` от 07.02.2024).
* **Ключевые изменения и обоснование**:
  * Обязательно требуется флаг сборки `CONFIG_SUPPORT_MLD=y` для поддержки IPv6 MLD Snooping. Все 12 экспортов и 59 импортов ядра совпадают на 100%.

---

### 3.4. `kmod-qca-ssdk-nohnat` (Qualcomm Switch & PHY Subsystem SDK)
* **Размещение**: `package/kernel/qca-ssdk/`
* **Исходники**: `oss/lklm/qca-ssdk.git` (ветка `NHSS.QSDK.12.4`, коммит `2e8bf996` от 16.11.2023).
* **Ключевые изменения и обоснование**:
  1. **Идентификация коммита (переход с `0ac166a1` на `2e8bf996`)**:
     * *Символ `phy_gbit_features`:* В коммите `630d17e6` (23.02.2024) Qualcomm убрал статическую маску `.features = PHY_GBIT_FEATURES`. В стоке Xiaomi этот символ импортируется из ядра. На коммите `2e8bf996` маска возвращается, давая ровно 137 из 137 импортов ядра.
     * *Опечатка `Recieved IOCTL call`:* Коммит `514aa723` (18.12.2023) исправил опечатку `Recieved` $\to$ `Received` в `sw_api_ks_ioctl.c`. В стоковом бинарнике присутствует опечатка `Recieved`, что доказывает сборку стока до 18.12.2023.
     * *Сброс скорости на 1G:* Инструкции `moveq r7, #1000` и `moveq r9, #1` в `mht_port_link_update` по адресу `0x70ef4` стока соответствуют коду коммита `2e8bf996`.
  2. **Профиль сборки стока**:
     * Флаги: `SoC=ipq53xx CHIP_TYPE=MPPE PTP_FEATURE=disable MINI_SSDK=enable IN_AQUANTIA_PHY=FALSE IN_QCA803X_PHY=FALSE IN_MALIBU_PHY=FALSE`.
  3. **Патч экспорта `fal_port_reset` (`001-export-fal_port_reset.patch`)**:
     * При `MINI_SSDK=enable` функция `fal_port_reset` исключалась макросом `IN_PORTCONTROL_MINI`. Патч восстанавливает экспорт, обеспечивая совпадение всех 443 экспортов таблицы ABI.

---

### 3.5. `kmod-qca-nss-dp` (NSS Data Plane / EDMA Ethernet driver)
* **Размещение**: `package/kernel/qca-nss-dp/`
* **Исходники**: `oss/lklm/nss-dp.git` (коммит `93102877` от 01.02.2024).
* **Ключевые изменения и обоснование**:
  1. **Критический флаг `MAKE_OPTS:=dp-ppe-ds=y`**:
     * Включает компиляцию Direct Switch (`hal/dp_ops/edma_dp/edma_v2/edma_ppeds.o`), экспорт `nss_dp_ppeds_get_ops` и блокировки `_raw_read_lock_bh` / `_raw_write_lock_bh`.
  2. **Патч `001-remove-phy-stop-on-close.patch`**:
     * Убирает вызов `phy_stop(dp_priv->phydev)` в `nss_dp_close()`, повторяя логику стока Xiaomi. Это предотвращает остановку стейт-машины PHY при выключении линка, которая ломала фоновый опрос портов в SSDK.
  3. **Сервисы и утилиты**:
     * Init-скрипт `/etc/init.d/qca-nss-dp` настраивает SMP affinity прерываний `edma_rxdesc` и `edma_txcmpl` по ядрам CPU; устанавливается утилита `/usr/bin/edma_dump`.

---

### 3.6. `kmod-qca-nss-ppe-vp` (PPE Virtual Ports core driver)
* **Размещение**: `package/kernel/qca-nss-ppe-vp/`
* **Исходники**: `oss/lklm/nss-ppe.git` (коммит `0c6434d7`).
* **Ключевые изменения и обоснование**:
  * В коммите `3e9af47d` (09.02.2024) сигнатура коллбэка VP была переписана с `bool (*)(struct net_device *, ...)` на `bool (*)(struct ppe_vp_cb_info *, ...)`.
  * Стоковая прошивка Xiaomi и закрытый модуль Wi-Fi `wifi_3_0.ko` ожидают старую сигнатуру с `struct net_device *dev`. Выбор коммита `0c6434d7` обеспечил 100% совместимость структур без риска Kernel Panic.

---

### 3.7. `kmod-qca-nss-ppe-rule` (PPE Rule / RFS Engine)
* **Размещение**: `package/kernel/qca-nss-ppe-rule/`
* **Исходники**: `oss/lklm/nss-ppe.git` (коммит `0c6434d7`).
* **Ключевые изменения и обоснование**:
  * Включение профиля `PPE_LOWMEM_PROFILE_256M=y` и опций `MAKE_OPTS:=ppe-rule=y PPE_RFS_ENABLED=y PPE_RULE_IPQ53XX=y`. Это исключило неиспользуемые модули ACL/Mirror, предотвратило ошибки `-Werror=undef` и обеспечило точный состав объектников стока (`ppe_rule.o`, `ppe_rfs.o`, `ppe_rfs_stats.o`).

---

### 3.8. `kmod-qca-nss-ppe-ds` (PPE Direct Switch driver)
* **Размещение**: `package/kernel/qca-nss-ppe-ds/`
* **Исходники**: `oss/lklm/nss-ppe.git` (коммит `0c6434d7`).
* **Ключевые изменения и обоснование**:
  * **Размер кода**: ровно 6 036 байт (+0 байт разницы со стоком).
  * **Патч `0001-ppe-ds-lowmem-rxfill-threshold.patch`**: Для профиля `PPE_LOWMEM_PROFILE_256M` значение порога `PPE_DS_WLAN_RXFILL_LOWMEM_THRESHOLD` установлено в 256 дескрипторов (вместо 1024), что на 100% соответствует стоку Xiaomi и экономит память буферов skb.

---

### 3.9. `kmod-qca-nss-ppe-tun` (PPE Tunneling Offload driver)
* **Размещение**: `package/kernel/qca-nss-ppe-tun/`
* **Исходники**: `oss/lklm/nss-ppe.git` (коммит `0c6434d7`).
* **Ключевые изменения и обоснование**:
  * **Патч `001-disable-acl-on-lowmem-profile.patch`**: В апстриме коммит `96a10ab` добавил вызовы `ppe_acl_rule_create/destroy`. В профиле 256M подсистема ACL отключена. Патч обернул вызовы ACL в макрос `!defined(NSS_PPE_LOWMEM_PROFILE_256M)`, устранив ошибку линковки и обеспечив побайтовое совпадение `.text` (10 828 байт, +0 байт diff).

---

### 3.10. `kmod-qca-nss-ppe-pppoe-mgr` (PPE PPPoE Client Manager)
* **Размещение**: `package/kernel/qca-nss-ppe-pppoe-mgr/`
* **Исходники**: `oss/lklm/nss-ppe.git` (коммит `0c6434d7`, `clients/pppoe/`).
* **Ключевые изменения и обоснование**:
  * Размер секции `.text`: ровно **2 156 байт** (+0 байт diff). Побайтовое сходство 99.95%. Активирована поддержка `kmod-bonding` (`BONDING_SUPPORT`).

---

### 3.11. `kmod-qca-nss-ppe-vlan-mgr` (PPE VLAN Client Manager)
* **Размещение**: `package/kernel/qca-nss-ppe-vlan/`
* **Исходники**: `oss/lklm/nss-ppe.git` (коммит `0c6434d7`, `clients/vlan/`).
* **Ключевые изменения и обоснование**:
  1. **Анализ разницы в 176 байт (`vp_wan_interface`)**:
     * В стоке Xiaomi была добавлена запись `/proc/sys/ppe/vlan_client/vp_wan_interface`. Анализ всего стокового rootfs показал **0 мест использования** — ни один скрипт или сервис стока этот узел не вызывал. Рудимент не переносился; параметр штатно доступен через sysfs `vlan_as_vp_interface`.
  2. **Патч `0001-default-vlan-as-vp-interface.patch`**:
     * Значение по умолчанию параметра `vlan_as_vp_interface` установлено в `"eth0"`, что обеспечивает автоматическую регистрацию Virtual Port для VLAN на базе eth0.

---

### 3.12. `kmod-qca-nss-ppe-lag-mgr` (PPE Link Aggregation Manager)
* **Размещение**: `package/kernel/qca-nss-ppe-lag/`
* **Исходники**: `oss/lklm/nss-ppe.git` (коммит `0c6434d7`, `clients/lag/`).
* **Результат**: **100% Bit-for-bit совпадение**. Размер секции `.text` ровно **2 520 байт** (+0 байт diff). 21 из 21 импортов ядра.

---

### 3.13. `kmod-qca-nss-ppe-bridge-mgr` (PPE Bridge Manager)
* **Размещение**: `package/kernel/qca-nss-ppe-bridge/`
* **Исходники**: `oss/lklm/nss-ppe.git` (коммит `0c6434d7`, `clients/bridge/`).
* **Ключевые изменения и обоснование**:
  * Параметр `NSS_PPE_BRIDGE_MGR_FDB_LEARNING=n` синхронизирован со стоком Xiaomi, предотвращая дублирование записей FDB аппаратным свитчом.

---

### 3.14. `kmod-qca-nss-ppe-vxlanmgr` (PPE VxLAN Tunnel Manager)
* **Размещение**: `package/kernel/qca-nss-ppe-vxlan/`
* **Исходники**: `oss/lklm/nss-ppe.git` (коммит `0c6434d7`, `clients/vxlanmgr/`).
* **Результат**: **100% Parity**. Размер секции `.text` ровно **11 400 байт** (+0 байт diff). Стал 10-м и последним модулем семейства PPE, полностью ликвидировав закрытые блобы PPE в `vendor_feed`.

---

### 3.15. `kmod-qca-nss-sfe` (Shortcut Forwarding Engine)
* **Размещение**: `package/kernel/qca-nss-sfe/`
* **Исходники**: `oss/lklm/shortcut-fe.git` (коммит `7d82c710` от 20.03.2024).
* **Ключевые изменения и обоснование**:
  * Для RD15 применены флаги `SFE_256M_PROFILE=y` и `EXTRA_CFLAGS += -DSFE_MEM_PROFILE_LOW`.
  * Размер хэш-таблицы ограничен `SFE_MAX_CONNECTION_HASH_ORDER=9` (максимум 512 соединений по умолчанию в `/sys/module/qca_nss_sfe/parameters/max_ipv4_conn`), что на 100% соответствует поведению стока.
  * В пакет интегрирована утилита `/usr/bin/sfe_dump`.

---

### 3.16. `kmod-qca-cnss` (Qualcomm Wi-Fi Bus Driver)
* **Размещение**: `package/kernel/qca-cnss/` (модуль `ipq_cnss2.ko`).
* **Исходники**: `oss/wifi/qca-cnss.git` (коммит `17fe2f6d` от 16.11.2023).
* **Ключевые изменения и обоснование**:
  * **Устранение утечки 2.0 МБ DMA-памяти QDSS (переход с `3cbb15d2` на `17fe2f6d`)**:
    В коммите `3cbb15d2` драйвер принудительно выделял 2.0 МБ непрерывной DMA-памяти под отладочную трассировку `qdss_mem`. В стоке Xiaomi драйвер собран на коммите `17fe2f6d`, где QDSS буфер не выделяется. Переход на `17fe2f6d` освободил 2.0 МБ RAM, дав 100% паритет свободной памяти со стоком.
  * Намеренно не используется `AUTOLOAD`: запуск строго контролируется сервисом `/etc/init.d/load_cnss2` (START=11), парсящим `cnss2.*` из `/proc/cmdline`.

---

### 3.17. `kmod-qca-nss-ecm` (Enhanced Connection Manager - Premium)
* **Размещение**: `package/kernel/qca-nss-ecm/` (`ecm.ko`, `ecm_sfe_l2.ko`, `ecm_ae_select.ko`).
* **Исходники**: `oss/lklm/qca-nss-ecm.git` (коммит `aed84d47` от 15.11.2023).
* **Ключевые изменения и обоснование**:
  1. Суффикс `-premium` собирается из **открытых исходников** репозитория CodeLinaro.
  2. **Отключение `ECM_NON_PORTED_SUPPORT_ENABLE`**: В стоке ускорение протоколов без портов (ICMP/IGMP/ESP) отключено. Отключение опции уменьшило размер модуля на ~89 КБ, полностью повторив профиль памяти стока.
  3. **Импорты ядра**: 223 из 224 символов совпадают. Отсутствуют только 2 телеметрических хука Xiaomi (`miwifi_ct_acct_hook` и `xqnss_ip_account_ecm_nss_hook`), которые безопасно заглушены в ядре патчем `904-vendor-compat-stubs.patch`.

---

### 3.18. `kmod-qca-nss-ecm-wifi-plugin` (Wi-Fi Integration Plugin for ECM)
* **Размещение**: `package/kernel/qca-nss-ecm/` (`ecm-wifi-plugin.ko`).
* **Исходники**: `oss/lklm/qca-nss-ecm.git` (`ecm_wifi_plugins/`, коммит `aed84d47`).
* **Ключевые изменения и обоснование**:
  * **Патч заглушки EasyMesh SAWF (`0001-ecm-wifi-plugin-emesh-sawf-optional.patch`)**:
    В стоке Xiaomi регистрация коллбэков SAWF возвращала заглушку (`mov r0, #0; bx lr`). Патч делает коллбэки опциональными (`ECM_WIFI_PLUGIN_EMESH_ENABLE=n`), генерируя стабы и уменьшая размер модуля с 4.9 КБ до 3.4 КБ без лишних импортов `qca_sawf_*`.

---

## 4. Открытые утилиты пространства пользователя (Userland)

1. **`package/network/utils/qca-ssdk-shell`**: Консольная утилита `/usr/sbin/ssdk_sh` для управления коммутатором и PPE. Патч `0001-fix-gcc13-build.patch` заменяет `-Werror` на `-Wno-error` в `make/linux_opt.mk` для устранения строгого предупреждения `-Wenum-int-mismatch` в GCC 13.
2. **`package/network/utils/qca-hostapd-cli`**: Нативный бинарник `/usr/sbin/hostapd_cli` и скрипты `hapd`, `wpsd`. Патч `001-qca-cli-commands.patch` добавляет команды `reconfig-remove`, `enable-reconfig`, `reload_config`. Слинкован с системным Musl libc.
3. **`package/network/utils/qca-wpa-cli`**: Нативный `/usr/sbin/wpa_cli`. Патч `001-qca-wpa-cli-preferred-ap-mld.patch` добавляет команду MLO `preferred_ap_mld_addr`.
4. **`package/network/utils/qca-wifi-scripts`**: Shell-скрипты калибровки (`create_cfg_caldata.sh`), распределения прерываний (`update_smp_affinity.sh`). Полностью устранены паразитные зависимости от `libc-vendor`.
5. **`package/network/utils/wififw_mount_script`**: Скрипты `/etc/init.d/wifi_fw_mount` (START=00) и `/etc/init.d/wifi_fw_done` (START=96).
6. **`package/network/utils/yt-9215s-client`**: Открытый C-клиент `/usr/sbin/switch_ctl` для прямого `ioctl` контроля коммутатора Motorcomm.
7. **`package/utils/nvram-env`**: Открытый аналог утилит `nvram` и `bdata` на C с молниеносным in-memory кэшированием в `/tmp/state/` и пакетной записью в MTD (`fw_setenv -s`), защищающей флеш-память от износа.

---

## 5. Текущий состав `vendor_feed` (17 пакетов)

Благодаря успешной миграции 18 драйверов и 7 утилит, состав `vendor_feed/` сокращен с исходных 87 пакетов до **17 строго изолированных компонентов**:

* **Библиотеки вендора с изоляцией `ld-vendor.so.1` (10 пакетов)**:
  `libc-vendor`, `libgcc-vendor`, `libnl-core-vendor`, `libnl-genl-vendor`, `libnl-nf-vendor`, `libnl-route-vendor`, `libnl-vendor`, `libopenssl-vendor`, `libpthread-vendor`, `libroxml-vendor`, `librt-vendor`.
* **Утилиты и демоны (6 пакетов)**:
  * `nvram-vendor` (используется только в профиле `prebuild`).
  * `qca-cnss-daemon-vendor` (демон PCIe шины QCN6432, завязан на закрытый QMI IPC сервис `0x42E`).
  * `qca-firmware-vendor` (бинарные прошивки радиомодулей).
  * `qca-hostap-vendor` (закрытый аутентификатор hostapd).
  * `qca-qmi-framework-vendor` (библиотеки QMI IPC: `v_lqmi_cci.so`, `v_lqmi_qrtr_cci.so`).
  * `qca-wpa-supplicant-vendor` (клиент WPA для режима повторителя).
* **Модуль ядра вендора (1 пакет)**:
  * `kmod-qca-wifi-lowmem-profile-vendor` (бинарные модули Wi-Fi Direct Connect: `umac.ko`, `qca_ol.ko`, `wifi_3_0.ko`, `mem_manager.ko`, `qdf.ko`).
* **Диагностическая библиотека (1 пакет)**:
  * `qca-cfg80211-vendor` (`v_lqca_nl80211_wrapper.so`, используется только отладочными утилитами `athstats`, `athdiag`).

---

## 6. Конвейер автоматической генерации `vendor_feed`

Главным инструментом создания и обновления вендорного фида является скрипт **`vendor_scripts/prepare_feed.sh`**, автоматизирующий полный цикл извлечения и подготовки проприетарных компонентов из стоковой прошивки Xiaomi (`miwifi_rd15_firmware_*.bin`):

### 6.1. Этапы работы `prepare_feed.sh`:
1. **Распаковка фабричного UBI-образа**:
   Извлекает тома с помощью `ubireader_extract_images` во временный каталог `tmp/`.
2. **Извлечение и сохранение ядра**:
   Находит извлеченный том ядра `img-*_vol-kernel.ubifs` и копирует его в `target/linux/ipq53xx/rd15/kernel` (для сборки профиля `xiaomi-rd15-prebuild`).
3. **Распаковка корневой файловой системы**:
   Распаковывает том `img-*_vol-ubi_rootfs.ubifs` через `unsquashfs` в `tmp/rootfs/` и накладывает оверлей `vendor_data/` (если присутствует).
4. **Символьный анализ зависимостей модулей ядра (`extract_kmod_deps.py`)**:
   Анализирует все файлы `.ko` стокового образа, строит граф экспортируемых и запрашиваемых символов и формирует карту зависимостей `tmp/kmod_deps.json`.
5. **Построение дерева фида в оперативной памяти (`generate_feed.py`)**:
   Считывает `opkg status` стока и `kmod_deps.json`, строит полный граф пакетов, валидирует наличие всех компонентов из `required.list` и генерирует Makefiles пакетов в каталоге `vendor_feed/`.
6. **ELF-версионирование и патчинг пакетов (`patch_package.py`)**:
   Модифицирует каждый пакет фида: переименовывает разделяемые библиотеки с префиксом `v_l*.so`, перенаправляет динамический линковщик `PT_INTERP` на `/lib/ld-vendor.so.1`, обновляет поля `DT_SONAME` / `DT_NEEDED` и патчит сервисные init-скрипты (`load_cnss2`, `qca-hostapd`).
7. **Регистрация фида в системе сборки**:
   Автоматически добавляет локальную ссылку `src-link vendor_feed ../vendor_feed` в файл `feeds.conf`.

> **Примечание по `modules.builtin`**:
> Файл `modules.builtin` в конвейере сборки **НЕ генерируется**. Конфигурация ядра зафиксирована статически в `target/linux/ipq53xx/rd15/config-5.4`. Более того, в `target/linux/ipq53xx/image/rd15.mk` на этапе `Image/Prepare` файлы `modules.builtin*` **принудительно вычищаются** (`rm -f $(TARGET_DIR)/lib/modules/*/modules.builtin*`), чтобы предотвратить конфликты сборочной системы OpenWrt и механизма загрузки внешних модулей. Утилита `extract_kernel_config.py` является автономным вспомогательным инструментом для разового извлечения `IKCONFIG` из стокового FIT-ядра и не входит в регулярный конвейер.

---

### 6.2. Списки пакетов и фильтрация модулей

Конвейер опирается на 3 конфигурационных списка в `vendor_scripts/`:

1. **`vendor_scripts/required.list`** (Обязательный минимум беспроводного маршрутизатора):
   Список из **10 ключевых вендорных пакетов**, без которых невозможна работа проприетарного Wi-Fi стека и калибровок:
   ```text
   kmod-qca-wifi-lowmem-profile
   nvram
   qca-cnss-daemon
   qca-firmware
   qca-hostap
   qca-hostapd-cli
   qca-wifi-scripts
   qca-wpa-cli
   qca-wpa-supplicant
   wififw_mount_script
   ```
   *(Библиотеки `v_l*` подтягиваются генератором автоматически как транзитивные зависимости).*

2. **`vendor_scripts/packages.list`** (Входной список генератора):
   Определяет перечень пакетов, для которых `generate_feed.py` строит спецификации сборки. Все компоненты, перенесенные в открытые исходники OpenWrt, исключены из этого списка.

3. **`vendor_scripts/native.list`** (Список открытых модулей ядра):
   Содержит перечень модулей ядра (Netfilter, криптография, файловые системы, туннели, PPE, SSDK, свитч YT9215S), которые **запрещено извлекать из стока**, так как они компилируются штатными пакетами OpenWrt из исходников ядра QSDK 12.4 или открытых репозиториев.

---

### 6.3. Вспомогательные скрипты конвейера

* **`vendor_scripts/patch_feeds.py`**:
  Идемпотентный Python-скрипт, применяющий сборочные патчи к системным фидам OpenWrt после выполнения `./scripts/feeds update`:
  - Добавляет `DEPENDS:=+libgcc` в пакет `feeds/luci/contrib/package/lucihttp/Makefile`.
  - Добавляет `DEPENDS:=+libatomic +libgcc` в пакет `feeds/packages/net/iperf3/Makefile`.
* **`vendor_scripts/prepare_config.sh`**:
  Применяет целевую конфигурацию `defconfig` сабтаргета `rd15`, выставляет архитектурные параметры и генерирует итоговый рабочий `.config`.
* **`vendor_scripts/build_kmod_toolchain.sh`**:
  Запускает автоматическую компиляцию изолированного тулчейна ядра GCC 7.5.0 в `vendor_toolchain/`.

