#!/usr/bin/env python3
"""
compare_kernels.py — Анализ и сравнение собранного и стокового ядра Linux 5.4.213
Xiaomi Router BE3600 (RD15, IPQ5332)

Использование:
  python3 compare_kernels.py --config      # сравнение конфигураций
  python3 compare_kernels.py --xor-diff    # байтовый XOR-diff двух Image
  python3 compare_kernels.py --functions   # маппинг регионов на функции
  python3 compare_kernels.py --disasm      # дизассемблирование изменённых функций
  python3 compare_kernels.py --full        # полный анализ + отчёт
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

# ─── Пути по умолчанию ───────────────────────────────────────────────────────

OPENWRT = Path(__file__).resolve().parent.parent
BUILD_TARGET = OPENWRT / "build_dir/target-arm_cortex-a7+neon-vfpv4_musl_eabi/linux-ipq53xx_rd15/linux-5.4.213"
TOOLCHAIN = OPENWRT / "staging_dir/toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel/bin"

OUR_VMLINUX  = BUILD_TARGET / "vmlinux"
OUR_IMAGE    = BUILD_TARGET / "arch/arm/boot/Image"
OUR_CONFIG   = BUILD_TARGET / ".config"

VENDOR_DIR   = OPENWRT / "vendor_scripts/kernel_diff"
VENDOR_IMAGE = VENDOR_DIR / "vendor_Image"
VENDOR_CONFIG= VENDOR_DIR / "config-5.4.vendor"

OUT_DIR      = VENDOR_DIR

# Адрес загрузки ядра в памяти
OUR_LOAD_ADDR    = 0x80008000  # наш vmlinux (ELF load addr)
VENDOR_LOAD_ADDR = 0x40008000  # стоковый Image (из FIT заголовка)

OBJDUMP = TOOLCHAIN / "arm-openwrt-linux-muslgnueabi-objdump"
NM      = TOOLCHAIN / "arm-openwrt-linux-muslgnueabi-nm"

# ─── Утилиты ─────────────────────────────────────────────────────────────────

def log(msg):
    print(f"[*] {msg}", flush=True)

def err(msg):
    print(f"[!] {msg}", file=sys.stderr, flush=True)

def check_files():
    missing = []
    for p, name in [(OUR_VMLINUX, "vmlinux"), (OUR_IMAGE, "наш Image"),
                    (VENDOR_IMAGE, "vendor_Image")]:
        if not p.exists():
            missing.append(f"  {p}  ({name})")
    if missing:
        err("Не найдены необходимые файлы:")
        for m in missing:
            err(m)
        sys.exit(1)

# ─── Фаза 1: Сравнение конфигураций ──────────────────────────────────────────

def parse_config(text):
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        m = re.match(r'#\s*(CONFIG_\S+)\s+is not set', line)
        if m:
            result[m.group(1)] = 'n'
        elif line.startswith('#'):
            continue
        elif '=' in line:
            k, v = line.split('=', 1)
            result[k.strip()] = v.strip()
    return result

def phase_config():
    log("Фаза 1: Сравнение конфигураций")

    if not OUR_CONFIG.exists():
        err(f"Наш .config не найден: {OUR_CONFIG}")
        return None, None, None

    vendor = parse_config(VENDOR_CONFIG.read_text(errors='ignore'))
    ours   = parse_config(OUR_CONFIG.read_text(errors='ignore'))

    only_vendor  = {k: v for k, v in vendor.items() if k not in ours}
    only_ours    = {k: v for k, v in ours.items()   if k not in vendor}
    different    = {k: (vendor[k], ours[k]) for k in vendor
                    if k in ours and vendor[k] != ours[k]}

    out_path = OUT_DIR / "config_diff.txt"
    lines = []
    lines.append(f"# Сравнение конфигураций ядра 5.4.213\n")
    lines.append(f"# Всего в vendor: {len(vendor)}, в нашем: {len(ours)}\n\n")

    lines.append(f"## Только в vendor ({len(only_vendor)} опций):\n")
    for k, v in sorted(only_vendor.items()):
        lines.append(f"+VENDOR  {k}={v}\n")

    lines.append(f"\n## Только в нашем ({len(only_ours)} опций):\n")
    for k, v in sorted(only_ours.items()):
        lines.append(f"+OURS    {k}={v}\n")

    lines.append(f"\n## Разные значения ({len(different)} опций):\n")
    for k, (vv, ov) in sorted(different.items()):
        lines.append(f"DIFF     {k}: vendor={vv}  ours={ov}\n")

    out_path.write_text("".join(lines))
    log(f"  Только в vendor: {len(only_vendor)}")
    log(f"  Только у нас:    {len(only_ours)}")
    log(f"  Разные значения: {len(different)}")
    log(f"  Результат: {out_path}")
    return only_vendor, only_ours, different

# ─── Фаза 2: Байтовый XOR-diff ───────────────────────────────────────────────

def phase_xor_diff(min_region=4):
    """
    Побайтово XOR-ует оба Image (выровненных по началу файла).
    Адреса в памяти:
      наш Image:    offset + OUR_LOAD_ADDR
      vendor_Image: offset + VENDOR_LOAD_ADDR
    Нас интересует смещение offset → адрес в нашем ядре = offset + OUR_LOAD_ADDR
    """
    log("Фаза 2: Байтовый XOR-diff (наш Image vs vendor_Image)")

    our_data    = OUR_IMAGE.read_bytes()
    vendor_data = VENDOR_IMAGE.read_bytes()

    size = min(len(our_data), len(vendor_data))
    log(f"  Наш Image:    {len(our_data):,} байт")
    log(f"  Vendor Image: {len(vendor_data):,} байт")
    log(f"  Сравниваем:   {size:,} байт")

    # Ищем непрерывные регионы различий
    regions = []
    in_diff   = False
    reg_start = 0
    changed   = 0

    our_view    = memoryview(our_data)
    vendor_view = memoryview(vendor_data)

    for i in range(size):
        diff = our_view[i] != vendor_view[i]
        if diff and not in_diff:
            in_diff   = True
            reg_start = i
            changed   = 1
        elif diff and in_diff:
            changed += 1
        elif not diff and in_diff:
            if changed >= min_region:
                regions.append([reg_start, i, changed])
            in_diff = False
            changed = 0
    if in_diff and changed >= min_region:
        regions.append([reg_start, size, changed])

    # Объединяем близкие регионы (gap < 64 байт)
    merged = []
    for r in regions:
        if merged and r[0] - merged[-1][1] < 64:
            prev = merged[-1]
            merged[-1] = [prev[0], r[1], prev[2] + r[2]]
        else:
            merged.append(r)

    log(f"  Найдено регионов различий: {len(merged)}")
    total_changed = sum(r[2] for r in merged)
    log(f"  Всего изменённых байт: {total_changed:,}")

    out_path = OUT_DIR / "xor_regions.txt"
    lines = ["# XOR-diff: наш Image vs vendor_Image\n",
             "# file_offset  vendor_addr  our_addr  size  changed_bytes\n\n"]
    for reg_start, reg_end, changed_b in merged:
        size_r = reg_end - reg_start
        vendor_addr = VENDOR_LOAD_ADDR + reg_start
        our_addr    = OUR_LOAD_ADDR    + reg_start
        lines.append(f"0x{reg_start:08x}  0x{vendor_addr:08x}  0x{our_addr:08x}"
                     f"  size={size_r:6d}  changed={changed_b:6d}\n")
    out_path.write_text("".join(lines))
    log(f"  Результат: {out_path}")
    return merged

# ─── Фаза 3: Маппинг регионов на функции через nm ────────────────────────────

def load_nm_symbols():
    """Запускает nm на нашем vmlinux, возвращает отсортированный список (addr, type, name)."""
    log("  Загружаем таблицу символов из vmlinux (nm)...")
    result = subprocess.run(
        [str(NM), "-n", "--defined-only", str(OUR_VMLINUX)],
        capture_output=True, text=True, timeout=180
    )
    symbols = []
    for line in result.stdout.splitlines():
        parts = line.split(None, 2)
        if len(parts) != 3:
            continue
        try:
            addr = int(parts[0], 16)
            sym_type = parts[1]
            name = parts[2]
            symbols.append((addr, sym_type, name))
        except ValueError:
            continue
    log(f"  Загружено {len(symbols):,} символов")
    return symbols

def phase_functions(xor_regions, symbols):
    log("Фаза 3: Маппинг регионов на функции (nm vmlinux)")

    # Только текстовые/функциональные символы
    func_syms = [(a, t, n) for a, t, n in symbols if t in ('T', 't', 'W', 'w')]
    func_syms.sort(key=lambda x: x[0])

    changed_funcs = {}  # name -> dict

    for reg_start, reg_end, changed_b in xor_regions:
        our_start = OUR_LOAD_ADDR + reg_start
        our_end   = OUR_LOAD_ADDR + reg_end

        # Бинарный поиск первого символа <= our_start
        lo, hi = 0, len(func_syms) - 1
        idx = 0
        while lo <= hi:
            mid = (lo + hi) // 2
            if func_syms[mid][0] <= our_start:
                idx = mid
                lo = mid + 1
            else:
                hi = mid - 1

        # Перебираем символы вокруг, которые могут перекрывать регион
        for i in range(max(0, idx - 1), min(len(func_syms), idx + 10)):
            addr, sym_type, name = func_syms[i]
            next_addr = func_syms[i+1][0] if i+1 < len(func_syms) else addr + 4096
            # Перекрытие?
            if addr < our_end and next_addr > our_start:
                if name not in changed_funcs:
                    changed_funcs[name] = {
                        'addr_our':    addr,
                        'addr_vendor': addr - OUR_LOAD_ADDR + VENDOR_LOAD_ADDR,
                        'size':        next_addr - addr,
                        'changed_b':   0,
                        'regions':     []
                    }
                changed_funcs[name]['changed_b'] += changed_b
                changed_funcs[name]['regions'].append((reg_start, reg_end, changed_b))

    log(f"  Изменённых функций: {len(changed_funcs)}")

    out_path = OUT_DIR / "changed_functions.txt"
    lines = [f"# Функции с отличиями между нашим и стоковым ядром\n",
             f"# Всего: {len(changed_funcs)}\n\n"]
    for name, info in sorted(changed_funcs.items(), key=lambda x: x[1]['addr_our']):
        lines.append(f"{'─'*60}\n")
        lines.append(f"FUNC: {name}\n")
        lines.append(f"  our_addr:    0x{info['addr_our']:08x}\n")
        lines.append(f"  vendor_addr: 0x{info['addr_vendor']:08x}\n")
        lines.append(f"  size:        {info['size']} байт\n")
        lines.append(f"  changed_b:   {info['changed_b']} байт\n")
    out_path.write_text("".join(lines))
    log(f"  Результат: {out_path}")
    return changed_funcs

# ─── Фаза 4: Дизассемблирование изменённых функций ───────────────────────────

def disasm_our(addr_start, addr_end):
    """Дизассемблирует диапазон из нашего vmlinux (ELF с символами)."""
    result = subprocess.run(
        [str(OBJDUMP), "-d",
         f"--start-address=0x{addr_start:x}",
         f"--stop-address=0x{addr_end:x}",
         str(OUR_VMLINUX)],
        capture_output=True, text=True, timeout=60
    )
    return result.stdout

def disasm_vendor(addr_start, size):
    """Дизассемблирует диапазон из vendor_Image (raw binary)."""
    if addr_start < VENDOR_LOAD_ADDR:
        return ""
    result = subprocess.run(
        [str(OBJDUMP), "--target=binary", "--architecture=arm",
         f"--adjust-vma=0x{VENDOR_LOAD_ADDR:x}",
         "--disassemble-all",
         f"--start-address=0x{addr_start:x}",
         f"--stop-address=0x{addr_start + size:x}",
         str(VENDOR_IMAGE)],
        capture_output=True, text=True, timeout=60
    )
    return result.stdout

def normalize_asm(text):
    """Нормализует вывод objdump: убирает адреса строк и абсолютные операнды."""
    lines = []
    for line in text.splitlines():
        # Убираем leading address: "80100024:  e3..."
        line = re.sub(r'^\s*[0-9a-f]{7,}:\s*', '', line)
        # Нормализуем абсолютные адреса в операндах
        line = re.sub(r'0x[0-9a-f]{6,8}\b', '0xADDR', line)
        lines.append(line)
    return "\n".join(lines)

def phase_disasm(changed_funcs, max_funcs=50):
    log(f"Фаза 4: Дизассемблирование (первые {max_funcs} функций по убыванию изменений)")

    disasm_dir = OUT_DIR / "disasm_diff"
    disasm_dir.mkdir(exist_ok=True)

    # Сортируем по количеству изменённых байт (самые интересные — первыми)
    sorted_funcs = sorted(changed_funcs.items(),
                          key=lambda x: x[1]['changed_b'], reverse=True)

    results = {}
    import difflib

    for idx, (name, info) in enumerate(sorted_funcs[:max_funcs]):
        addr_our    = info['addr_our']
        addr_vendor = info['addr_vendor']
        size        = min(info['size'], 16384)  # ограничение 16 КБ

        our_asm    = disasm_our(addr_our, addr_our + size)
        vendor_asm = disasm_vendor(addr_vendor, size)

        our_norm    = normalize_asm(our_asm)
        vendor_norm = normalize_asm(vendor_asm)

        diff_lines = list(difflib.unified_diff(
            our_norm.splitlines(), vendor_norm.splitlines(),
            fromfile="ours", tofile="vendor", lineterm=""
        ))
        has_diff = any(
            l.startswith('+') or l.startswith('-')
            for l in diff_lines
            if not l.startswith('+++') and not l.startswith('---')
        )

        safe_name = re.sub(r'[^\w.-]', '_', name)[:80]
        out_file  = disasm_dir / f"{idx+1:03d}_{safe_name}.diff"
        content   = [
            f"# Функция: {name}\n",
            f"# Адрес (наш):    0x{addr_our:08x}\n",
            f"# Адрес (vendor): 0x{addr_vendor:08x}\n",
            f"# Размер:         {size} байт\n",
            f"# Изменённых байт:{info['changed_b']}\n",
            f"# Реальный diff:  {'да' if has_diff else 'нет (только смещения адресов)'}\n",
            f"{'─'*70}\n\n",
            "## НАША ВЕРСИЯ:\n",
            our_asm or "(пусто)\n",
            f"\n{'─'*70}\n\n",
            "## СТОКОВАЯ ВЕРСИЯ (vendor):\n",
            vendor_asm or "(пусто)\n",
            f"\n{'─'*70}\n\n",
            "## DIFF (нормализованный, без абсолютных адресов):\n",
            "\n".join(diff_lines) if diff_lines else "(идентично)\n"
        ]
        out_file.write_text("".join(content))
        results[name] = has_diff

        if (idx + 1) % 10 == 0:
            log(f"  [{idx+1}/{min(len(changed_funcs), max_funcs)}] обработано")

    real_diff_count = sum(1 for v in results.values() if v)
    log(f"  Функций с реальным diff кода: {real_diff_count} из {len(results)}")
    log(f"  Дизассемблер: {disasm_dir}")
    return results

# ─── Генерация итогового отчёта ───────────────────────────────────────────────

def generate_report(config_diff, xor_regions, changed_funcs, disasm_results):
    log("Генерация итогового отчёта...")

    only_vendor = config_diff[0] if config_diff else {}
    meaningful  = {k: v for k, v in only_vendor.items() if v != 'n' and 'CC_' not in k}
    trivial     = {k: v for k, v in only_vendor.items() if v == 'n' or 'CC_' in k}
    real_diff   = {n: i for n, i in changed_funcs.items()
                   if disasm_results and disasm_results.get(n)}

    flag_desc = {
        "CONFIG_BRIDGE_NETFILTER_DMZ_LOOPBACK": "Hairpin NAT через loopback для br_netfilter",
        "CONFIG_MIWIFI_CONNTRACK_ACCT_HOOK":    "Хук учёта трафика в nf_conntrack",
        "CONFIG_MIWIFI_CONNTRACK_HOOK":          "Хук событий nf_conntrack",
        "CONFIG_MIWIFI_NFNL_QUEUE_EXTENSION":   "Расширение NFNETLINK_QUEUE",
        "CONFIG_MIWIFI_SKB_MARK":               "Маркировка SKB (уже есть kmod-miwifi-skb-mark-vendor)",
    }

    import datetime
    lines = [
        "# Анализ патчей стокового ядра Xiaomi RD15 vs QSDK 12.4\n\n",
        f"**Дата**: {datetime.date.today()}\n\n",
        "## 1. Сводка результатов\n\n",
        "| Параметр | Значение |\n|---|---|\n",
        f"| Всего различий в конфиге | {len(only_vendor)} |\n",
        f"| Содержательных патч-флагов | {len(meaningful)} |\n",
        f"| Регионов бинарных отличий | {len(xor_regions) if xor_regions else 'N/A'} |\n",
        f"| Затронутых функций ядра | {len(changed_funcs)} |\n",
        f"| Функций с реальным diff | {len(real_diff)} |\n",
        "\n## 2. Патчи стокового ядра (по CONFIG-флагам)\n\n",
        "### 2.1 Содержательные патчи\n\n",
        "| Флаг | Описание |\n|---|---|\n",
    ]
    for k, v in sorted(meaningful.items()):
        desc = flag_desc.get(k, "—")
        lines.append(f"| `{k}` | {desc} |\n")

    if trivial:
        lines.append("\n### 2.2 Технические/автоматические флаги\n\n")
        for k, v in sorted(trivial.items()):
            lines.append(f"- `{k}={v}`\n")

    lines.append("\n## 3. Изменённые функции ядра\n\n")
    lines.append("Функции с наибольшим количеством изменённых байт "
                 "(топ 20, сортировка по `changed_b`):\n\n")
    lines.append("| # | Функция | vendor_addr | size | changed_b | real_diff |\n"
                 "|---|---|---|---|---|---|\n")
    top = sorted(changed_funcs.items(), key=lambda x: x[1]['changed_b'], reverse=True)[:20]
    for i, (name, info) in enumerate(top, 1):
        rd = "✅" if real_diff.get(name) else "—"
        lines.append(f"| {i} | `{name}` | `0x{info['addr_vendor']:08x}` | "
                     f"{info['size']} | {info['changed_b']} | {rd} |\n")

    lines.append("\n## 4. Следующие шаги\n\n"
                 "1. **Получить исходники патчей** — искать в GPL-архиве Xiaomi BE3600 "
                 "или в QSDK QCA open-source репозиториях.\n"
                 "2. **Написать 4-5 патчей** в `target/linux/ipq53xx/rd15/patches-5.4/` "
                 "для каждого `CONFIG_MIWIFI_*` и `CONFIG_BRIDGE_NETFILTER_DMZ_LOOPBACK`.\n"
                 "3. **Проверить** через повторный XOR-diff после сборки — diff должен "
                 "сократиться до нуля.\n"
                 "4. **Подробный дизассемблер** в "
                 "`vendor_scripts/kernel_diff/disasm_diff/` — по файлу на функцию.\n")

    report_path = OUT_DIR / "kernel_analysis_report.md"
    report_path.write_text("".join(lines))
    log(f"Отчёт: {report_path}")
    return report_path

# ─── Точка входа ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Сравнение собранного и стокового ядра Xiaomi RD15"
    )
    parser.add_argument("--config",    action="store_true", help="Фаза 1: сравнение конфигов")
    parser.add_argument("--xor-diff",  action="store_true", help="Фаза 2: XOR-diff Image")
    parser.add_argument("--functions", action="store_true", help="Фаза 3: маппинг на функции")
    parser.add_argument("--disasm",    action="store_true", help="Фаза 4: дизассемблирование")
    parser.add_argument("--full",      action="store_true", help="Все фазы + отчёт")
    parser.add_argument("--max-funcs", type=int, default=50,
                        help="Макс. функций для дизассемблирования (default: 50)")
    args = parser.parse_args()

    if not any([args.config, args.xor_diff, args.functions, args.disasm, args.full]):
        parser.print_help()
        sys.exit(0)

    OUT_DIR.mkdir(exist_ok=True)
    check_files()

    do_all = args.full
    config_diff = xor_regions = changed_funcs = symbols = disasm_results = None

    if do_all or args.config:
        config_diff = phase_config()

    if do_all or args.xor_diff or args.functions or args.disasm:
        xor_regions = phase_xor_diff()

    if do_all or args.functions or args.disasm:
        symbols = load_nm_symbols()
        if xor_regions and symbols:
            changed_funcs = phase_functions(xor_regions, symbols)

    if do_all or args.disasm:
        if changed_funcs:
            disasm_results = phase_disasm(changed_funcs, max_funcs=args.max_funcs)
        else:
            err("Нет данных для дизассемблирования (сначала --xor-diff + --functions)")

    if do_all:
        generate_report(config_diff, xor_regions or [], changed_funcs or {}, disasm_results or {})

    log("Готово.")

if __name__ == "__main__":
    main()
