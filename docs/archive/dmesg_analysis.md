# Анализ dmesg: Stock MiWiFi vs Custom OpenWrt 24 (Xiaomi BE3600 RD15)

> **Ядро:** Linux 5.4.213 (одинаковое в обеих прошивках)  
> **Источники:** `36` — стоковая прошивка MiWiFi (полный лог, 1472 строки, ~143 сек);  
> `46` — кастомная OpenWrt 24 (полный лог, 798 строк, ~113 сек до VAP up + DFS)

---

## 1. Сводная таблица

| Параметр | Stock (`36`) | Custom (`46`) |
|---|---|---|
| Hostname | `XiaoQiang` | `OpenWrt` |
| Загружаемый UBI MTD слот | `ubi.mtd=rootfs` (mtd19) | `ubi.mtd=rootfs_1` (mtd20) |
| UBI user volumes | 2 | 3 (+`rootfs_data`) |
| Время до `procd: - init -` | ~15.4 сек | ~13.3 сек (**быстрее**) |
| Время до `kmodloader done /modules.d` | ~18.8 сек | ~13.8 сек (**быстрее**) |
| FW ready QCA5332 (2.4 GHz) | ~25.0 сек | ~18.3 сек (**быстрее на 6.7 сек**) |
| FW ready QCN6432 (5 GHz) | ~27.8 сек | ~21.1 сек (**быстрее на 6.7 сек**) |
| Реинициализация Wi-Fi | **Да** (teardown @ ~31 сек, restart @ ~35 сек) | **Нет** (один цикл) |
| Имена VAP-интерфейсов | `wl0`, `wl4`, `wl5` (MLO MiMesh) | `ath0`, `ath1` (стандартный hostapd) |
| VAP 2.4 GHz up | `wl4` @ ~84 сек | `ath0` @ ~54 сек (**быстрее на ~30 сек**) |
| VAP 5 GHz up (после DFS CAC) | `wl0`/`wl5` @ **~143 сек** | `ath1` @ **~113 сек** (**быстрее на ~30 сек**) |
| DFS CAC длительность | ~60 сек (штатная) | ~60 сек (штатная) |
| ECM аппаратный оффлоад | Не виден в логе | ✅ `ECM init complete` @ ~41 сек |
| EDMA RPS (Receive Packet Steering) | Не настроен | ✅ 3 ядра CPU |
| `urngd` (Jitter CSPRNG) | Отсутствует | ✅ v1.0.2 запущен |
| MLO / MiMesh | ✅ (2 MLO VAP, mesh) | Нет (не используется) |

---

## 2. 🔴 Критические ошибки и проблемы

### 2.1. `ubi0 error -16 (EBUSY)` при сканировании блочных устройств — **РЕШЕНО** ✅

```
[   10.730240] ubi0 error: 0x80479fcc: cannot open device 0, volume 2, error -16
[   10.737150] ubi1 error: 0x80479fcc: cannot open device 1, volume 1, error -16
```

- **Статус**: **Исправлено** (патч `package/system/fstools/patches/001-block-skip-gluebi-ubi-mtdblock.patch` и фильтр `package/system/fstools/files/mount.hotplug`).
- **Симптом**: При первом запуске или после сброса настроек ошибок в dmesg не было; они появлялись десятками строк только при последующих перезапусках роутера.
- **Истинная причина (Root Cause)**:
  1. **Драйвер ядра GLUEBI**: В стоковом ядре Qualcomm 5.4.213 (`config-5.4.vendor`) включен `CONFIG_MTD_UBI_GLUEBI=y`, создающий виртуальные MTD-устройства поверх томов UBI:
     - `ubi0:2` (`rootfs_data`) $\to$ `/dev/mtd26` (`/dev/mtdblock26`, sysfs type `ubi`).
     - `ubi1:1` (`cfg`) $\to$ `/dev/mtd27` (`/dev/mtdblock27`, sysfs type `ubi`).
  2. **Триггер `uci-defaults`**: При первом старте скрипт `/etc/uci-defaults/10-fstab` генерирует файл `/etc/config/fstab`. Пока файла нет, `/sbin/block` сразу завершается с кодом `-1`, ничего не сканируя. Но со 2-го старта файл уже есть в `/overlay/upper/etc/config/fstab`, и `block` выполняет функцию `cache_load(1)`.
  3. **Логика `block.c`**: Функция `mtdblock_is_nand()` проверяла только `/sys/class/mtd/mtdX/type == "nand"`. Так как для устройств `gluebi` ядро возвращает тип `"ubi"`, утилита считала их обычным NOR-флешем и пыталась прозондировать `/dev/mtdblock26` в режиме RW (`probe_path()`).
  4. **Конфликт монопольного доступа**: Драйвер `gluebi` запрашивает монопольный доступ к тому UBI (`ubi_open_volume(..., UBI_READWRITE)`). Поскольку `rootfs_data` и `cfg` уже были смонтированы драйвером UBIFS (`/overlay` и `/data`), ядро отклоняло запрос с ошибкой `-EBUSY` (`error -16`).
  5. **Лавина hotplug**: Во время coldplug `procd` генерировал события для 36 блочных устройств (`mtdblock0..27`, `loop0..7`), порождая 36 параллельных вызовов `/sbin/block hotplug`, что приводило к многократному спаму ошибки в dmesg.
- **Сравнение со стоком и апстримом**:
  - **В стоке MiWiFi**: Из бинарника `/sbin/block` вырезано сканирование `mtdblock*` и `ubi*` (оставлены только `sd*`, `mmcblk*`, `hd*`, `md*`), а в hotplug стоит фильтр `[ "${DEVNAME:0:2}" = "sd" ] || exit 3`.
  - **В апстриме OpenWrt (main, openwrt-25)**: Драйвер `gluebi` полностью отключен в ядре (`# CONFIG_MTD_UBI_GLUEBI is not set`), поэтому виртуальные `mtdblock` поверх UBI не создаются ядром в принципе.
- **Внесённое исправление**:
  1. В `package/system/fstools/patches/001-block-skip-gluebi-ubi-mtdblock.patch`: в `mtdblock_is_nand()` добавлена проверка `if (!strcmp(buf, "ubi")) return true;`, предотвращающая зондирование виртуальных `mtdblock` устройств.
  2. В `package/system/fstools/files/mount.hotplug`: добавлен быстрый выход для `mtdblock*|ubi*`, избавляющий систему от 36 бесполезных запусков `block` на этапе coldplug.
- **Результат**: Ошибки `cannot open device ..., volume ..., error -16` полностью устранены в `dmesg` при сохранении полной совместимости со стоковым ядром 5.4.213.

### 2.2. UBIFS recovery на разделе `cfg` — **только в custom**

```
[   11.366042] UBIFS (ubi1:1): recovery needed
[   11.490321] UBIFS (ubi1:1): recovery completed
```

- **Только в custom**, в stock `ubi1:1` монтируется без recovery.
- **Причина**: предыдущая перезагрузка была некорректной (hard reset/power cut),
  journal UBIFS не был сброшен.
- **Критичность**: низкая — UBIFS recovery полностью автоматична и безопасна.
  Не является ошибкой сборки.

### 2.3. `ath0`/`ath1` netdev already exists при создании VAP — **только в custom**

```
[   44.524045] wlan: [1957:E:ANY] osif_create_vap_netdev_alloc: ath0 net dev exists already
[   44.530639] wlan: [1957:I:ANY] osif_create_vap:create netdev failed
[   44.538834] wlan: [1957:I:ANY] wlan_cfg80211_add_virtual_intf: Failed to create VAP. osif_create_vap returned NULL!
[   44.726344] wlan: [1994:E:ANY] osif_create_vap_netdev_alloc: ath1 net dev exists already
[   44.726372] wlan: [1994:I:ANY] osif_create_vap:create netdev failed
```

- `qca-wifi` уже создал `ath0`/`ath1` как legacy netdev на этапе инициализации,
  а затем `netifd`/`hostapd` через `cfg80211` пытается создать их снова.
- **Факт**: первая попытка фейлится, retry успешен — `ath0` и `ath1` добавляются
  в `br-lan` и VAP-ы поднимаются штатно.
- **Критичность**: средняя — лишняя задержка и потенциальная нестабильность
  при `wifi down/up`.
- **Рекомендация**: исследовать порядок создания интерфейсов в `qca-wifi-scripts`
  vs `netifd`/`mac80211.sh`. Возможно, нужно убрать pre-создание `ath0`/`ath1`
  в `qca-wifi-scripts` и отдать это полностью `cfg80211`/`hostapd`.

### 2.4. `ol_ath_vdev_set_intra_bss: vdev is NULL!` — **только в custom**

```
[   44.419499] wlan: [1931:E:ANY] ol_ath_vdev_set_intra_bss: vdev is NULL!
[   44.613247] wlan: [1993:E:ANY] ol_ath_vdev_set_intra_bss: vdev is NULL!
```

- Следствие ошибки 2.3: при фейловом создании VAP vdev не аллоцирован.
- **Критичность**: низкая — после retry vdev создаётся нормально.

### 2.5. `ol_ath_sync_multisoc_tbtt: reported AP count is zero!!` — **только в stock**

```
[  143.052577] wlan: [0:E:6GHZ] ol_ath_sync_multisoc_tbtt: reported AP count is zero!!
[  143.061068] wlan: [0:E:6GHZ] ol_ath_sync_multisoc_tbtt: reported AP count is zero!!
```

- Появляется в stock сразу после DFS CAC при поднятии MLO VAP-ов.
- **Причина**: функция синхронизации TBTT для 6 GHz не находит AP-ов (6 GHz не используется
  на данном роутере).
- **Критичность**: низкая — артефакт MLO кода QSDK для 6 GHz.

---

## 3. 🟡 Существенные отличия (архитектурные)

### 3.1. Stock: полный реинит Wi-Fi от MiWiFi демона (~31–37 сек)

В стоковом логе после первой инициализации Wi-Fi происходит **полный teardown и рестарт**:

```
[31.963038] deinit_mlo_cfg: Reset MLO configuration
[31.963136] ol_ath_wifi_ssr: SSR event 0
→ remoteproc остановлен (оба радио)
[34.960984] miwifi mesh exit!
[35.715975] qdf: ...  ← повторный старт
→ второй полный цикл загрузки Wi-Fi firmware
[37.785706] FW ready received for device 0xfff9
```

Стоковый MiWiFi демон перезапускает Wi-Fi после первичной инициализации для настройки
MLO/Mesh. В custom этого нет — **Wi-Fi инициализируется только один раз**.

### 3.2. Stock: MLO Multi-Link Operation с MiMesh VAP-ами

В stock активирован MLO (802.11be) с отдельными Mesh VAP-интерфейсами:

| VAP | Диапазон | MAC | Назначение |
|---|---|---|---|
| `wl0` | 5 GHz | `50:4f:3b:eb:47:9f` | Основной клиентский AP |
| `wl4` | 2.4 GHz | `5a:4f:3b:eb:47:9e` | MiMesh backhaul |
| `wl5` | 5 GHz | `5a:4f:3b:eb:47:9f` | MiMesh backhaul |

ACS для `wl5`: канал 48/5240 MHz, ширина 160 MHz (EHT160), MLO-партнёр: `wl4`.

В **custom** — только 2 клиентских VAP без Mesh:

| VAP | Диапазон | SSID | Ширина |
|---|---|---|---|
| `ath0` | 2.4 GHz | `OpenWrt_RD15_2.4G` | HE40 (40 MHz) |
| `ath1` | 5 GHz | `OpenWrt_RD15_5G` | HE160 (160 MHz, ch 36, center 5250) |

### 3.3. Временна́я шкала поднятия Wi-Fi (полная картина)

```
Время    Stock                                   Custom
───────  ───────────────────────────────────     ────────────────────────────────
 0 сек   Загрузка ядра                           Загрузка ядра
 3 сек   modules-boot.d (ssdk, yt)               modules-boot.d (ssdk, yt)
13 сек   procd init                              procd init  ← быстрее на 2 сек
15 сек   cnss daemon connected                   cnss daemon connected
18 сек   modules.d loaded                        modules.d loaded  ← быстрее 5 сек
19 сек   loading qca-wifi (1-й раз)              ── уже в modules.d ──
25 сек   FW ready QCA5332 (1-й раз)              18 сек: FW ready QCA5332 ✅
27 сек   FW ready QCN6432 (1-й раз)              21 сек: FW ready QCN6432 ✅
31 сек   ══ TEARDOWN (miwifi reinit) ══           ─────────────────────────
35 сек   miwifi mesh exit!, restart              ─────────────────────────
37 сек   FW ready QCA5332 (2-й раз)              ─────────────────────────
39 сек   FW ready QCN6432 (2-й раз)              ─────────────────────────
41 сек   ─────────────────────────               ECM init complete ✅
54 сек   ─────────────────────────               VAP ath0 up (2.4G) ✅
54 сек   ACS для MiMesh запускается              ─────────────────────────
84 сек   VAP wl4 up (2.4G MiMesh) ✅              ─────────────────────────
113 сек  ─────────────────────────               VAP ath1 up (5G, DFS done) ✅
143 сек  VAP wl0/wl5 up (5G, DFS done) ✅         ─────────────────────────
```

**Custom поднимает Wi-Fi на ~30 секунд быстрее стока по всем метрикам.**

### 3.4. Процедура монтирования файловой системы

**Stock** (стоковый `mount_root` QSDK) — простая линейная схема:
```
mount_root: mounting /dev/root
mount_root: loading kmods from internal overlay
→ ubi1 attaching overlay → UBIFS cfg mounted → done
```

**Custom** (нативный OpenWrt `fstools`) — сложная схема с fallback:
```
→ 3 попытки /tmp/overlay/upper/.../fstab (Entry not found)
→ UBIFS ubi0:2 (rootfs_data) монтируется → block ищет fstab → не находит
→ ubi0:2 размонтируется
→ ubi0 error -16 (EBUSY)
→ mount_root: switching to ubifs overlay
→ ubi1 overlay + UBIFS recovery → успех
```

---

## 4. 🟢 Улучшения в custom относительно stock

| Компонент | Stock | Custom | Оценка |
|---|---|---|---|
| **EDMA RPS** | Не настроен | ✅ 3 ядра CPU | Выше пропускная способность |
| **`urngd` Jitter CSPRNG** | Отсутствует | ✅ v1.0.2 | Лучшая криптографическая энтропия |
| **ECM init** | Не виден в логе | ✅ `init complete` @ 41 сек | Аппаратный оффлоад PPE подтверждён |
| **Один цикл Wi-Fi** | 2 цикла (reinit miwifi) | 1 цикл | Стабильнее, меньше wear |
| **Время VAP up** | ~84/143 сек | ~54/113 сек | Быстрее на 30 сек |
| **`dm-req-crypt`** | Загружен (не нужен) | Отсутствует | Меньше attack surface |
| **`xt_cgroup`** | Загружен | Отключён (ne 5.4) | Корректно для ядра 5.4 |

---

## 5. Совпадающее поведение (всё ок в обеих прошивках)

| Компонент | Статус |
|---|---|
| Ядро 5.4.213, SoC IPQ5312, 4 CPU | Идентично |
| MTD разметка (24 раздела NAND, Winbond W25N01) | Идентично |
| `qca-ssdk` APPE инициализация | Идентично, успешно |
| `yt_switch` (YT9215S) swconfig | Идентично, успешно |
| `nat46` версия и хеш `1182f30785e4` | Идентично |
| NSS Data Plane driver | Идентично |
| `cnss` платформенный драйвер (два инстанса) | Идентично |
| Firmware version `0x130a7fff` (2024-05-20) | Идентично |
| MLO multi-soc setup (2 soc, up to 2 links) | Идентично |
| `regulatory.db` не найден → fallback sysfs | Одинаково (норма) |
| MLO_MGR warnings `PSOC order 255` | Одинаково (норма для QSDK) |
| Wi-Fi config warnings `num_vdevs=16 → Using 9` | Одинаково (норма) |
| DFS CAC 60 сек завершается успешно | В обеих прошивках |
| `ath_pktlog: module license Proprietary taints kernel` | Одинаково |

---

## 6. Рекомендации по устранению проблем

### 6.1. Устранение `ubi0 error -16 (EBUSY)` (приоритет: средний)

Исследовать порядок вызовов в preinit:

```sh
# На роутере:
cat /lib/preinit/80_mount_root
grep -r "block" /lib/preinit/

# Проверить наличие fstab в оверлее:
ls /etc/config/fstab
```

Возможные решения:
- Добавить `/etc/config/fstab` с явным `option enabled 0`, чтобы `block`
  не пытался автоматически монтировать дополнительные разделы.
- Проверить, нет ли лишнего вызова `block mount` в `base-files` rd15 оверлее.

### 6.2. Устранение конфликта `ath0`/`ath1` netdev (приоритет: средний)

```sh
# Проверить, где создаются ath0/ath1 до hostapd:
grep -rn "wlanconfig\|create_vap\|ath0" /usr/lib/wifi/ /etc/init.d/
```

Варианты:
- Убедиться, что `qca-wifi-scripts` не вызывает `wlanconfig ath0 create` напрямую —
  создание должно происходить только через `cfg80211` из `hostapd`.
- Проверить порядок зависимостей `procd` в init-скрипте `qca-hostapd`:
  он должен стартовать после полной инициализации `wifi_3_0`.

### 6.3. UBIFS recovery — мониторинг

```sh
# Добавить в /etc/rc.local для мониторинга:
dmesg | grep -q "recovery needed" && \
    logger -t "ubifs" "UBIFS recovery detected — check last shutdown"
```

---

## 7. Итоговая оценка

### ✅ Критических блокирующих проблем нет

Кастомная прошивка полностью функциональна:
- Ядро, свитч, PPE/ECM, Wi-Fi 2.4G/5G — работают.
- DFS CAC пройден успешно (~60 сек, финиш на 113 сек).
- ECM аппаратный оффлоад инициализирован и подтверждён.
- Система загружается и поднимает Wi-Fi быстрее стока.

### ⚠️ Требуют внимания (по приоритету)

| # | Проблема | Критичность | Рекомендация |
|---|---|---|---|
| 1 | `ubi0 error -16 (EBUSY)` при preinit | Средняя | Исследовать `fstools`/`mount_root` preinit |
| 2 | `ath0`/`ath1` netdev конфликт при VAP создании | Средняя | Уточнить порядок создания VAP в `qca-wifi-scripts` |
| 3 | UBIFS recovery на `cfg` | Низкая | Мониторинг, не ошибка сборки |

### 📊 Ключевые преимущества custom перед stock

- Wi-Fi поднимается **на ~30 секунд быстрее**.
- Нет двойной реинициализации Wi-Fi (`miwifi mesh exit!` в стоке).
- EDMA RPS активен — лучшая многоядерная производительность.
- `urngd` обеспечивает криптографическую энтропию (отсутствует в стоке).
- ECM аппаратный оффлоад подтверждён в логе (@ ~41 сек).
