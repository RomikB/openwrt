# Переход с firewall (firewall3/iptables) на firewall4 (nftables) на ядре QSDK 5.4.213

## 1. Введение и контекст

В прошивке **Xiaomi Router BE3600 (RD15)** (SoC Qualcomm IPQ5332, свитч Motorcomm YT9215S, ядро Linux 5.4.213 QSDK 12.4) по умолчанию используется классический межсетевой экран **`firewall3`** (`iptables` / `xtables`).

В OpenWrt 22.03+ и 24.x стандартом стал **`firewall4`** (`nftables` + `ucode`). В данном документе детально проанализирована техническая возможность перехода на `firewall4`, ограничения ядра 5.4, взаимодействие с аппаратным ускорителем Qualcomm PPE/ECM и составлен пошаговый план изменений.

---

## 2. Анализ совместимости: что БУДЕТ и что НЕ БУДЕТ работать

### ✅ Что БУДЕТ работать:
1. **Базовый межсетевой экран OpenWrt:**
   * Зонирование (`lan`, `wan`), стандартные политики `REJECT`, `DROP`, `ACCEPT`.
   * Правила переадресации портов (Port Forwarding / DNAT).
   * Маскарадинг (SNAT / Masquerade) и Redirect.
   * Контроль состояний (`ct state established,related,new,invalid`).
   * Ограничения трафика (`limit`, `quota`, `counter`).
2. **Аппаратный оффлоад Qualcomm PPE (Line Rate 2.5G):**
   * Модуль ядра `ecm.ko` (Enhanced Connection Manager) перехватывает сетевые потоки не через утилиты фаервола, а через низкоуровневые хуки ядра Linux:
     * `NF_INET_POST_ROUTING` (приоритет `NF_IP_PRI_NAT_SRC + 1`).
     * `nf_conntrack` (таблица сессий соединений).
   * Поскольку и `iptables`, и `nftables` используют одну и ту же системную подсистему `nf_conntrack` ядра Linux, **ECM одинаково успешно видит и транслирует сессии в аппаратные таблицы PPE**.
3. **Коммутатор Motorcomm YT9215S (`yt_switch.ko`, `yt_phy_module.ko`):**
   * Свитч работает на уровне L2 и связывается с SoC через сетевые интерфейсы `eth0`/`eth1`. Он не завязан на подсистему пакетной фильтрации и не требует никаких изменений.
4. **Проприетарные демоны Qualcomm/Xiaomi:**
   * В бинарных файлах (`hostapd`, `cnssdaemon`, `ssdk_sh`, `switch_ctl`, `nvram`) **нет жестко зашитых вызовов `iptables`**.

---

### ⚠️ Ограничения ядра 5.4 (что НЕ БУДЕТ работать или требует внимания):
1. **Программный Flow Offloading (`flowtable`):**
   * ❌ **НЕЛЬЗЯ включать** опцию `option flow_offloading '1'` в `/etc/config/firewall`.
   * *Причина:* Программный `flowtable` в `firewall4` забирает пакеты на сетевом `ingress` (до стека Netfilter) и пересылает их программно силами CPU. В результате пакеты не доходят до точки `POST_ROUTING`, где их должен перехватить `ecm.ko` для отправки в аппаратный ускоритель PPE.
   * *Решение:* Опции `flow_offloading` и `flow_offloading_hw` в `/etc/config/firewall` должны быть выключены (`0`). Аппаратным ускорением полностью и гораздо эффективнее управляет Qualcomm PPE/ECM.
2. **Конкатенация диапазонов сетей (PIPAPO Set Backend):**
   * ❌ В ядре 5.4 отсутствует модуль `nft_set_pipapo.c` (появился в ядре 5.6).
   * *Следствие:* В `ipset` нельзя использовать составные интервалы (например, одновременный диапазон `подсеть /24` + `диапазон портов`). Обычные сеты (списки IP, списки MAC, диапазоны портов по отдельности) работают без проблем.
3. **Хук моста для ECM:**
   * Скрипт `/etc/firewall.d/qca-nss-ecm` использовал вызов `iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT`. Для `firewall4` требуется его аналог в `/etc/nftables.d/`.

---

## 3. Сравнение архитектур (firewall3 vs firewall4)

```
+-----------------------------------------------------------------------------------+
|                                 ТЕКУЩЕЕ СОСТОЯНИЕ (firewall3)                     |
|                                                                                   |
|  /etc/config/firewall ---> fw3 (C binary) ---> iptables/xtables                   |
|                                                    │                              |
|                                                    ▼                              |
|                                  Linux Kernel Netfilter (xt_*)                    |
|                                                    │                              |
|                                                    ▼ (nf_conntrack)               |
|                                         ecm.ko (Post-Routing)                     |
|                                                    │                              |
|                                                    ▼                              |
|                                        Qualcomm PPE (Hardware)                    |
+-----------------------------------------------------------------------------------+

+-----------------------------------------------------------------------------------+
|                                 ЦЕЛЕВОЕ СОСТОЯНИЕ (firewall4)                     |
|                                                                                   |
|  /etc/config/firewall ---> fw4 (ucode) ---> nftables 1.1.x (nft)                  |
|                                                    │                              |
|                                                    ▼                              |
|                                  Linux Kernel Netfilter (nft_*)                   |
|                                                    │                              |
|                                                    ▼ (nf_conntrack)               |
|                                         ecm.ko (Post-Routing)                     |
|                                                    │                              |
|                                                    ▼                              |
|                                        Qualcomm PPE (Hardware)                    |
+-----------------------------------------------------------------------------------+
```

---

## 4. Влияние на системные ресурсы: оперативная память (RAM) и Flash

Экспериментальные замеры на физическом оборудовании (Xiaomi BE3600 / RD15) показали, что замена `firewall3` на `firewall4` приводит к заметному росту потребления как оперативной памяти, так и дискового пространства:

### 4.1. Потребление оперативной памяти (RAM: +2.0 ... +2.5 МБ)
Свободная память (`MemAvailable`) снижается в среднем на **2.0–2.8 МБ** (с ~50 МБ до ~47.5 МБ в базовом состоянии системы). Данный оверхед складывается из трёх факторов:
1. **Код модулей ядра в RAM (`vmalloc`: +450–570 КБ):**
   * Вместо нескольких базовых модулей `iptables` в ядро загружается модульный стек `nftables`: `nf_tables.ko` (102 КБ) и **25 вспомогательных модулей** (`nft_counter`, `nft_chain_nat`, `nft_fib`, `nft_ct`, `nft_limit`, `nft_masq`, `nf_flow_table_*` и др.).
2. **Объектные структуры правил в SLUB-кэше ядра (+300–500 КБ):**
   * В отличие от плоского компактного бинарного массива `iptables`, в `nftables` каждое правило — это иерархический объект (`struct nft_rule`, `struct nft_expr`).
   * Для правил с подсчетом трафика выделяются счетчики **`nft_counter_percpu`**. На 4-ядерном процессоре IPQ5332 структуры счетчиков аллоцируются **раздельно для каждого из 4 ядер CPU**, кратно умножая накладные расходы SLAB.
3. **Userland-библиотеки и файловый кэш (+1.0–1.5 МБ):**
   * Бинарник `fw3` занимал всего ~60 КБ на C и сразу завершал работу.
   * `firewall4` написан на интерпретаторе `ucode` и опирается на тяжелые библиотеки: `libnftables.so` (**690 КБ**), `libnftnl.so` (**138 КБ**) и структуры разбора JSON. При работе LuCI / `rpcd` эти библиотеки и динамические структуры постоянно удерживаются в страничном кэше RAM (`Cached`).

*Поведение при росте правил:*
* При типичном домашнем наборе правил (до 100–200 правил) дельта остается в пределах тех же **~2 МБ**.
* При использовании крупных списков адресов (AdBlock / Geoblocking / списки обхода на тысячи IP) нативные сеты `nftables` (`nft_set_hash`, `nft_set_rbtree`) начинают масштабироваться эффективнее классического `iptables` без `ipset`, работая по алгоритму $O(1)$.

### 4.2. Потребление дискового пространства (Flash / SquashFS: +500 ... +800 КБ)
При включении `firewall4` в корневую файловую систему добавляются:
* Разделяемые библиотеки: `libnftables.so.1.1.0` (690 КБ raw), `libnftnl.so` (138 КБ raw).
* Утилита управления: `/usr/sbin/nft` (~15 КБ).
* 25 модулей ядра `kmod-nft-*` (~350 КБ raw в каталоге `/lib/modules/5.4.213/`).
* Скрипты генерации правил: `/sbin/fw4`, `/usr/share/firewall4/` (~60 КБ).

В сжатом образе SquashFS (XZ) суммарное утяжеление прошивки составляет **~500–800 КБ**. Для раздела `ubi0` (где под системный ROM и overlay суммарно доступно всего ~38 МБ) это существенная величина, которую необходимо учитывать при формировании списка предустановленных пакетов.

---

## 5. Пошаговый план перехода на `firewall4`

Для перехода на `firewall4` потребуется внести изменения в 4 компонента проекта:

### Шаг 1. Включение модулей ядра в `target/linux/ipq53xx/rd15/config-5.4`
Для работы `firewall4` обязателен пакет `kmod-nft-fib`. Включаем поддержку FIB для IPv4 и IPv6:
```ini
CONFIG_NFT_FIB=m
CONFIG_NFT_FIB_INET=m
CONFIG_NFT_FIB_IPV4=m
CONFIG_NFT_FIB_IPV6=m
```
*(Также необходимо убедиться в наличии `CONFIG_NFT_NAT=m`, `CONFIG_NFT_MASQ=m`, `CONFIG_NFT_REJECT=m`, которые уже активированы в ядре).*

---

### Шаг 2. Переключение пакетов в `target/linux/ipq53xx/rd15/target.mk`
В списке `DEFAULT_PACKAGES`:
1. Убираем запрет `-firewall4 -nftables -kmod-nft-offload`.
2. Заменяем `firewall iptables-zz-legacy xtables-legacy` на `firewall4`.
3. Добавляем `iptables-nft` (позволит утилитам, скриптам или пакетам, всё ещё вызывающим `iptables`, прозрачно транслировать правила в `nftables`).
4. Заменяем зависимые расширения `kmod-ipt-*` на нативные эквиваленты или удаляем устаревшие.

*Было:*
```makefile
DEFAULT_PACKAGES += \
	-procd-ujail \
	-firewall4 -nftables -kmod-nft-offload \
	firewall iptables-zz-legacy xtables-legacy swconfig bridge ethtool ip-full block-mount nand-utils \
	...
	kmod-ipt-conntrack-extra kmod-ipt-raw kmod-ipt-ipopt \
	kmod-ipt-offload kmod-ipt-filter kmod-ipt-extra kmod-ipt-nat6 \
```

*Станет:*
```makefile
DEFAULT_PACKAGES += \
	-procd-ujail \
	firewall4 nftables iptables-nft swconfig bridge ethtool ip-full block-mount nand-utils \
	...
```

---

### Шаг 3. Адаптация хука ECM под `nftables` в `vendor_scripts/patch_package.py`
В составе пакета `kmod-qca-nss-ecm-premium-vendor` есть файл `/etc/firewall.d/qca-nss-ecm`. Механизм каталога `firewall.d` является специфичным для `firewall3`.

В скрипте `vendor_scripts/patch_package.py` для пакета `kmod-qca-nss-ecm-premium` добавляем генерацию хука для `firewall4` в `/etc/nftables.d/10-ecm.nft`:
```nft
chain ecm_forward {
	type filter hook forward priority filter - 1; policy accept;
	meta ibrname "br-lan" accept
}
```
Это гарантирует пропуск локального трафика моста между Wi-Fi и LAN без лишней фильтрации.

---

### Шаг 4. Настройка конфигурации по умолчанию (`/etc/config/firewall`)
В скрипте генерации или дефолтном конфиге фаервола убедиться, что:
```uci
set firewall.@defaults[0].flow_offloading='0'
set firewall.@defaults[0].flow_offloading_hw='0'
```
Это оставит управление ускорением за драйвером `ecm.ko` и аппаратным блоком PPE, исключив софтверный конфликт.

---

## 6. План тестирования и верификации после перехода

1. **Проверка компиляции:**
   ```bash
   make package/network/config/firewall4/compile -j$(nproc)
   make target/linux/compile -j$(nproc)
   ```
2. **Проверка запуска демона на устройстве:**
   ```bash
   /etc/init.d/firewall status
   fw4 print
   nft list ruleset
   ```
3. **Проверка работы аппаратного ускорения PPE/ECM:**
   Запуск `iperf3` через роутер между LAN (2.5G) и WAN:
   ```bash
   cat /sys/kernel/debug/ecm/ecm_db/connection_count
   # Проверка счетчиков PPE:
   cat /sys/kernel/debug/ppe/stats
   top # Нагрузка на CPU должна оставаться близкой к 0-1% при скорости 2.5 Gbps
   ```
4. **Проверка веб-интерфейса LuCI:**
   * Раздел **Network -> Firewall**: проверка корректного отображения и редактирования зон, правил проброса портов и NAT через интерфейс LuCI (пакет `luci-app-firewall` в OpenWrt 24 нативно поддерживает `firewall4`).

---

## 7. Резюме

Переход с `firewall3` на `firewall4` для Xiaomi BE3600 **полностью осуществим**:
* Он переводит устройство на современный стандарт OpenWrt 24.
* Не ломает аппаратное ускорение PPE при отключенном софтовом `flow_offload`.
* Не требует декомпиляции или изменения проприетарных бинарных драйверов Qualcomm/Motorcomm.
