# Анализ патчей стокового ядра Xiaomi RD15 vs QSDK 12.4

**Дата**: 2026-09-01

## 1. Сводка результатов

| Параметр | Значение |
|---|---|
| Всего различий в конфиге | 9 |
| Содержательных патч-флагов | 5 |
| Регионов бинарных отличий | 701 |
| Затронутых функций ядра | 415 |
| Функций с реальным diff | 50 |

## 2. Патчи стокового ядра (по CONFIG-флагам)

### 2.1 Содержательные патчи

| Флаг | Описание |
|---|---|
| `CONFIG_BRIDGE_NETFILTER_DMZ_LOOPBACK` | Hairpin NAT через loopback для br_netfilter |
| `CONFIG_MIWIFI_CONNTRACK_ACCT_HOOK` | Хук учёта трафика в nf_conntrack |
| `CONFIG_MIWIFI_CONNTRACK_HOOK` | Хук событий nf_conntrack |
| `CONFIG_MIWIFI_NFNL_QUEUE_EXTENSION` | Расширение NFNETLINK_QUEUE |
| `CONFIG_MIWIFI_SKB_MARK` | Маркировка SKB (уже есть kmod-miwifi-skb-mark-vendor) |

### 2.2 Технические/автоматические флаги

- `CONFIG_CC_CAN_LINK=y`
- `CONFIG_EXFAT_FS=n`
- `CONFIG_NTFS3_FS=n`
- `CONFIG_RTC_DRV_IT8563WEX=n`

## 3. Изменённые функции ядра

Функции с наибольшим количеством изменённых байт (топ 20, сортировка по `changed_b`):

| # | Функция | vendor_addr | size | changed_b | real_diff |
|---|---|---|---|---|---|
| 1 | `_etext` | `0x407149a0` | 2012768 | 1122360 | ✅ |
| 2 | `cfi_read_pri` | `0x40452b0c` | 276 | 797983 | ✅ |
| 3 | `cfi_use_status_reg` | `0x40452c20` | 48 | 797983 | ✅ |
| 4 | `fixup_use_secsi` | `0x40452c50` | 20 | 797983 | ✅ |
| 5 | `fixup_use_erase_chip` | `0x40452c64` | 52 | 797983 | ✅ |
| 6 | `fixup_use_atmel_lock` | `0x40452c98` | 40 | 797983 | ✅ |
| 7 | `fixup_quirks` | `0x40452cc0` | 48 | 797983 | ✅ |
| 8 | `is_m29ew` | `0x40452cf0` | 76 | 797983 | ✅ |
| 9 | `do_read_secsi_onechip` | `0x40452d3c` | 632 | 797983 | ✅ |
| 10 | `fixup_use_fwh_lock` | `0x40452fb4` | 48 | 797983 | ✅ |
| 11 | `fixup_s29ns512p_sectors` | `0x40452fe4` | 60 | 797983 | ✅ |
| 12 | `fill_window` | `0x40384000` | 864 | 739851 | ✅ |
| 13 | `deflate_slow` | `0x40384360` | 968 | 739851 | ✅ |
| 14 | `deflate_fast` | `0x40384728` | 752 | 739851 | ✅ |
| 15 | `deflate_stored` | `0x40384a18` | 420 | 739851 | ✅ |
| 16 | `zlib_deflateReset` | `0x40384bbc` | 284 | 739851 | ✅ |
| 17 | `zlib_deflateInit2` | `0x40384cd8` | 332 | 739851 | ✅ |
| 18 | `zlib_deflate` | `0x40384e24` | 724 | 739851 | ✅ |
| 19 | `zlib_deflateEnd` | `0x403850f8` | 92 | 739851 | ✅ |
| 20 | `zlib_deflate_workspacesize` | `0x40385154` | 76 | 739851 | ✅ |

## 4. Следующие шаги

1. **Получить исходники патчей** — искать в GPL-архиве Xiaomi BE3600 или в QSDK QCA open-source репозиториях.
2. **Написать 4-5 патчей** в `target/linux/ipq53xx/rd15/patches-5.4/` для каждого `CONFIG_MIWIFI_*` и `CONFIG_BRIDGE_NETFILTER_DMZ_LOOPBACK`.
3. **Проверить** через повторный XOR-diff после сборки — diff должен сократиться до нуля.
4. **Подробный дизассемблер** в `vendor_scripts/kernel_diff/disasm_diff/` — по файлу на функцию.
