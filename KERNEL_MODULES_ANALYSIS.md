# Анализ и сопоставление модулей ядра: Xiaomi BE3600 (RD15)

## 1. Общая сводка

* **Версия ядра Linux**: `5.4.213` (Qualcomm Hardened / OpenWrt 21.02 BSP)
* **Целевая платформа**: `ipq53xx/rd15` (Qualcomm IPQ5332, 4x Cortex-A7 @ 1.1 GHz)
* **Встроенные драйверы и подсистемы (`CONFIG_*=y`)**: **988 параметров** (монолитная часть бинарника ядра `target/linux/ipq53xx/rd15/kernel`)
* **Всего модулей ядра (`.ko` / `CONFIG_*=m`) в стоковой прошивке**: **234 файла** (148 пакетов `kmod-*`)
* **Модулей используется в нашей сборке OpenWrt 24 сейчас**: **102 файла** (62 пакета `kmod-*-vendor`)
* **Модулей не используется сейчас**: **132 файла**

---

## 2. Встроенные в ядро подсистемы и драйверы (`CONFIG_*=y`)

Эти драйверы скомпилированы непосредственно в монолитный образ ядра `kernel@1` (FIT Image) и активны автоматически при загрузке системы:

| Подсистема / Драйвер | Символы конфигурации | Назначение и функционал |
| :--- | :--- | :--- |
| **Qualcomm SoC Platform** | `CONFIG_ARCH_IPQ5332=y`, `CONFIG_QCOM_SCM=y`, `CONFIG_QCOM_SMEM=y`, `CONFIG_QCOM_TLMM=y` | Инициализация чипсета IPQ5332, TrustZone/SCM, разделяемая память SMEM, контроллер пинов TLMM (GPIO multiplexing). |
| **Клоки, Питание и DMA** | `CONFIG_IPQ_GCC_IPQ5332=y`, `CONFIG_IPQ_APSS_IPQ5332=y`, `CONFIG_QCOM_BAM_DMA=y`, `CONFIG_QCOM_WDT=y` | Тактовые генераторы GCC/APSS/NSSCC, контроллер прямого доступа к памяти BAM DMA, аппаратный сторожевой таймер Watchdog. |
| **Аппаратное крипто (QCE)** | `CONFIG_CRYPTO_DEV_QCE_SKCIPHER=y`, `CONFIG_CRYPTO_DEV_QCE_SHA=y`, `CONFIG_CRYPTO_DEV_QCE_AEAD=y` | Аппаратный блок Qualcomm Crypto Engine 5.0 (QCE) для разгрузки CPU при шифровании AES/SHA/AEAD. |
| **ARM NEON Crypto** | `CONFIG_CRYPTO_AES_ARM_CE=y`, `CONFIG_CRYPTO_SHA2_ARM_CE=y`, `CONFIG_CRYPTO_GHASH_ARM_CE=y` | Векторные NEON инструкции ARM Cortex-A7 для быстрого криптографического хеширования и блочного шифрования. |
| **Аппаратный TRNG** | `CONFIG_HW_RANDOM_MSM_LEGACY=y` | Аппаратный генератор истинно случайных чисел SoC Qualcomm. |
| **Шина PCI Express** | `CONFIG_PCI=y`, `CONFIG_PCIE_QCOM=y`, `CONFIG_PCIE_DW_HOST=y` | Контроллер Synopsys DesignWare PCIe Host для внешнего Wi-Fi 5 GHz радиомодуля QCN6432. |
| **Хранилище и Flash (NAND)** | `CONFIG_MTD_NAND_QCOM=y`, `CONFIG_MTD_UBI=y`, `CONFIG_UBIFS_FS=y`, `CONFIG_SQUASHFS=y` | QPIC SPI-NAND контроллер, подсистема UBI томов, файловые системы UBIFS (`/data`), SquashFS (`rootfs`) и OverlayFS. |
| **Сетевое ядро (Net Core)** | `CONFIG_BRIDGE=y`, `CONFIG_VLAN_8021Q=y`, `CONFIG_INET=y`, `CONFIG_IPV6=y`, `CONFIG_RPS=y` | Сетевой мост Linux Bridge, тегирование 802.1Q VLAN, сетевые протоколы IPv4/IPv6, SMP Packet Steering (RPS/XPS). |
| **Базовый Netfilter** | `CONFIG_NETFILTER=y`, `CONFIG_NF_CONNTRACK=y`, `CONFIG_NF_NAT=y` | Базовый движок межсетевого экрана и таблицы отслеживания состояний Conntrack. |

---

## 3. Модули ядра, используемые в текущей сборке OpenWrt 24 (102 шт.)

В настоящее время в `vendor_feed` и сборочную конфигурацию включены 102 модуля ядра:

```text
ath_pktlog.ko            ecm.ko                   l2tp_netlink.ko          qca-nss-ppe-vlan.ko      xt_comment.ko
bootconfig.ko            ecm_ae_select.ko         l2tp_ppp.ko              qca-nss-ppe-vp.ko        xt_connbytes.ko
cfg80211.ko              ecm_sfe_l2.ko            leds-gpio.ko             qca-nss-ppe-vxlanmgr.ko  xt_connlimit.ko
crc-ccitt.ko             emesh-sp.ko              mem_manager.ko           qca-nss-ppe.ko           xt_connmark.ko
gpio-button-hotplug.ko   ip6_tables.ko            monitor.ko               qca-nss-sfe.ko           xt_conntrack.ko
ip6_udp_tunnel.ko        ip6t_NPT.ko              nat46.ko                 qca-ssdk.ko              xt_dscp.ko
ip6t_REJECT.ko           ip6table_filter.ko       nf_conncount.ko          qca_ol.ko                xt_DSCP.ko
ip6table_mangle.ko       ip6table_nat.ko          nf_conntrack_rtcache.ko  qdf.ko                   xt_ecn.ko
ip_gre.ko                ip_tables.ko             nf_log_common.ko         udp_tunnel.ko            xt_helper.ko
ip_tunnel.ko             ipq_cnss2.ko             nf_log_ipv4.ko           umac.ko                  xt_hl.ko
ipt_ECN.ko               ipt_REJECT.ko            nf_log_ipv6.ko           vxlan.ko                 xt_HL.ko
iptable_filter.ko        iptable_mangle.ko        nf_nat.ko                wifi_3_0.ko              xt_length.ko
iptable_nat.ko           iptable_raw.ko           nf_reject_ipv4.ko        x_tables.ko              xt_limit.ko
l2tp_core.ko             nf_reject_ipv6.ko        ppp_async.ko             xt_CLASSIFY.ko           xt_LOG.ko
pwm-rgb.ko               qca-mcs.ko               qca-nss-dp.ko            xt_CT.ko                 xt_mac.ko
qca-nss-ppe-bridge-mgr.ko qca-nss-ppe-ds.ko       qca-nss-ppe-lag.ko       xt_FLOWOFFLOAD.ko        xt_mark.ko
qca-nss-ppe-pppoe-mgr.ko qca-nss-ppe-rule.ko      qca-nss-ppe-tun.ko       xt_MASQUERADE.ko         xt_multiport.ko
xt_nat.ko                xt_owner.ko              xt_pkttype.ko            xt_quota.ko              xt_recent.ko
xt_REDIRECT.ko           xt_state.ko              xt_statistic.ko          xt_string.ko             xt_TCPMSS.ko
xt_tcpmss.ko             xt_tcpudp.ko             xt_time.ko               yt_phy_module.ko         yt_switch.ko
```

### Назначение групп активных модулей:
1. **Аппаратный уровень и сетевые интерфейсы**:
   * `qca-nss-dp.ko` — драйвер NSS Data Path сетевых интерфейсов `eth0` (WAN/LAN) и `eth1` (2.5G LAN).
   * `yt_switch.ko` — драйвер коммутатора Motorcomm YT9215S (`switch1`).
   * `yt_phy_module.ko` — драйвер Ethernet PHY Motorcomm.
   * `bootconfig.ko` — чтение параметров загрузчика U-Boot / factory.
   * `pwm-rgb.ko` — управление RGB светодиодом индикации (`/sys/class/leds/rgb`).
   * `leds-gpio.ko` — управление GPIO индикаторами.
   * `gpio-button-hotplug.ko` — диспетчер нажатия кнопок Reset и Mesh.
2. **Аппаратный оффлоад Qualcomm PPE / NSS ECM (Line Rate 2.5 Gbps)**:
   * Драйверы PPE: `qca-ssdk.ko`, `qca-nss-ppe.ko`, `qca-nss-ppe-rule.ko`, `qca-nss-ppe-vp.ko`, `qca-nss-ppe-bridge-mgr.ko`, `qca-nss-ppe-vlan.ko`, `qca-nss-ppe-tun.ko`, `qca-nss-ppe-vxlanmgr.ko`, `qca-nss-ppe-pppoe-mgr.ko`, `qca-nss-ppe-ds.ko`, `qca-nss-ppe-lag.ko`, `qca-nss-sfe.ko`.
   * Диспетчер соединений: `ecm.ko`, `ecm_ae_select.ko`, `ecm_sfe_l2.ko`, `emesh-sp.ko`, `qca-mcs.ko`.
3. **Беспроводной стек Qualcomm Direct Connect (Wi-Fi 6/7)**:
   * `ipq_cnss2.ko` — платформенный драйвер шины PCIe для радиомодуля QCN6432.
   * Драйверы радио: `mem_manager.ko`, `qdf.ko`, `umac.ko`, `qca_ol.ko`, `wifi_3_0.ko`, `cfg80211.ko`, `ath_pktlog.ko`, `monitor.ko`.
4. **Сетевые туннели и протоколы**:
   * `ppp_async.ko`, `crc-ccitt.ko` (PPPoE / PPP стек).
   * `l2tp_core.ko`, `l2tp_netlink.ko`, `l2tp_ppp.ko`, `ip_gre.ko`, `ip_tunnel.ko`, `udp_tunnel.ko`, `ip6_udp_tunnel.ko`, `vxlan.ko`, `nat46.ko`.
5. **Межсетевой экран Netfilter / Firewall3 / NAT**:
   * `ip_tables.ko`, `iptable_filter.ko`, `iptable_nat.ko`, `iptable_mangle.ko`, `iptable_raw.ko`, `ipt_REJECT.ko`, `ipt_ECN.ko`.
   * `ip6_tables.ko`, `ip6table_filter.ko`, `ip6table_nat.ko`, `ip6table_mangle.ko`, `ip6t_REJECT.ko`, `ip6t_NPT.ko`.
   * `nf_nat.ko`, `nf_conncount.ko`, `nf_conntrack_rtcache.ko`, `nf_reject_ipv4.ko`, `nf_reject_ipv6.ko`, `nf_log_common.ko`, `nf_log_ipv4.ko`, `nf_log_ipv6.ko`.
   * Библиотека матчей `xt_*` (34 модуля).

---

## 4. Неиспользуемые модули ядра (132 шт.), их назначение и оценка необходимости

### 🌟 Категория 1: IPset (Высокоскоростные списки IP/сетей/портов/MAC) — 17 модулей

| Модуль `.ko` | Вендорный пакет | Описание функционала | Необходимость |
| :--- | :--- | :--- | :---: |
| `ip_set.ko` | `kmod-ipt-ipset` | Базовое ядро подсистемы IPset. | 🔴 **Критическая** |
| `ip_set_hash_ip.ko` | `kmod-ipt-ipset` | Хеш-таблица единичных IP-адресов. | 🔴 **Критическая** |
| `ip_set_hash_net.ko` | `kmod-ipt-ipset` | Хеш-таблица подсетей (CIDR /24, /16 и т.д.). | 🔴 **Критическая** |
| `ip_set_list_set.ko` | `kmod-ipt-ipset` | Списки наборов (сет из сетов). | 🔴 **Критическая** |
| `xt_set.ko` | `kmod-ipt-ipset` | Матч `iptables -m set --match-set ...`. | 🔴 **Критическая** |
| `ip_set_hash_ipport.ko` | `kmod-ipt-ipset` | Хеш-таблица пар `IP:Port`. | 🟡 **Высокая** |
| `ip_set_hash_ipportnet.ko`| `kmod-ipt-ipset` | Хеш-таблица троек `IP:Port:Subnet`. | 🟡 **Высокая** |
| `ip_set_hash_mac.ko` | `kmod-ipt-ipset` | Хеш-таблица MAC-адресов. | 🟡 **Высокая** |
| `ip_set_hash_netport.ko` | `kmod-ipt-ipset` | Хеш-таблица пар `Subnet:Port`. | 🟡 **Высокая** |
| `ip_set_hash_netiface.ko`| `kmod-ipt-ipset` | Хеш-таблица пар `Subnet:Interface`. | 🟡 **Высокая** |
| `ip_set_hash_ipmark.ko` | `kmod-ipt-ipset` | Хеш-таблица пар `IP:fwmark`. | 🟡 **Высокая** |
| `ip_set_hash_ipportip.ko` | `kmod-ipt-ipset` | Хеш-таблица троек `IP:Port:IP`. | 🟡 **Высокая** |
| `ip_set_hash_netnet.ko` | `kmod-ipt-ipset` | Хеш-таблица пар `Subnet:Subnet`. | 🟡 **Высокая** |
| `ip_set_hash_netportnet.ko`| `kmod-ipt-ipset` | Хеш-таблица четверок `Subnet:Port:Subnet`. | 🟡 **Высокая** |
| `ip_set_bitmap_ip.ko` | `kmod-ipt-ipset` | Битовая карта для непрерывных диапазонов IP. | 🟢 **Средняя** |
| `ip_set_bitmap_ipmac.ko`| `kmod-ipt-ipset` | Битовая карта пар `IP:MAC`. | 🟢 **Средняя** |
| `ip_set_bitmap_port.ko` | `kmod-ipt-ipset` | Битовая карта диапазонов портов TCP/UDP. | 🟢 **Средняя** |

> [!IMPORTANT]
> **Оценка необходимости**: **КРИТИЧЕСКИ ВЫСОКАЯ**. 
> Модули IPset необходимы для выборочной маршрутизации трафика по спискам заблокированных/разрешенных ресурсов (Antizapret, zapret, sing-box, Xray, v2ray, BGP-маршрутизация). Позволяют проверять совпадение IP с базой в сотни тысяч записей за $O(1)$.

---

### 🌟 Категория 2: TPROXY (Прозрачное проксирование TCP/UDP) — 6 модулей

| Модуль `.ko` | Вендорный пакет | Описание функционала | Необходимость |
| :--- | :--- | :--- | :---: |
| `xt_TPROXY.ko` | `kmod-ipt-tproxy` | Таргет `iptables -j TPROXY` для прозрачного перехвата. | 🔴 **Критическая** |
| `xt_socket.ko` | `kmod-ipt-tproxy` | Матч `iptables -m socket` для проверки существования локального сокета. | 🔴 **Критическая** |
| `nf_tproxy_ipv4.ko` | `kmod-ipt-tproxy` | Ядерный бэкенд TPROXY для стека IPv4. | 🔴 **Критическая** |
| `nf_tproxy_ipv6.ko` | `kmod-ipt-tproxy` | Ядерный бэкенд TPROXY для стека IPv6. | 🔴 **Критическая** |
| `nf_socket_ipv4.ko` | `kmod-ipt-tproxy` | Поиск сокета открытого приложения для IPv4. | 🔴 **Критическая** |
| `nf_socket_ipv6.ko` | `kmod-ipt-tproxy` | Поиск сокета открытого приложения для IPv6. | 🔴 **Критическая** |

> [!IMPORTANT]
> **Оценка необходимости**: **КРИТИЧЕСКИ ВЫСОКАЯ**. 
> TPROXY — стандартный и самый производительный способ организации прозрачного проксирования клиентского трафика в OpenWrt (sing-box, Xray, Clash, Shadowsocks) без изменения адреса источника и без двойного NAT.

---

### 🚀 Категория 3: Traffic Control, QoS и шейпинг полосы пропускания — 6 модулей

| Модуль `.ko` | Вендорный пакет | Описание функционала | Необходимость |
| :--- | :--- | :--- | :---: |
| `sch_htb.ko` | `kmod-sched` | Иерархический токен-бакет (Hierarchical Token Bucket) для ограничения скорости. | 🟡 **Высокая** |
| `sch_sfq.ko` | `kmod-sched` | Стохастическое справедливое распределение очередей (Stochastic Fairness Queueing). | 🟡 **Высокая** |
| `sch_prio.ko` | `kmod-sched` | Строгая приоритизация очередей по классам трафика. | 🟡 **Высокая** |
| `cls_fw.ko` | `kmod-sched-core` | Классификатор пакетов по меткам брандмауэра (`fwmark`). | 🟡 **Высокая** |
| `cls_u32.ko` | `kmod-sched-core` | Универсальный 32-битный фильтр пакетов утилиты `tc`. | 🟡 **Высокая** |
| `em_ipt.ko` | `kmod-sched` | Расширенный матч iptables внутри классификатора `tc`. | 🟢 **Средняя** |

> [!TIP]
> **Оценка необходимости**: **ВЫСОКАЯ**. 
> Необходимы для работы пакетов `luci-app-sqm`, `luci-app-qos`, управления полосой пропускания клиентов и устранения задержек (Bufferbloat).

---

### 🚀 Категория 4: Расширенные модули фильтрации Iptables / Ip6tables — 17 модулей

| Модуль `.ko` | Вендорный пакет | Описание функционала | Необходимость |
| :--- | :--- | :--- | :---: |
| `xt_NFQUEUE.ko` | `kmod-ipt-nfqueue` | Передача сетевых пакетов в юзерспейс через Netlink очередь. | 🔴 **Критическая** (для `zapret` / `nfqws`) |
| `xt_hashlimit.ko` | `kmod-ipt-hashlimit` | Динамическое ограничение частоты пакетов по хеш-таблицам (Rate Limiting). | 🟡 **Высокая** (защита SSH/LuCI) |
| `xt_physdev.ko` | `kmod-ipt-physdev` | Фильтрация пакетов по физическому порту Ethernet моста. | 🟡 **Высокая** (изоляция портов) |
| `xt_u32.ko` | `kmod-ipt-u32` | Сопоставление произвольных битовых масок и смещений в пакетах. | 🟡 **Высокая** (кастомные фильтры) |
| `xt_esp.ko` | `kmod-ipt-ipsec` | Фильтрация зашифрованных IPsec ESP пакетов. | 🟢 **Средняя** (VPN IPsec) |
| `xt_policy.ko` | `kmod-ipt-ipsec` | Проверка соответствия пакета политике безопасности IPsec. | 🟢 **Средняя** (VPN IPsec) |
| `ipt_ah.ko` | `kmod-ipt-ipsec` | Фильтрация заголовков аутентификации IPsec AH. | 🟢 **Средняя** (VPN IPsec) |
| `ip6t_ah.ko` | `kmod-ip6tables-extra` | Фильтрация IPsec AH в пакетах IPv6. | 🟢 **Средняя** (VPN IPsec) |
| `ipt_rpfilter.ko` | `kmod-ipt-rpfilter` | Проверка обратного пути IPv4 (защита от IP Spoofing). | 🟢 **Средняя** |
| `ip6t_rpfilter.ko` | `kmod-ipt-rpfilter` | Проверка обратного пути IPv6. | 🟢 **Средняя** |
| `ip6table_raw.ko` | `kmod-ipt-raw6` | Таблица `raw` для IPv6 (правила `NOTRACK`). | 🟢 **Средняя** |
| `ip6t_eui64.ko` | `kmod-ip6tables-extra` | Фильтрация IPv6 адресов формата EUI-64 (по MAC). | ⚪ **Низкая** |
| `ip6t_frag.ko` | `kmod-ip6tables-extra` | Фильтрация фрагментированных пакетов IPv6. | ⚪ **Низкая** |
| `ip6t_hbh.ko` | `kmod-ip6tables-extra` | Фильтрация IPv6 Hop-by-Hop Extension заголовков. | ⚪ **Низкая** |
| `ip6t_ipv6header.ko`| `kmod-ip6tables-extra` | Проверка наличия расширенных заголовков IPv6. | ⚪ **Низкая** |
| `ip6t_mh.ko` | `kmod-ip6tables-extra` | Фильтрация Mobility Header в Mobile IPv6. | ⚪ **Низкая** |
| `ip6t_rt.ko` | `kmod-ip6tables-extra` | Фильтрация заголовков IPv6 Routing Header. | ⚪ **Низкая** |
| `xt_sctp.ko` | `kmod-ipt-sctp` | Фильтрация протокола SCTP. | ⚪ **Низкая** |

---

### 📦 Категория 5: Файловые системы и шифрование накопителей — 9 модулей

| Модуль `.ko` | Вендорный пакет | Описание функционала | Необходимость |
| :--- | :--- | :--- | :---: |
| `ext4.ko` | `kmod-fs-ext4` | Драйвер файловой системы EXT4/EXT3/EXT2. | 🟡 **Высокая** |
| `jbd2.ko` | `kmod-fs-ext4` | Диспетчер журналирования файловой системы (Journaling Block Device 2). | 🟡 **Высокая** |
| `mbcache.ko` | `kmod-fs-ext4` | Кеширование индексных дескрипторов EXT4. | 🟡 **Высокая** |
| `nls_utf8.ko` | `kmod-nls-utf8` | Кодировка UTF-8 для монтирования накопителей и файловых систем. | 🟡 **Высокая** |
| `nls_iso8859-1.ko`| `kmod-nls-iso8859-1` | Базовая таблица символов Western European ISO-8859-1. | 🟢 **Средняя** |
| `dm-req-crypt.ko` | `kmod-dm` | Аппаратное шифрование блочных устройств через криптоядро (Device Mapper Crypt). | 🟢 **Средняя** |
| `dm-mirror.ko` | `kmod-dm` | Программное зеркалирование разделов (RAID1 / Device Mapper Mirror). | ⚪ **Низкая** |
| `dm-log.ko` | `kmod-dm` | Модуль логирования изменений Device Mapper. | ⚪ **Низкая** |
| `dm-region-hash.ko`| `kmod-dm` | Хеширование блоков для зеркалированных разделов. | ⚪ **Низкая** |

> [!TIP]
> **Оценка необходимости**: **ВЫСОКАЯ**. 
> Позволяет создавать и монтировать виртуальные loopback-образы в EXT4 (для хранения сторонних пакетов, Docker-контейнеров или chroot), форматировать внешние разделы в EXT4 и обеспечивать корректную работу с именами файлов в UTF-8.

---

### 🌐 Категория 6: Дополнительные туннели и шифрование PPP — 4 модуля

| Модуль `.ko` | Вендорный пакет | Описание функционала | Необходимость |
| :--- | :--- | :--- | :---: |
| `ip6_tunnel.ko` | `kmod-ip6-tunnel` | Туннелирование IPv6-in-IPv6, DS-Lite, MAP-E/MAP-T. | 🟢 **Средняя** |
| `tunnel6.ko` | `kmod-iptunnel6` | Инфраструктура инкапсуляции туннелей IPv6. | 🟢 **Средняя** |
| `ppp_mppe.ko` | `kmod-mppe` | Алгоритм шифрования Microsoft Point-to-Point Encryption (MPPE) для PPTP VPN. | 🟢 **Средняя** |
| `passthrough.ko` | `kmod-passthrough` | Специализированный модуль проброса туннелей. | ⚪ **Низкая** |

---

### 📞 Категория 7: Netfilter Conntrack & NAT Helpers (ALG) — 15 модулей

| Модуль `.ko` | Вендорный пакет | Описание функционала | Необходимость |
| :--- | :--- | :--- | :---: |
| `nf_conntrack_ftp.ko` | `kmod-nf-nathelper` | Отслеживание портов пассивного режима FTP. | 🟢 **Средняя** |
| `nf_nat_ftp.ko` | `kmod-nf-nathelper` | Трансляция адресов портов данных FTP через NAT. | 🟢 **Средняя** |
| `nf_conntrack_sip.ko` | `kmod-nf-nathelper-extra` | Отслеживание сессий VoIP телефонии SIP (UDP/TCP 5060). | 🟢 **Средняя** |
| `nf_nat_sip.ko` | `kmod-nf-nathelper-extra` | Трансляция внутренних IP-адресов в теле SIP/SDP пакетов. | 🟢 **Средняя** |
| `nf_conntrack_pptp.ko`| `kmod-nf-nathelper-extra` | Отслеживание управляющих сессий PPTP VPN (TCP 1723). | 🟢 **Средняя** |
| `nf_nat_pptp.ko` | `kmod-nf-nathelper-extra` | Трансляция GRE Call ID для PPTP VPN клиентов. | 🟢 **Средняя** |
| `nf_conntrack_tftp.ko`| `kmod-nf-nathelper-extra` | Отслеживание сессий TFTP. | ⚪ **Низкая** |
| `nf_nat_tftp.ko` | `kmod-nf-nathelper-extra` | Трансляция динамических портов TFTP. | ⚪ **Низкая** |
| `nf_conntrack_irc.ko` | `kmod-nf-nathelper-extra` | Отслеживание DCC сессий передачи файлов в IRC. | ⚪ **Низкая** |
| `nf_nat_irc.ko` | `kmod-nf-nathelper-extra` | Трансляция портов IRC DCC. | ⚪ **Низкая** |
| `nf_conntrack_h323.ko`| `kmod-nf-nathelper-extra` | Отслеживание сессий видеоконференций H.323. | ⚪ **Низкая** |
| `nf_nat_h323.ko` | `kmod-nf-nathelper-extra` | Трансляция RTP портов H.323. | ⚪ **Низкая** |
| `nf_conntrack_snmp.ko`| `kmod-nf-nathelper-extra` | Отслеживание SNMP запросов. | ⚪ **Низкая** |
| `nf_nat_snmp_basic.ko`| `kmod-nf-nathelper-extra` | Трансляция IP-адресов в пакетах SNMP Payload. | ⚪ **Низкая** |
| `nf_conntrack_amanda.ko`| `kmod-nf-nathelper-extra`| Хелпер резервного копирования Amanda. | ⚪ **Низкая** |
| `nf_nat_amanda.ko` | `kmod-nf-nathelper-extra`| NAT хелпер Amanda. | ⚪ **Низкая** |
| `nf_conntrack_broadcast.ko`| `kmod-nf-nathelper-extra`| Обработка широковещательных пакетов в Conntrack. | ⚪ **Низкая** |

---

### ⏸️ Категория 8: Стек Nftables & Программный Flow Offload — 19 модулей

| Модуль `.ko` | Вендорный пакет | Описание функционала | Необходимость |
| :--- | :--- | :--- | :---: |
| `nf_tables.ko` | `kmod-nft-core` | Базовый движок Nftables (Firewall4). | ⚪ **Не используется** |
| `nft_counter.ko`, `nft_ct.ko`, `nft_limit.ko`, `nft_log.ko`, `nft_numgen.ko`, `nft_quota.ko`, `nft_redir.ko`, `nft_reject*.ko` | `kmod-nft-core` | Стандартные правила и выражения Nftables. | ⚪ **Не используется** |
| `nft_nat.ko`, `nft_masq.ko` | `kmod-nft-nat` | Трансляция сетевых адресов Nftables NAT. | ⚪ **Не используется** |
| `nft_dup_netdev.ko`, `nft_fwd_netdev.ko` | `kmod-nft-netdev` | Пересылка пакетов на сетевом уровне `netdev`. | ⚪ **Не используется** |
| `nft_flow_offload.ko`, `nf_flow_table_inet.ko`, `nf_flow_table_ipv4.ko`, `nf_flow_table_ipv6.ko` | `kmod-nft-offload` | Программный софтверный Flow Offload Nftables. | ⚪ **Не используется** |

> [!NOTE]
> Наша сборка использует классический стек **Firewall3 (iptables-legacy)** с прямым кремниевым ускорением **Qualcomm PPE / NSS ECM**. Стек Nftables не используется и не требуется.

---

### ⏸️ Категория 9: ARPtables — 3 модуля

| Модуль `.ko` | Вендорный пакет | Описание функционала | Необходимость |
| :--- | :--- | :--- | :---: |
| `arp_tables.ko` | `kmod-arptables` | Ядро фильтрации ARP-пакетов на канальном уровне. | ⚪ **Низкая** |
| `arptable_filter.ko`| `kmod-arptables` | Таблица `filter` для фильтрации ARP-запросов и ответов. | ⚪ **Низкая** |
| `arpt_mangle.ko` | `kmod-arptables` | Модификация ARP-заголовков (подмена MAC/IP в ARP ответах). | ⚪ **Низкая** |

---

### ❌ Категория 10: Проприетарные вендорные модули Xiaomi / MiWiFi — 15 модулей

| Модуль `.ko` | Вендорный пакет | Описание функционала | Необходимость |
| :--- | :--- | :--- | :---: |
| `miwifi-xtcounter.ko` | `kmod-miwifi-xtcounter` | Сбор детальной статистики трафика по устройствам для облака Mi Home. | ❌ **Нулевая (Мусор)** |
| `miwifi-xthostlog.ko` | `kmod-miwifi-xthostlog` | Логирование сетевой активности хостов для китайского приложения. | ❌ **Нулевая (Мусор)** |
| `miwifi-xthostset.ko` | `kmod-miwifi-xthostset` | Управление списками устройств MiWiFi. | ❌ **Нулевая (Мусор)** |
| `connattr-haohan.ko` | `kmod-connattr-haohan` | Атрибуты соединений для интеграции с сервисами Haohan/DPI. | ❌ **Нулевая (Мусор)** |
| `connattr-label.ko` | `kmod-connattr-label` | Маркировка пакетов для родительского контроля Xiaomi. | ❌ **Нулевая (Мусор)** |
| `connattr-statistic.ko` | `kmod-connattr-statistic` | Статистика соединений для мобильного приложения MiWiFi. | ❌ **Нулевая (Мусор)** |
| `conntrack-attr.ko` | `kmod-conntrack-attr` | Расширенные вендорные атрибуты conntrack. | ❌ **Нулевая (Мусор)** |
| `enid.ko` | `kmod-enid` | Генератор уникальных идентификаторов устройств экосистемы Xiaomi. | ❌ **Нулевая (Мусор)** |
| `ip_account.ko` | `kmod-ipaccount2` | Учет трафика стоковой прошивки. | ❌ **Нулевая (Мусор)** |
| `local_gw_security.ko` | `kmod-local_gw_security` | Закрытый модуль встроенной безопасности Xiaomi. | ❌ **Нулевая (Мусор)** |
| `wan_check.ko` | `wan_check_v2` | Стоковая проверка наличия интернета на WAN порту. | ❌ **Нулевая (Мусор)** |
| `wandt_filter.ko` | `port_service_wandt` | Фильтрация сервисных портов стоковой прошивки на WAN. | ❌ **Нулевая (Мусор)** |
| `xt_IP4MARK.ko` | `kmod-ipt-ip4mark` | Вендорный маркер IPv4 пакетов. | ❌ **Нулевая (Мусор)** |
| `xt_flowMARK.ko` | `kmod-ipt-flowMARK` | Вендорная маркировка потоков трафика. | ❌ **Нулевая (Мусор)** |
| `xt_cgroup_MARK.ko` | `kmod-ipt-cgroup_MARK` | Вендорная маркировка cgroup трафика. | ❌ **Нулевая (Мусор)** |

> [!CAUTION]
> Все эти модули представляют собой закрытый вендорный код для облачных сервисов Xiaomi, телеметрии и мобильного приложения Mi Home. В стандартном окружении OpenWrt 24 они бесполезны и исключены из сборки.

---

### ❌ Категория 11: Тестовые, отладочные и вспомогательные модули — 15 модулей

| Модуль `.ko` | Вендорный пакет | Описание функционала | Необходимость |
| :--- | :--- | :--- | :---: |
| `mtd_*test.ko` (8 шт.) | `kmod-mtdtests` | Набор стресс-тестов flash-памяти MTD (`nandecctest`, `oobtest`, `pagetest`, `readtest`, `speedtest`, `stresstest`, `subpagetest`, `torturetest`). | ❌ **Нулевая (Тесты)** |
| `diagchar.ko` | `kmod-diag-char` | Отладочный символьный интерфейс Qualcomm DIAG (для связи с Qualcomm QPST / QXDM). | ❌ **Нулевая (Отладка)** |
| `button-hotplug.ko` | `kmod-button-hotplug` | Устаревший обработчик кнопок (заменен на `gpio-button-hotplug.ko`). | ❌ **Нулевая (Дубликат)** |
| `input-core.ko` | `kmod-input-core` | Ядро подсистемы ввода Linux (клавиатуры/джойстики). | ❌ **Нулевая** |
| `md5.ko` | `kmod-crypto-md5` | Хеширование MD5 (уже встроено в криптоядро). | ❌ **Нулевая** |
| `qca-nss-nsm.ko` | `kmod-qca-nss-nsm` | Network Service Manager NSS (отладочный модуль). | ❌ **Нулевая** |
| `ecm-wifi-plugin.ko` | `kmod-qca-nss-ecm-wifi-plugin` | Плагин интеграции ECM ускорения для Wi-Fi Direct Connect. | 🟡 **Потребуется на этапе Wi-Fi** |
| `compat_xtables.ko` | `kmod-ipt-compat-xtables` | Слой совместимости xtables. | ❌ **Нулевая** |
| `nfnlq-extension.ko` | `kmod-nfnlq-extension` | Расширение netlink queue. | ❌ **Нулевая** |

---

## 5. Рекомендации по интеграции модулей в сборку

Для расширения возможностей роутера и подготовки к установке прикладных пакетов рекомендуется добавить в `vendor_scripts/packages.list` следующие модули ядра:

1. **Пакет `kmod-ipt-ipset`** (`ip_set.ko`, `ip_set_hash_*.ko`, `xt_set.ko`):
   * Позволит мгновенно запускать списки обхода блокировок и маршрутизацию по базам IP.
2. **Пакет `kmod-ipt-tproxy`** (`xt_TPROXY.ko`, `xt_socket.ko`, `nf_tproxy_*.ko`, `nf_socket_*.ko`):
   * Позволит запускать прозрачные прокси-клиенты (sing-box, Xray, Clash).
3. **Пакет `kmod-ipt-nfqueue`** (`xt_NFQUEUE.ko`):
   * Необходим для работы утилит обхода DPI (`zapret`, `nfqws`, `tpws`).
4. **Пакет `kmod-fs-ext4`** + **`kmod-nls-utf8`** (`ext4.ko`, `jbd2.ko`, `mbcache.ko`, `nls_utf8.ko`):
   * Позволит монтировать образы EXT4 и подключать внешние накопители.
5. **Пакеты `kmod-sched` + `kmod-sched-core`** (`sch_htb.ko`, `sch_sfq.ko`, `cls_u32.ko`, `cls_fw.ko`):
   * Позволят использовать `luci-app-sqm` для шейпинга трафика и контроля задержек.
