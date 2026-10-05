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

## 3. Решение проблемы и реализация

В ходе анализа стоковой прошивки Xiaomi (`qcawificfg80211.sh`, строки 4843–4850) и тестов на реальном устройстве было установлено:

1. **Команда драйвера Qualcomm**:
   Драйвер `wifi_3_0.ko` является self-managed и принимает смену кода страны для физических интерфейсов (`wifi0`, `wifi1`) через утилиту `cfg80211tool`:
   ```bash
   cfg80211tool wifi0 setCountry CN
   cfg80211tool wifi1 setCountry CN
   ```
   После выполнения команды в ядре регистрируется:
   ```text
   phy#1 (self-managed)
   country CN: DFS-UNSET
           (2402 - 2482 @ 40), (N/A, 30), (N/A), AUTO-BW
   ```
   Частоты **2467 МГц (канал 12)** и **2472 МГц (канал 13)** мгновенно появляются в списке разрешенных каналов (`iw phy phy1 info`), а максимальная мощность передатчика возрастает до 33 dBm.

2. **Скрипт платформы `mac80211.sh`**:
   В функцию `drv_mac80211_setup()` добавлено чтение параметра `country` из UCI `/etc/config/wireless` (по умолчанию `CN`) и вызов:
   ```bash
   cfg80211tool "$wlandev" setCountry "$country"
   ```
   до инициализации VAP и демона `hostapd`.

3. **Скрипт `hostapd_config.sh`**:
   В конфиг `hostapd` передаются:
   ```text
   country_code=CN
   ieee80211d=1
   ```
   что полностью соответствует стоковой конфигурации Xiaomi и стандартам 802.11d Regulatory Information Element.

