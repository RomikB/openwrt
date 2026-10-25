# MiWiFi RD15: формат файла прошивки (HDR1 / BABE)

> Образцы: `miwifi_rd15_firmware_89297_1.0.81.bin`, `miwifi_rd15_firmware_23a4f_1.0.68.bin`  
> Инструменты: `vendor_scripts/mkxqimage_info.py` (разбор/извлечение)

---

## 1. Формат бинарного файла прошивки (HDR1 / BABE)

Файл прошивки — **проприетарный контейнер Xiaomi**, содержащий сегментированный образ.  
Инструмент для работы с форматом: `/bin/mkxqimage` (на роутере) / `vendor_scripts/mkxqimage_info.py`.

### 1.1 Общая структура файла

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ [0x000000 .. hdr_len-1]        HDR1 Header           (144 байта)            │
├─────────────────────────────────────────────────────────────────────────────┤
│ Повторяется для каждого сегмента N=0,1,...:                                 │
│   [offset]       BABE Descriptor N  (48 байт)                               │
│   [offset+0x30]  Payload N          (desc.length байт, выровнено до 4 байт)│
├─────────────────────────────────────────────────────────────────────────────┤
│ [total_size .. EOF]            Signature Trailer     (272 байта)            │
└─────────────────────────────────────────────────────────────────────────────┘
  total_size (из HDR1 +0x04) = полный размер файла − 272
```

### 1.2 HDR1 Главный заголовок (144 байта, смещение 0x0000)

```
Offset  Size  Field           Пример (1.0.81)    Описание
──────────────────────────────────────────────────────────────────────────────
+0x00    4    magic           48 44 52 31        ASCII "HDR1" — идентификатор формата
+0x04    4    total_size      F0 02 B8 01 (LE)   Размер файла без трейлера (= file_size − 272)
+0x08    4    checksum        C5 E5 AB 22 (LE)   MD5-based хеш payload (первые 4 байта MD5)
+0x0C    4    flags           00 00 55 00 (LE)   Флаги версии/алгоритма (0x00550000)
+0x10    4    hdr_len         90 00 00 00 (LE)   Длина этого заголовка (всегда 0x90 = 144)
+0x14    4    sign_ext_len    C0 02 00 00 (LE)   Смещение от 0, где заканчивается metadata
                                                  (= HDR1 + seg0_desc + seg0_payload)
+0x18   120   (zeros)         00 00 ...          Зарезервировано, нули
```

> `sign_ext_len = 0x2C0` означает: первые 0x2C0 байт (HDR1 + дескриптор + метаданные
> первого сегмента) отделены от основного payload. Начиная с 0x2C0 идёт
> дескриптор `root.ubi` и сам UBI-образ.

### 1.3 BABE Дескриптор сегмента (48 байт)

```
Offset  Size  Field           Пример (seg0)      Описание
──────────────────────────────────────────────────────────────────────────────
+0x00    2    magic           BE BA              0xBABE — идентификатор дескриптора
+0x02    2    rsvd0           00 00              Зарезервировано
+0x04    4    flash_addr      FF FF FF FF (LE)   Адрес во flash (0xFFFFFFFF = автовыбор)
+0x08    4    length          FF 01 00 00 (LE)   Длина полезной нагрузки в байтах
+0x0C    2    partition       FF FF              Номер раздела (0xFFFF = автовыбор)
+0x0E    2    le_magic        00 00              Доп. magic (всегда 0)
+0x10   32    filename        "xiaoqiang_ver...\0" Имя сегмента, нуль-терминированная строка
```

**Payload** каждого сегмента следует сразу за его дескриптором.  
Если длина payload не кратна 4, добавляется padding нулями до следующей 4-байтовой границы,  
после чего идёт дескриптор следующего сегмента.

### 1.4 Сегменты в прошивке 1.0.81

| N | Имя (`filename`) | flash_addr | length | Смещение payload | Назначение |
|---|------------------|------------|--------|-----------------|------------|
| 0 | `xiaoqiang_version` | 0xFFFFFFFF | 511 | 0x0000C0 | UCI-метаданные версии, **не прошивается** |
| 1 | `root.ubi` | 0xFFFFFFFF | 28 835 840 | 0x0002F0 | UBI-образ: ядро + SquashFS rootfs |

> Дескриптор seg0 находится на 0x0090, дескриптор seg1 — на 0x02C0 (= `sign_ext_len`).

### 1.5 Содержимое seg0: `xiaoqiang_version` (511 байт UCI-текст)

```
config core 'version'
    option ROM '1.0.81'
    option CHANNEL 'release'
    option HARDWARE 'RD15'
    option LINUX '5.4'
    option UBOOT '1.0.2'
    option BUILDTIME '...'
    option BUILDTS '1712556249'
    option GTAG 'eb0e248cd25c0'
```

### 1.6 Signature Trailer (272 байта, в конце файла)

```
Offset  Size  Field        Сырые байты (1.0.81)  Описание
──────────────────────────────────────────────────────────────────────────
+0x00    2    rsa_sig_len  00 01 (LE)             Длина RSA-подписи в байтах: 0x0100 = 256
                                                  (= размер ключа RSA-2048 в байтах)
+0x02    2    rsvd         00 00                  Зарезервировано
+0x04   12    padding      00 00 ... 00            Нули
+0x10  256    rsa_sig      7D 64 07 10 ...        RSA-2048 PKCS#1 v1.5 подпись
                                                  (SHA-1 от payload, ключ public.pem)
```

> **Поле `rsa_sig_len` (байты 0–1):** значение `0x0100` в little-endian = **256** — это
> не «версия формата», а длина следующего блока RSA-подписи в байтах (256 байт = 2048 бит).
> Поле идентично в прошивках 1.0.68 и 1.0.81, что подтверждает его роль константного
> размера ключа. Код `mkxqimage` читает это поле для определения границ RSA-буфера
> перед вызовом `EVP_VerifyFinal`.

**Итоговая байтовая карта прошивки 1.0.81:**

```
0x0000000  .. 0x000008F   HDR1 header               (  144 bytes)
0x0000090  .. 0x00000BF   BABE descriptor 0          (   48 bytes)
0x00000C0  .. 0x00002BF   xiaoqiang_version payload  (  512 bytes, 511 content + 1 pad)
0x00002C0  .. 0x00002EF   BABE descriptor 1           (   48 bytes)
0x00002F0  .. 0x1B802EF   root.ubi payload           (27.5 MiB)
0x1B802F0  .. 0x1B803FF   Signature trailer           (  272 bytes)
```

---

### 1.7 Цепочка валидации файла перед прошиванием (stock)

Полный путь выполнения от инициации обновления до старта записи во flash:

```
WebUI / SSH
  └─ /bin/flash.sh <firmware.bin> [restore_defaults] [no_reboot]
```

#### Шаг 1 — Предварительные системные проверки (`upgrade_param_check`)

```sh
# flash.sh: upgrade_param_check()
nvram get flag_ota_reboot        # ABORT если == "1" (обновление уже идёт)
cat /usr/share/xiaoqiang/xiaoqiang_version  # лог текущей версии
cat /proc/xiaoqiang/model        # лог модели устройства
echo 3 > /proc/sys/vm/drop_caches          # освобождение кеша
```

#### Шаг 2 — Проверка образа (`upgrade_verify_image`)

```sh
# flash.sh: upgrade_verify_image()
mkxqimage -v <firmware.bin>
# exit code != 0  →  "Check Failed!!!" + выход
```

Внутри `mkxqimage -v` выполняется:

| Порядок | Проверка | При провале |
|---------|----------|-------------|
| 1 | `fread(buf, 1, 0x90, file) == 0x90` — читает ровно 144 байта | exit -5 |
| 2 | `buf[0..3] == "HDR1"` — magic заголовка | exit -22 |
| 3 | `model == /proc/xiaoqiang/model` — совпадение модели | exit -22 |
| 4 | `sign_ext_len` совпадает с вычисленным размером метаданных | exit -22 |
| 5 | `sign_ext_len >= computed_offset` — граница payload валидна | exit -22 |
| 6 | Каждый BABE: `magic == 0xBABE` — magic дескриптора | exit -22 |
| 7 | MD5 checksum поля `+0x08` совпадает с вычисленным | exit -22 |
| 8 | `EVP_VerifyFinal()` — RSA-2048 подпись (**результат игнорируется!** см. VULN-1) | — |

#### Шаг 3 — Подготовка рабочей директории

```sh
# flash.sh: upgrade_prepare_dir()
mount -o remount,size=100% /tmp
rm -rf /tmp/system_upgrade
mkdir -p /tmp/system_upgrade
mv <firmware.bin> /tmp/system_upgrade/   # или cp если файл не в /tmp
```

#### Шаг 4 — Извлечение метаданных версии

```sh
# flash.sh (после верификации)
mkxqimage -x "$filename" -f xiaoqiang_version   # извлекает seg0 в текущую директорию
uci -q -c /tmp/system_upgrade get xiaoqiang_version.version.ROM  # читает ROM-версию
```

#### Шаг 5 — Остановка сервисов (`board_prepare_upgrade`)

```sh
# boardupgrade.sh: board_prepare_upgrade()
ifdown wan
# killall pppd (timeout 5 сек)
for i in /etc/rc.d/K*; do $i shutdown; done  # кроме reboot-wdt, umount, network, dnsmasq
sync
echo 3 > /proc/sys/vm/drop_caches
```

#### Шаг 6 — Последовательная запись разделов (`board_system_upgrade`)

```sh
# boardupgrade.sh: board_system_upgrade()
# Прошиваются секции по порядку: sbl1 tz devcfg cdt uboot firmware

# Для MTD-разделов (sbl1, tz, devcfg, cdt, uboot):
mkxqimage -c $package -f <segment_name>    # проверяет наличие сегмента
mkxqimage -x $package -f <segment_name> -n | mtd write - /dev/mtdN  # pipe-запись

# Для firmware (root.ubi) — определяет target-раздел через nvram:
nvram get flag_boot_rootfs  # 0 = rootfs, 1 = rootfs_1
# pipe в ubiformat:
mkxqimage -x $package -f root.ubi -n | ubiformat /dev/mtdN -f - -s 2048 -O 2048 -y

# После всех секций — обновление bootconfig (если нужно):
# cat /proc/boot_info/getbinary_bootconfig > /tmp/bootconfig.bin
# dd ... | mtd write - /dev/mtdX
```

#### Итоговая схема:

```
flash.sh <fw.bin>
  ├─ [SYS]   nvram get flag_ota_reboot         → abort if "1"
  ├─ [VERIFY] mkxqimage -v <fw.bin>             → abort if exit != 0
  ├─ [PREP]   mkdir /tmp/system_upgrade; mv fw  
  ├─ [META]   mkxqimage -x fw -f xiaoqiang_version  → /tmp/system_upgrade/
  ├─ [STOP]   K* shutdown scripts
  └─ [FLASH]  for sec in sbl1 tz devcfg cdt uboot firmware:
                ├─ mkxqimage -c fw -f <sec>     → segment exists check
                └─ mkxqimage -x fw -f <sec> -n | mtd write - /dev/mtdN
                                                  (firmware → ubiformat)
```

> [!NOTE]
> Команды `mkxqimage` используют флаги: `-v` (verify), `-x` (extract),
> `-c` (check/size), `-f <name>` (имя сегмента), `-n` (no-write, pipe mode).
> Все вызовы работают с именем сегмента из поля `filename` BABE-дескриптора.

---
