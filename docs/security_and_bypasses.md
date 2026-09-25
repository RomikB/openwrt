# Безопасность, обход блокировок, VPN и DNS-сервисы (docs/security_and_bypasses.md)

Данный документ аккумулирует архитектурные решения, особенности настройки, рабочие конфигурации и методики устранения неисправностей для инструментов сетевой безопасности и обхода цензуры на маршрутизаторе **Xiaomi Router BE3600 (RD15)** под управлением OpenWrt 24 (ядро 5.4.213 QSDK 12.4).

---

## 1. Специфика платформы и ограничения

Маршрутизатор Xiaomi BE3600 на чипсете **Qualcomm IPQ5332** накладывает строгие системные требования на работу с пакетами и трафиком:
1. **Аппаратный акселератор PPE / ECM (`kmod-qca-nss-ppe`, `ecm.ko`)**:
   * Любые перехваты пакетов (Netfilter, `NFQUEUE`, `TPROXY`) должны учитывать работу драйвера ускорения Qualcomm ECM.
   * Пакеты, требующие десинхронизации или проксирования, должны маркироваться (`fwmark` / `ct mark`), предотвращая преждевременный оффлоад потока в кремний PPE до завершения инспекции и модификации L7-заголовков.
2. **Лимиты оперативной памяти (256 МБ RAM, доступно ~50–60 МБ)**:
   * Запрещено использование тяжелых runtime-сред (Go/Rust демоны без оптимизации по памяти, Python).
   * Бинарник `nfqws2` сжат через UPX и собран с легковесным Lua 5.4, что обеспечивает потребление памяти всего **~2.2 МБ RSS**.
3. **Межсетевой экран `firewall4` (`nftables 1.1.x` + `ucode`)**:
   * Все правила таблиц и цепочек базируются на `nftables`.
   * Хуки сторонних инструментов встраиваются через выделенные таблицы (например, `table inet zapret2`) с четким контролем приоритетов Netfilter.

---

## 2. Активная конфигурация Zapret2 (DPI Desync)

### 2.1. Архитектурный профиль сервиса
* **Версия пакета**: `zapret2` 0.9.20260307 + `luci-app-zapret2`.
* **Движок**: `/opt/zapret2/nfq2/nfqws2`.
* **Язык скриптов десинка**: Lua 5.4 (`zapret-lib.lua`, `zapret-antidpi.lua`, `zapret-auto.lua`).
* **Потребление RAM**: ~2.2 МБ RSS при полной нагрузке.
* **Сетевой хук**: `table inet zapret2` в цепочке `postrouting` с приоритетом `srcnat + 1` (`POSTNAT=1`).
* **Метка десинхронизации**: `0x40000000` (исключает циклическую обработку сгенерированных пакетов и информирует модуль ECM).

---

### 2.2. Рабочая стратегия десинхронизации: `v1_by_AnonymTsk`

На текущем стенде и у целевого провайдера подтверждена 100% стабильность стратегии `v1_by_AnonymTsk` как для веб-клиентов, так и для мобильных устройств (Android):

```sh
# Основной параметр NFQWS2_OPT в /etc/config/zapret2 и /opt/zapret2/config:
--comment=Strategy__v1_by_AnonymTsk \
--blob=blob_tls_clienthello_www_google_com:@/opt/zapret2/files/fake/tls_clienthello_www_google_com.bin \
--blob=blob_quic_initial_www_google_com:@/opt/zapret2/files/fake/quic_initial_www_google_com.bin \
--filter-tcp=443,80 --filter-l7=http,tls <HOSTLIST> \
  --payload=tls_client_hello \
  --lua-desync=fake:blob=fake_default_tls:tls_mod=rnd,dupsid,sni=www.google.com:tcp_ts=-1000 \
  --lua-desync=multidisorder:pos=1,midsld,sniext+1,endhost-2,-10:seqovl=1:seqovl_pattern=blob_tls_clienthello_www_google_com:tcp_ts_up \
  --payload=http_req \
  --lua-desync=http_methodeol:badsum \
--new \
--filter-udp=443 --filter-l7=quic <HOSTLIST_NOAUTO> \
  --payload=quic_initial \
  --lua-desync=fake:blob=blob_quic_initial_www_google_com:repeats=11 \
--new \
--filter-udp=590-600,1400,3478-3481,5349,19294-19344,50000-65535 \
--filter-l7=wireguard,stun,discord,mtproto \
  --out-range=-n1 \
  --payload=wireguard_initiation,wireguard_response,wireguard_cookie,stun,discord_ip_discovery,mtproto_initial \
  --lua-desync=fake:blob=quic_initial:repeats=6
```

#### Разбор механизмов стратегии:
1. **TCP (HTTP/TLS, порты 80, 443)**:
   * **TLS ClientHello**: отправляется фейковый пакет с подмененным SNI `www.google.com` и смещением временной метки `tcp_ts=-1000`, после чего реальный ClientHello фрагментируется на несколько частей (`multidisorder`) и отправляется в перемешанном порядке с перекрытием `seqovl`.
   * ТСПУ провайдера не может собрать и распознать заблокированный SNI в потоке.
2. **UDP QUIC (HTTP/3, порт 443)**:
   * Критически важно для **мобильного приложения YouTube на Android**.
   * Пакет `quic_initial` десинхронизируется инъекцией 11 повторов фейкового пакета `quic_initial_www_google_com.bin`.
3. **UDP Voice / Discovery / RTC (Discord и мессенджеры)**:
   * Порты `590-600, 1400, 3478-3481, 5349, 19294-19344, 50000-65535`.
   * Перехватываются служебные пакеты STUN, Discord IP Discovery и инициализации туннелей, защищая голосовые каналы от сброса.

---

### 2.3. Списки доменов (`hostlist`)

Система использует списки хостов в каталоге `/opt/zapret2/ipset/`:

| Файл | Назначение |
| :--- | :--- |
| `zapret-hosts-user.txt` | Пользовательские домены (все зоны Discord: `discord.com`, `discordapp.com`, `gateway.discord.gg`, базовые домены YouTube). |
| `zapret-hosts-google.txt` | Полный список доменов инфраструктуры Google / YouTube (CDN, GGC, API). |
| `zapret-hosts.txt` | **Символическая ссылка** на `zapret-hosts-google.txt` (`ln -sf zapret-hosts-google.txt zapret-hosts.txt`). |
| `zapret-hosts-user-exclude.txt` | Исключения из десинхронизации (гос. ресурсы, банковские шлюзы). |

> [!IMPORTANT]
> Макрос `<HOSTLIST>` в конфигурации `zapret2` автоматически расширяется в связку:
> `--hostlist=/opt/zapret2/ipset/zapret-hosts-user.txt --hostlist=/opt/zapret2/ipset/zapret-hosts.txt`
> Благодаря симлинку `zapret-hosts.txt -> zapret-hosts-google.txt` списки объединяются автоматически без ручного дублирования сотен доменов в пользовательском файле.

---

### 2.4. Критические правила взаимодействия с сетью и фаерволом

#### Правило 1: СТРОГО ЗАПРЕЩЕНО блокировать QUIC в firewall4 (`Block-QUIC`)
* **Симптом**: YouTube открывается в браузере на ПК, но бесконечно грузится или не воспроизводит видео в мобильном приложении Android.
* **Причина**: Мобильный сетевой стек Android (Cronet) использует QUIC (UDP 443) как приоритетный протокол. При наличии правила `REJECT udp dport 443` роутер отвечает пачками ICMP Port Unreachable (сотни пакетов), вызывая таймаут и зависание приложения.
* **Решение**: Правило `Block-QUIC` удалено из `/etc/config/firewall`. Весь трафик UDP 443 поступает в `zapret2`, где успешно десинхронизируется модулем QUIC.

#### Правило 2: Обработка IPv6 (NAT66 Masquerading vs отключение при отсутствии PD)
* **Симптом**: Долгий отклик или зависание сервисов Google/YouTube на смартфонах при наличии IPv6.
* **Причина**: В большинстве региональных сетей и при каскадном подключении вышестоящий роутер/провайдер выдает только один адрес `/64` без Prefix Delegation (PD) и жестко привязывает его к MAC-адресу. Демон `odhcpd` анонсирует локальные адреса `fd00:...`, но без NAT66 провайдер уничтожает пакеты из-за неизвестного Source IP.
* **Решение (Штатный NAT66 из коробки)**:
  В дереве исходников сабтаргета внедрен скрипт первого запуска [`target/linux/ipq53xx/rd15/base-files/etc/uci-defaults/06-ipv6-nat66`](file:///home/romikb/openwrt/target/linux/ipq53xx/rd15/base-files/etc/uci-defaults/06-ipv6-nat66):
  1. Включает IPv6-маскарадинг на зоне WAN (`firewall.@zone[1].masq6='1'`).
  2. Настраивает раздачу ULA-адресов с принудительным объявлением шлюза (`dhcp.lan.ra_default='2'`, `dhcp.lan.ra_slaac='1'`).
  3. Разрешает IPv6 AAAA-записи в DNS (`dhcp.@dnsmasq[0].filter_aaaa='0'`).
  4. Активирует десинхронизацию IPv6 в zapret2 (`zapret2.config.DISABLE_IPV6='0'`).
  
  *При необходимости полного отключения IPv6* (если провайдер вообще не поддерживает IPv6 на WAN):
  ```sh
  uci set dhcp.lan.dhcpv6='disabled'
  uci set dhcp.lan.ra='disabled'
  uci set dhcp.@dnsmasq[0].filter_aaaa='1'
  uci commit dhcp
  /etc/init.d/odhcpd restart
  /etc/init.d/dnsmasq restart
  ```

#### Правило 3: Первоначальная инициализация и применение конфигурации Zapret2
Для полной автоматизации при первой установке или сбросе прошивки внедрены два скрипта первоначальной настройки. Благодаря именам с префиксом `zz-...` они гарантированно вызываются в `/etc/init.d/boot` **после** генерации базового конфига пакетом (`zapret2-uci-def-cfg.sh`):

1. **[`target/linux/ipq53xx/rd15/base-files/etc/uci-defaults/zz-zapret2-setup`](file:///home/romikb/openwrt/target/linux/ipq53xx/rd15/base-files/etc/uci-defaults/zz-zapret2-setup)**:
   - Активирует стратегию `v1_by_AnonymTsk` через `set_cfg_nfqws_strat`.
   - Синхронизирует UCI в бинарный конфиг `/opt/zapret2/config`.
   - Создает символическую ссылку `zapret-hosts.txt -> zapret-hosts-google.txt` (подключает полный список YouTube/Google).
   - Сохраняет дефолтный `zapret-hosts-user.txt` (содержит зоны Discord).
   - Сервис по умолчанию **выключен** (`run_on_boot='0'`) до момента, пока пользователь осознанно не включит его в LuCI или через CLI (`/etc/init.d/zapret2 enable`). Все сетевые параметры (FLOWOFFLOAD, INIT_APPLY_FW, MODE_FILTER) уже имеют нужные значения по умолчанию.
2. **[`target/linux/ipq53xx/rd15/base-files/etc/uci-defaults/zz-zapret2-ipv6`](file:///home/romikb/openwrt/target/linux/ipq53xx/rd15/base-files/etc/uci-defaults/zz-zapret2-ipv6)**:
   - Выделенный скрипт активации IPv6 в zapret2: выставляет `DISABLE_IPV6='0'` и синхронизирует `/opt/zapret2/config`. Системный сетевой IPv6 NAT66 настраивается скриптом `06-ipv6-nat66`.

При ручном изменении параметров через CLI или LuCI требуется процедура синхронизации:
```sh
# 1. Применение настроек через UCI или comfunc
. /opt/zapret2/comfunc.sh
set_cfg_nfqws_strat v1_by_AnonymTsk

# 2. Синхронизация UCI -> /opt/zapret2/config
/opt/zapret2/sync_config.sh

# 3. Перезапуск демона и правил nftables
/etc/init.d/zapret2 restart
```

---

## 3. Маршрутизация списков блокировок: RuAntiBlock

* **Пакеты**: `ruantiblock`, `luci-app-ruantiblock`, `kmod-nft-tproxy`.
* **Текущий статус**: Включен в состав прошивки, демон по умолчанию остановлен (`enabled='0'`).
* **Роль в архитектуре**:
  * Предназначен для скачивания агрегированных списков реестра блокировок (Antifilter / Rublacklist) и направления трафика заблокированных IP через VPN-туннель (WireGuard / AmneziaWG / TProxy).
  * Не потребляет память под полный список 400k+ адресов за счет использования оптимизированных IP-суммаризаций CIDR (`bllist_summarize_cidr='1'`).
  * При активации направляет только заблокированные IP в интерфейс туннеля (например, `awg0`), оставляя весь остальной трафик в прямом гигабитном WAN.

### 3.1. Пошаговая инструкция по настройке RuAntiBlock (User Runbook)

Для корректной работы раздельной маршрутизации пользователю необходимо выполнить следующие шаги:

#### Шаг 1: Подготовка интерфейса туннеля (`awg0` / `wg0`)
1. В веб-интерфейсе LuCI перейти в **Сеть** $\to$ **Интерфейсы** $\to$ добавить новый интерфейс (протокол `AmneziaWG VPN` или `WireGuard`, имя: `awg0`).
2. Ввести ключи, адрес пира и параметры обфускации (`Jc`, `H1`–`H4`).
3. **Критично (Автозапуск)**: На вкладке «Общие настройки» проверить флаг **«Автозапуск»** (`option auto '1'`), чтобы туннель поднимался при перезагрузке роутера.
4. **Критично (Сетевой экран NAT)**: На вкладке **«Настройки межсетевого экрана»** обязательно включить интерфейс `awg0` в зону **`wan`** (иначе пакеты клиентов локальной сети `192.168.1.x` не будут маскарадиться при выходе в туннель).
5. **Раздельная маршрутизация (Split Tunneling)**: Убедиться, что опция «Маршрут по умолчанию» отключена (`option defaultroute '0'`). Обычный интернет должен идти через физический WAN.

#### Шаг 2: Настройка службы RuAntiBlock в LuCI
В LuCI перейти в **Службы** $\to$ **RuAntiBlock**:
1. **Вкладка «Основные настройки»**:
   * Режим проксирования: **VPN** (`proxy_mode '2'`).
   * VPN-интерфейс: **`awg0`** (`if_vpn 'awg0'`).
2. **Вкладка «Списки пользователя» (Точечный обход)**:
   * Выбрать **Список 1** и поставить галочку **«Включить список 1»**.
   * **Важно**: В поле «VPN-интерфейс» для Списка 1 выбрать **`awg0`** (по умолчанию там может стоять `tun0`).
   * В текстовое поле ввести нужные домены (по одному на строку), например:
     ```text
     rutracker.org
     instagram.com
     ifconfig.me
     ```
3. **Вкладка «Общий список» (Опционально — реестры РКН)**:
   * Если требуется автоматическая выгрузка заблокированных ресурсов, выбрать источник: например, `antifilter-ip` или `ruantiblock-fqdn`.
4. Нажать кнопку **«Сохранить и применить»**.
5. На вкладке «Управление службой» нажать **«Включить»** (для добавления в автозапуск) и **«Старт»** (если сервис еще не запущен).
6. Если используется Общий список — нажать кнопку **«Обновить список»**.

#### Шаг 3: Настройки на клиентских устройствах (ПК / Смартфоны)
1. **Отключение стороннего DoH**: В браузерах (Chrome, Firefox, Edge) и на смартфонах (Android «Частный DNS») временно отключить безопасный DNS / DoH, либо настроить их на использование DNS роутера (`192.168.1.1`). Если браузер использует зашифрованный DoH (Cloudflare 1.1.1.1 / Google 8.8.8.8 напрямую по TLS 853/443), встроенный `dnsmasq` роутера не сможет перехватить резолвинг домена и добавить его динамический IP в nftset `d.list1`.
2. **Сброс кэша DNS**: Браузеры кэшируют предыдущие IP. При первой проверке откройте сайт во **вкладке инкогнито** или выполните `ipconfig /flushdns` на ПК.

#### Шаг 4: Проверка работоспособности через CLI роутера
```sh
# 1. Проверка статуса службы (не должно быть ошибок VPN ROUTING ERROR)
ruantiblock status

# 2. Проверка генерации правил для dnsmasq
cat /tmp/dnsmasq.*.d/01-ruantiblock_user_instances.dnsmasq

# 3. Проверка наполнения динамического сета после обращения к домену
nft list set ip r d.list1

# 4. Проверка раздельного выхода в сеть:
curl -4 -s https://ifconfig.me     # Должен вернуть IP VPN-сервера (Финляндия)
curl -4 -s https://api.ipify.org   # Должен вернуть IP вашего провайдера (РФ)
```

---

## 4. VPN-туннелирование (AmneziaWG / WireGuard)

### 4.1. AmneziaWG (Awg)
* **Пакеты**: `amneziawg-tools`, `luci-proto-amneziawg`, модуль ядра `kmod-amneziawg` (встроен в ядро 5.4.213).
* **Специфика**:
  * Модификация WireGuard с обфускацией заголовков инициализации (`Jc`, `Jmin`, `Jmax`, `S1`, `S2`, `H1`, `H2`, `H3`, `H4`).
  * Позволяет преодолевать блокировки протокола WireGuard ТСПУ на магистральных каналах.
* **Совместимость с PPE/ECM**:
  * Трафик виртуального интерфейса `awg0` обрабатывается драйвером `ecm`, аппаратное шифрование/дешифрование выполняется на ядрах ARM Cortex-A7 (до 250–350 Мбит/с пропускной способности).

---

## 5. Защищенный DNS (DoH / DoT / DNSCrypt)

### 5.1. Текущий DNS-стек
* **Демон**: `dnsmasq-full` (v2.93, поддержка conntrack, nftset, фильтрации AAAA).
* **Фильтрация IPv6**: `filter_aaaa='1'` (исключает резолвинг IPv6-адресов для предотвращения таймаутов).
* **Внутренний кэш**: 1000 записей.

### 5.2. Планы по развертыванию DoH / DoT
* Для защиты от перехвата и подмены DNS-ответов провайдером планируется интеграция легковесного DoH-клиента (`https-dns-proxy` или интеграция Stubby/Dnsmasq DoT).
* На смартфонах Samsung/Android при включенном режиме «Частный DNS» (Private DNS, TLS порт 853) трафик идет напрямую на резолверы Google/Cloudflare в обход локального dnsmasq. При необходимости локального контроля порт 853 перенаправляется на роутере.

---

## 6. Чек-лист диагностики (Troubleshooting Playbook)

| Проблема | Диагностическая команда на роутере | Метод устранения |
| :--- | :--- | :--- |
| **Проверка статуса zapret2** | `ps \| grep nfqws2` | Если процесс отсутствует: `/etc/init.d/zapret2 restart` |
| **Проверка правил nftables** | `nft list chain inet zapret2 postnat` | Проверить наличие счетчиков и перенаправления в queue 300 |
| **Проверка сессий клиента** | `grep 192.168.1.243 /proc/net/nf_conntrack` | Убедиться, что сессии имеют метку `mark=1073741824` |
| **Проверка ответа сервера** | `curl -4 -Iv -m 4 https://discord.com` | Должен возвращать `HTTP/2 200` |
| **Проверка потока YouTube** | `curl -4 -Iv -m 4 https://www.youtube.com` | Должен возвращать `HTTP/2 200` |
| **Диагностика QUIC от клиента**| `nft list chain inet fw4 forward_lan` | Убедиться в **отсутствии** отбрасывания пакетов `dport 443` |
| **Просмотр логов десинка** | `uci set zapret2.config.DAEMON_LOG_ENABLE='1'; ...` | Лог пишется в `/tmp/zapret2+nfqws2+1+main.log` (не забывать отключать) |
