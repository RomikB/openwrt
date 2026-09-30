# Исследование: Регуляторный домен и каналы 12–13 (2.4 ГГц)

## 1. Проблема

При сканировании диапазона 2.4 ГГц (`iwinfo radio0 scan` / LuCI) маршрутизатор Xiaomi BE3600 (RD15) не обнаруживает точку доступа, работающую на **канале 13 (2472 МГц)** (например, MikroTik hAP ax3).

## 2. Диагностика и первопричина

### 2.1. Список частот и домен в ядре
Команда `iw phy phy1 info` и `iw reg get` показали:
```text
phy#1 (self-managed)
country US: DFS-FCC
        (2402 - 2472 @ 40), (6, 30), (N/A), AUTO-BW
```
А список поддерживаемых частот `phy1`:
```text
Frequencies:
    * 2412 MHz [1]
    * 2417 MHz [2]
    ...
    * 2462 MHz [11]
```
Каналы 12 (2467 МГц) и 13 (2472 МГц) **полностью отсутствуют** в таблице разрешенных частот радиомодуля IPQ5332 (`wifi0` / `phy1`). Команда `wlanconfig ath0 list chan` также возвращает только каналы 1–11.

### 2.2. Почему включен домен `US` вместо `CN` / `RU`
В прошивке Qualcomm QSDK Direct Connect (`wifi_3_0.ko` / `IPQ5332/WIFI_FW`):
1. Радиомодули работают в режиме **self-managed regulatory domain**.
2. В строках прошивки Qualcomm (`Data.msc`):
   ```text
   REGDB: get valid country_code/domain_code from BDF
   REGDB: neither OTP nor BDF valid value for country_code/domain_code
   Invalid country code. Setting to "US".
   ```
3. Если калибровка BDF или OTP не содержит валидный код страны (или код страны не распознан встроенной базой `regdb.bin`), драйвер принудительно активирует безопасный дефолт — **`US` (FCC)**.
4. В домене США (FCC) каналы 12 и 13 законодательно запрещены, поэтому драйвер аппаратно исключает частоты 2467 и 2472 МГц из планов сканирования и работы передатчика.

## 3. Направления для будущего решения

1. **Вендорные команды регуляторного домена**:
   В драйвере `wifi_3_0.ko` обнаружены WMI-команды:
   * `WMI_SET_CURRENT_COUNTRY_CMDID` (`send_user_country_code_cmd_tlv`).
   * В `qcacommands_ol_radio.xml`: VendorCmd `setCountry` (ID 74) и `getCountry` (ID 75).
   * Необходимо изучить возможность передачи кода страны `RU` (или `CN`) непосредственно в чип при инициализации драйвера (например, через параметры инициализации или утилиту `wifitool`).

2. **Взаимодействие `hostapd` и `regdb`**:
   Проверить, почему `country_code=CN` в `hostapd-ath0.conf` не переопределяет дефолтный `US` в firmware WMI при старте VAP, и требуется ли флаг `country_ie` / `ieee80211d` со стороны Qualcomm hostapd.
