# Анализ миграции сетевого стека и Wi-Fi на OpenWrt 25: Xiaomi Router BE3600 (RD15/RD16)

Документ описывает технические результаты расследования, аппаратную диагностику и архитектурные изменения сетевого и беспроводного стеков при переходе с **OpenWrt 24 (24.10 / master)** на **OpenWrt 25 (25.12-SNAPSHOT)** для маршрутизаторов серии **Xiaomi Router BE3600 (RD15 / RD16)** на гибридной платформе **Qualcomm IPQ5332 (Linux 5.4.213 QSDK 12.5)**.

---

## 1. Контекст проблемы и симптомы первичного старта

После первой прошивки релиза на базе OpenWrt 25.12 возникли следующие симптомы:
1. Маршрутизатор успешно завершил загрузку ядра, светодиод переключился в синий цвет (`blue:status`).
2. **Проводная сеть (LAN/WAN)** не поднялась: индикаторов линка нет, IP-адреса по DHCP на портах коммутатора не выдавались, интерфейсы находились в состоянии `DOWN`.
3. **Беспроводная сеть (Wi-Fi)** не появилась в эфире (SSID отсутствовали на обоих диапазонах 2.4G и 5G).

Для локализации проблемы был задействован автономный диагностический стенд **`rd15-hwdiag`**, сохранивший детальный дамп ядра, шин MDIO/PCIe, конфигурации `ubus` и системных логов в энергонезависимый раздел `/data/`.

---

## 2. Расследование и исправление проводной сети (LAN / WAN)

### 2.1. Анализ дампов оборудования
По логам `dmesg.log` и `mdio_devices_list.txt` аппаратная инициализация прошла штатно:
* Коммутатор **Motorcomm YT9215S** успешно определен на шине MDIO (`chipid: 0x90020002`), поднят транк к CPU 2.5 Gbps (`Link is Up - 2.5Gbps/Full`).
* Зарегистрировано дерево DSA (`DSA: tree 0 setup`), созданы сетевые интерфейсы портов: `port1`, `port2`, `port3`, а интерфейс `eth1` (2.5G PHY) переименован в `port4`.

Однако в дампе `ubus call network.interface dump` (`ubus_network.json`) сетевые интерфейсы находились в аварийном состоянии:
```json
{
  "interface": "lan",
  "up": false,
  "device": "br-lan",
  "errors": [ { "subsystem": "interface", "code": "NO_DEVICE" } ]
},
{
  "interface": "wan",
  "up": false,
  "device": "eth1",
  "errors": [ { "subsystem": "interface", "code": "NO_DEVICE" } ]
}
```

### 2.2. Архитектурное изменение OpenWrt 25 (Preinit `82_config_generate`)
В OpenWrt 25 генерация первичного файла конфигурации платы `/etc/board.json` и настроек `/etc/config/network` была перенесена в этап `preinit` (коммит `2a8b27fab9c8e8bf67ff8a0c341b06a8c68453cf`, скрипт `package/base-files/files/lib/preinit/82_config_generate`):
```sh
do_config_generate() {
    [ -f /etc/board.json ] || {
        echo "- generating board file -"
        /bin/board_detect /tmp/board.json
        mv /tmp/board.json /etc/board.json
        /bin/config_generate > /dev/null
    }
}
```
Скрипт `/bin/board_detect` вызывается с явным параметром `$1` = `/tmp/board.json`, устанавливая внутреннюю переменную `CFG=/tmp/board.json`.

### 2.3. Корневая причина сбоя (Хардкод в `02_network`)
В скрипте сабтаргета `target/linux/ipq53xx/ipq53xx_32/base-files/etc/board.d/02_network` присутствовала строка:
```sh
CFG=/etc/board.json   # Жесткий хардкод
```
В результате возникла скрытая коллизия:
1. `02_network` перезаписывал переменную `CFG` и сохранял корректные DSA-порты (`port2 port3 port4`, `port1`) напрямую в `/etc/board.json`.
2. Файл `/tmp/board.json` оставался **несозданным** (нулевого размера).
3. Следующий по порядку скрипт `/etc/board.d/99-default_network` читал `$CFG` (который в родительском процессе оставался `/tmp/board.json`), видел отсутствие объекта `network`, считал архитектуру платы неопознанной и генерировал fallback:
   * `lan` $\to$ `eth0`
   * `wan` $\to$ `eth1`
   и сбрасывал это в `/tmp/board.json`.
4. Скрипт `82_config_generate` выполнял `mv /tmp/board.json /etc/board.json`, **безвозвратно затирая правильный конфиг `02_network` generic-заглушкой**.
5. `/bin/config_generate` формировал сетевую конфигурацию, в которой WAN указывал на несуществующий `eth1` (переименованный в `port4`), а мост `br-lan` создавался без единого пользовательского порта коммутатора. В результате `netifd` переводил обе сети в статус `NO_DEVICE`.

### 2.4. Примененное исправление
В коммите `52df61a4bb` из `02_network` была удалена строка хардкода `CFG=/etc/board.json`. Теперь скрипт динамически использует значение `$CFG`, переданное вызывающей подсистемой. При первом старте конфигурация атомарно формируется в `/tmp/board.json`, и проводная сеть маршрутизатора поднимается на 100%.

---

## 3. Расследование и анализ неработоспособности Wi-Fi

После восстановления проводного сегмента роутер стал доступен по SSH (`192.168.11.24`), что позволило провести интерактивную диагностику беспроводного стека на работающей системе.

### 3.1. Статус драйвера и радиомодулей
* Модули ядра Qualcomm QSDK (`wifi_3_0.ko`, `umac.ko`, `qca_ol.ko`, `qdf.ko`) загружены штатно.
* Демон `cnssdaemon` успешно подключен к IPC QMI сокету ядра.
* Удаленные сопроцессоры (`d100000.remoteproc`) запущены, образы микрокода `q6_fw0.mdt`, `q6_fw1.mdt`, `iu_fw.mdt` загружены в DDR.
* Команда `iw dev` отображает оба физических радиомодуля:
  * `phy#1` $\leftrightarrow$ `wifi0` (On-Chip IPQ5312, 2.4 GHz, канал 1).
  * `phy#2` $\leftrightarrow$ `wifi1` (PCIe QCN6432, 5 GHz, канал 36).
* Конфигурационный файл `/etc/config/wireless` сгенерирован штатно.

### 3.2. Симптом в пространстве пользователя (Userland Netifd)
В системном журнале `logread` зафиксировано критическое предупреждение:
```text
daemon.warn netifd: Wireless module not found
```
Команда `ubus list` показала полное отсутствие пространства имен `network.wireless`.
Попытка ручного запуска через `/sbin/wifi up` завершалась ошибкой:
```text
Command failed: Not found (ubus call network.wireless up)
```
Ни один процесс `hostapd` в системе запущен не был.

### 3.3. Причина: Переход `netifd` на Ucode и пакет `wifi-scripts`
1. **Рефакторинг `netifd` в OpenWrt 25** (коммит `cbb83a18`):
   В OpenWrt 24 подсистема управления Wi-Fi была реализована на C внутри демона `netifd` с вызовом шелл-оберток `/lib/netifd/wireless/*.sh`.
   В OpenWrt 25 весь C-код беспроводных сетей был удален из `netifd` и заменен загрузчиком скриптов на `ucode` (`/lib/netifd/main.uc`):
   ```javascript
   const wireless_module = dirname(sourcepath()) + "/wireless.uc";
   if (access(wireless_module, "r")) {
           try {
                   wireless = loadfile(wireless_module)();
           } catch (e) {
                   netifd.log(netifd.L_WARNING, `Error loading wireless module: ${e}\n`);
           }
   } else {
           netifd.log(netifd.L_WARNING, `Wireless module not found\n`);
   }
   ```
2. **Выделение пакета `wifi-scripts`**:
   Файлы `/lib/netifd/wireless.uc`, `/lib/netifd/wireless-device.uc` и библиотеки `/usr/share/ucode/wifi/` были перенесены в отдельный апстримный пакет **`package/network/config/wifi-scripts`**.
3. **Обрыв цепочки зависимостей**:
   В стандартном OpenWrt пакет `wifi-scripts` включается как зависимость открытого драйвера `kmod-mac80211`:
   ```makefile
   # package/kernel/mac80211/Makefile
   DEPENDS += +wifi-scripts
   ```
   В нашем сабтаргете `ipq53xx_32` для BE3600 используется закрытый проприетарный драйвер ядра QSDK (`wifi_3_0.ko`) и закрытый `qca-hostap-vendor`. Пакет `kmod-mac80211` не используется.
   В результате в конфигурации сборки флаг `CONFIG_PACKAGE_wifi-scripts` оказался выключен (`# CONFIG_PACKAGE_wifi-scripts is not set`), и файл `/lib/netifd/wireless.uc` **не попал в образ rootfs**.
   Не найдя модуля, `netifd` вообще не регистрировал шину `network.wireless`.

---

## 4. Архитектурные особенности интеграции `wifi-scripts` с Qualcomm QSDK

Простая установка апстримного пакета `wifi-scripts` «как есть» порождает две вторичные проблемы:

### 4.1. Несовместимость режима Ucode Hostapd (`CONFIG_WIFI_SCRIPTS_UCODE`)
В OpenWrt 25 по умолчанию активирован флаг `CONFIG_WIFI_SCRIPTS_UCODE=y`. В этом режиме пакет заменяет шелл-скрипт `mac80211.sh` на ucode-генератор, который пытается управлять точкой доступа через UBUS-интерфейс демона hostapd:
```javascript
ubus.call("hostapd", "config_add", ...);
```
**Проблема**: Закрытый бинарник Qualcomm `qca-hostap-vendor` (QSDK 12.4/12.5) скомпилирован без поддержки UBUS-объектов OpenWrt. Он поддерживает только традиционный запуск через конфигурационный файл на диске (`/var/run/hostapd-athX.conf`) и управление через локальный сокет управления `hostapd_cli`.

**Требование**: Флаг `CONFIG_WIFI_SCRIPTS_UCODE` должен быть **отключен** (`# CONFIG_WIFI_SCRIPTS_UCODE is not set`).
В режиме legacy (`WIFI_SCRIPTS_UCODE=n`):
* `wireless.uc` использует функцию `handler_load()`, которая сканирует каталог `/lib/netifd/wireless/*.sh`.
* Для каждого устройства вызывается классический драйвер через `netifd.process()`:
  ```javascript
  argv: [ './' + wdev.script, wdev.data.config.type, op, wdev.name, "" + wdev.handler_config ]
  ```
* Это обеспечивает 100% совместимость с нашим фирменным скриптом `target/linux/ipq53xx/ipq53xx_32/base-files/lib/netifd/wireless/mac80211.sh`, реализующим двухэтапную инициализацию `wlanconfig` + `iw` и расширенные параметры Wi-Fi 7 (EHT160, Beamforming, Probe Response Offload).

### 4.2. Конфликт принадлежности файлов (Apk file collision) и его элегантное решение
Пакет `wifi-scripts` устанавливает:
* `/lib/netifd/wireless/mac80211.sh`
* `/sbin/wifi`

Если эти же пути присутствуют в `target/linux/ipq53xx/ipq53xx_32/base-files/`, пакетный менеджер `apk` выдает ошибку коллизии владения файлами:
```text
ERROR: wifi-scripts-1.0-r1: trying to overwrite lib/netifd/wireless/mac80211.sh owned by base-files.
ERROR: wifi-scripts-1.0-r1: trying to overwrite sbin/wifi owned by base-files.
```

**Решение (проверено на живом оборудовании)**:
1. **Штатный `/sbin/wifi` из `wifi-scripts` полностью совместим**: в OpenWrt 25 `/sbin/wifi` представляет собой тонкую ucode-обертку над методами Ubus `network.wireless up/down/reload/status`. Собственный `/sbin/wifi` из `base-files` удален (`git rm`).
2. **Изоляция драйвера в `qcawifi.sh` с регистрацией драйвера `mac80211`**:
   Скрипт драйвера сабтаргета переименован в `qcawifi.sh`:
   `target/linux/ipq53xx/ipq53xx_32/base-files/lib/netifd/wireless/qcawifi.sh`.
   Внутри скрипта вызывается:
   ```sh
   add_driver mac80211
   ```
   Благодаря алфавитной сортировке `glob(path + "/*.sh")` в `handler_load()`, сначала считывается ванильный `mac80211.sh`, а затем `qcawifi.sh`, который атомарно перезаписывает хэндлер `wireless.handlers["mac80211"]`.
   * **100% совместимость с LuCI**: веб-интерфейс `feeds/luci/.../wireless.js` проверяет `hwtype == 'mac80211'`, поэтому в LuCI без модификаций отображаются все функции Wi-Fi 7 / 160MHz / EHT.
   * **100% совместимость с существующей конфигурацией UCI**: `config wifi-device` по-прежнему использует `option type 'mac80211'`.
   * **Чистая установка через APK**: файлы не пересекаются, оверлей сабтаргета не конфликтует с пакетом `wifi-scripts`.

### 4.3. Апстримный баг в `utils.uc` (зависание `handler_load`)
В ванильном `package/network/config/netifd/files/lib/netifd/utils.uc` обнаружен критический баг: цикл чтения схемы драйвера `while (!f.error())` крутится бесконечно при наступлении EOF, так как `getline()` в ucode возвращает `null`, не выставляя `errno` (EOF не является ошибкой I/O). В результате `netifd` зависал со 100% CPU.
**Исправление**:
```javascript
let line;
while ((line = f.read("line")) != null) {
    let data = trim(line);
    // ...
```

### 4.4. Типизация атрибута `disabled` (Type Safety)
В `qcawifi.sh` атрибут `disabled` исключен из `config_add_string`:
В `wireless.uc` атрибут `device.disabled` имеет тип `TYPE_BOOL` (7). Если драйвер объявляет его строкой через `config_add_string`, значение `"0"` парсится как строка, что в проверках JS/ucode `if (dev.config.disabled)` трактуется как truthy (`true`), из-за чего радиоинтерфейс ошибочно считался выключенным.

---

## 5. Статус реализации и результаты валидации на стенде

Все доработки протестированы и верифицированы на тестовом маршрутизаторе Xiaomi Router BE3600 RD15 (`192.168.11.24`):

1. **Регистрация в UBUS**:
   Объект `network.wireless` корректно зарегистрирован и отдает статус обоих диапазонов:
   * `radio0` (2.4 GHz, `ath0`, HE40 / 40 МГц, Tx-Power 29 dBm)
   * `radio1` (5 GHz, `ath1`, EHT160 / 160 МГц, Tx-Power 28 dBm, PHY rate 2402 Mbps)
2. **Интеграция с мостом `br-lan`**:
   Интерфейсы `ath0` и `ath1` успешно добавлены в мост `br-lan` (DSA) через netifd без гонок.
3. **Беспроводные демоны**:
   Два экземпляра вендорного `qca-hostapd` запущены с изолированным `ld-vendor.so.1` и библиотеками `v_lc.so`.
4. **Управление через `/sbin/wifi`**:
   Команды `/sbin/wifi down` и `/sbin/wifi up` корректно останавливают и перезапускают беспроводной стек за ~1.2 секунды.
5. **Безошибочная сборка**:
   Конфликты APK устранены, `DEFAULT_PACKAGES` сабтаргета дополнен `wifi-scripts`, а `WIFI_SCRIPTS_UCODE` отключен в `prepare_config.sh`.
