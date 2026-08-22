# Техническая документация: Стек Wi-Fi 6 / 7 на Xiaomi Router BE3600 (RD15)

Дополнительный документ к [VENDOR_USERLAND_REPLACEMENT.md](VENDOR_USERLAND_REPLACEMENT.md), описывающий архитектуру, специфичные компоненты и механизмы интеграции беспроводного стека Qualcomm Direct Connect в OpenWrt 24.

---

## 1. Архитектура радиомодулей и аппаратная часть

| Радиоинтерфейс | Чипсет / Контроллер | Шина подключения | VAP интерфейс | PHY имя | Диапазон и полоса |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **2.4 GHz Radio** | Qualcomm IPQ5312 On-SoC | AHB (встроен в SoC) | `ath0` | `phy1` | 2.4 GHz, 802.11ax (HE20/HE40), 2x2 MIMO |
| **5.0 GHz Radio** | Qualcomm QCN6432 PCIe Radio | PCIe Gen3 | `ath1` | `phy2` | 5.0 GHz, 802.11ax/be (HE160/EHT160), 2x2 MIMO |
| **MLD Radio** | Multi-Link Device (Wi-Fi 7) | Внутренняя шина | `mld-wifi0` | `phy0` | Wi-Fi 7 MLO (агрегация 2.4G + 5G) |

---

## 2. Стек компонентов Wi-Fi

```
┌────────────────────────────────────────────────────────────────────────┐
│                        LuCI Web UI / UCI CLI                           │
│  /etc/config/wireless  ───►  /lib/wifi/hostapd_config.sh (Генератор)   │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│               Сетевой менеджер Netifd & Утилита /sbin/wifi             │
│  /lib/netifd/wireless/mac80211.sh  ───►  /sbin/wifi (CLI & Mutex)      │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   Аутентификатор Qualcomm hostapd                      │
│  /usr/sbin/hostapd (изолирован через ld-vendor / OpenSSL 1.1)          │
│  Сокеты управления: /var/run/hostapd/ath0, /var/run/hostapd/ath1       │
│  Мониторинг LuCI: libiwinfo (STA-FIRST / STA-NEXT fallback patch)      │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│               Qualcomm Direct Connect Драйверы (Ядро 5.4)              │
│  • ipq_cnss2.ko + cnssdaemon ─── Инициализация PCIe шины QCN6432       │
│  • mem_manager.ko, qdf.ko, umac.ko, qca_ol.ko, wifi_3_0.ko, cfg80211  │
│  • ecm-wifi-plugin.ko ───────── Аппаратный оффлоад потоков (PPE/ECM)   │
│  • 0:ART / 0:0:ALL_MISC ─────── Заводские калибровки BDF (caldata.bin) │
└────────────────────────────────────────────────────────────────────────┘
```

### Состав стека:
1. **Подсистема PCIe и инициализация радиомодуля QCN6432**:
   * `ipq_cnss2.ko` — платформенный драйвер шины PCIe для управления питанием и сбросом радиочипа.
   * `cnssdaemon` (`/usr/sbin/cnssdaemon -n -s`) — сервис инициализации чипа и загрузки микрокода.
   * Калибровки и BDF-блобы: монтирование заводских данных `caldata.bin`, `caldata_1.b0060`, `ftm.conf` из разделов `0:ART` и `0:0:ALL_MISC` в `/ini` и `/lib/firmware/qcn6432`.
2. **Драйверный уровень Qualcomm Direct Connect**:
   * `mem_manager.ko` — когерентная DMA-память дескрипторов.
   * `qdf.ko` — слой абстракции ОС Qualcomm Driver Framework.
   * `umac.ko` — Upper MAC уровень (управление точками доступа, протоколом 802.11 и Rate Control).
   * `qca_ol.ko` — транспортный уровень обмена с микрокодом по шинам AHB/PCIe.
   * `wifi_3_0.ko` — аппаратный драйвер радиомодулей Wi-Fi 3.0.
   * `cfg80211.ko` — подсистема беспроводной конфигурации ядра Linux.
3. **Аппаратное ускорение Wi-Fi трафика (Qualcomm PPE / NSS ECM)**:
   * `ecm-wifi-plugin.ko` — модуль интеграции Qualcomm ECM с радиодрайвером Direct Connect. Реализует кремниевую классификацию потоков FSE (Flow Search Engine) и аппаратную приоритезацию QoS MSCS.
4. **Аутентификация и управление точками доступа**:
   * Qualcomm `hostapd` и `wpa_supplicant` (`/usr/sbin/hostapd`, `/usr/sbin/hostapd_cli`).
   * Изоляция окружения: слинкованы с `ld-vendor.so.1` и `v_lssl.so.1.1` / `v_lcrypto.so.1.1` (OpenSSL 1.1).

---

## 3. Специфичные патчи беспроводного стека

### 1. Системный патч `libiwinfo` ([200-hostapd-assoclist-fallback.patch](package/network/utils/iwinfo/patches/200-hostapd-assoclist-fallback.patch))
* **Причина**: Драйвер Qualcomm Direct Connect не возвращает список станций через стандартный `nl80211` dump ядра (`iw dev ath0 station dump`), из-за чего в LuCI Web UI (*Network → Wireless*) не отображались подключенные клиенты.
* **Реализованный механизм**:
  1. В `libiwinfo` добавлен fallback на прямой опрос управляющих UNIX-сокетов hostapd (`/var/run/hostapd/ath0` и `/var/run/hostapd/ath1`).
  2. Реализована итерация по станциям через специфичный вендорный протокол `STA-FIRST` / `STA-NEXT`.
  3. Реализован парсинг расширенных метрик: MAC-адрес, уровень сигнала RSSI (`signal`), уровень шума (`noise`), время активности (`inactive_time`), битрейты TX/RX (HE/EHT rates, MCS, NSS, полоса 20/40/80/160 MHz), флаги авторизации.
  4. Защита сокета при DFS CAC: предотвращено удаление управляющего сокета во время 60-секундного сканирования радаров на частоте 5 ГГц (каналы 52–64).

### 2. Модификации пакетов вендорного фида ([vendor_scripts/patch_package.py](vendor_scripts/patch_package.py))
* **Пакет `qca-hostap` (`files/etc/init.d/qca-hostapd`)**:
  * Генерация сервиса формата `procd` / `rc.common` (`START=21`, `STOP=87`).
  * Реализация функции `setup_vaps`: динамическое определение `phy1`/`phy2` через sysfs `wifi0`/`wifi1`, создание виртуальных AP-интерфейсов `ath0` и `ath1` (`iw phy <phy> interface add <ath> type __ap`), добавление в сетевой мост `br-lan` и перевод в `up`.
  * Отключение фильтрации трафика моста через `sysctl` (`net.bridge.bridge-nf-call-iptables=0`, `ip6tables=0`, `arptables=0`) во избежание сброса сетевых фреймов.
  * Интеграция вызова генератора `/lib/wifi/hostapd_config.sh all` и запуск инстансов hostapd с файлом энтропии `/var/run/entropy.bin`, PID-файлами и сокетами `/var/run/hostapd/ath*`.
* **Пакет `kmod-qca-wifi-lowmem-profile`**:
  * Преобразование скрипта `/etc/init.d/load_cnss2` в сервис под супервизором `procd` (`START=11`, `STOP=89`, `USE_PROCD=1`, `respawn`) для управления демоном `/usr/bin/cnssdaemon -n -s` и загрузки модуля `ipq_cnss2.ko` с аргументами `cnss2` из `/proc/cmdline`.
  * Отключение автозапуска устаревших тестовых утилит `qcawifi-config-cmd` и `diag_socket_app` (очистка `START=`).

---

## 4. Интеграция с OpenWrt 24 (UCI, Netifd, LuCI)

### 1. Конфигурация UCI Wireless (`/etc/config/wireless`)
* `radio0` (2.4 GHz): тип `mac80211`, каналы 1–13 (`auto`/`6`), ширина полосы `HE40`, регуляторный домен `CN`.
* `radio1` (5.0 GHz): тип `mac80211`, каналы 36–64 (`auto`/`44`), ширина полосы `HE160`, регуляторный домен `CN`.
* Интерфейсы `default_radio0` (`ath0`) и `default_radio1` (`ath1`): привязка к мосту `lan`, режим `ap`, SSID `OpenWrt_RD15_2.4G` и `OpenWrt_RD15_5G`, шифрование `psk2+ccmp` / `sae`.

### 2. Динамический транслятор `/lib/wifi/hostapd_config.sh`
Преобразует параметры UCI в файлы конфигурации `/var/run/hostapd-ath0.conf` и `/var/run/hostapd-ath1.conf`:
* Расчет центральных частот сегментов для 160 МГц (`vht_oper_centr_freq_seg0_idx`, `he_oper_centr_freq_seg0_idx`, `eht_oper_centr_freq_seg0_idx`).
* Включение стандартов 802.11ax (`ieee80211ax=1`, `he_oper_chwidth=2`) и 802.11be (`ieee80211be=1`, `eht_oper_chwidth=2`).
* Формирование параметров WPA2-PSK / WPA3-SAE / Transition Mode с PMF (`ieee80211w=1` / `ieee80211w=2`).
* Отключение `ieee80211d` для исключения конфликтов регуляторных доменов с аппаратными калибровками в `0:ART`.

### 3. Интеграция с Netifd (`/lib/netifd/wireless/mac80211.sh`)
* Обработка событий `setup` и `teardown` от `netifd`.
* Создание виртуальных интерфейсов `ath0` и `ath1` через `iw` (`iw phy phy1 interface add ath0 type __ap`).
* Привязка к мосту `br-lan` и перевод интерфейсов в UP.
* Поддержка независимого перезапуска радиомодулей без обрыва проводных соединений моста `br-lan`.

### 4. Системная утилита `/sbin/wifi`
Стандартный CLI-интерфейс OpenWrt с файловой блокировкой `/var/run/wifi.lock`:
* `/sbin/wifi up [radio]` — включение и инициализация радиомодулей.
* `/sbin/wifi down [radio]` — корректная остановка hostapd и удаление VAP.
* `/sbin/wifi reload [radio]` — бесшовное применение изменений конфигурации.
* `/sbin/wifi status` — вывод JSON-статуса радиомодулей и интерфейсов.

---

## 5. Последовательность инициализации и автозапуск служб

Запуск служб осуществляется под супервизором процессов `procd`:

```text
1. S11load_cnss2     -> Инициализация шины PCIe и запуск cnssdaemon
2. S12qca-wifi       -> Загрузка стека модулей ядра Direct Connect и ecm-wifi-plugin
3. S18qca-nss-dp     -> Инициализация проводных интерфейсов NSS (eth0, eth1)
4. S19qca-nss-ecm    -> Старт аппаратного оффлоада Qualcomm ECM / PPE
5. S20network        -> Сетевой стек netifd создает мост br-lan (192.168.1.1)
6. S21qca-hostapd    -> Создание ath0/ath1, привязка к br-lan, генерация конфигов и запуск hostapd
```

---

## 6. Команды управления и мониторинга

### 1. Проверка состояния беспроводного стека:
```sh
/sbin/wifi status
```

### 2. Информация об интерфейсах и активных станциях (libiwinfo):
```sh
iwinfo ath0 info
iwinfo ath1 info
iwinfo ath0 assoclist
iwinfo ath1 assoclist
```

### 3. Прямое управление через hostapd_cli:
```sh
hostapd_cli -p /var/run/hostapd -i ath0 status
hostapd_cli -p /var/run/hostapd -i ath1 status
hostapd_cli -p /var/run/hostapd -i ath0 all_sta
hostapd_cli -p /var/run/hostapd -i ath1 all_sta
```
