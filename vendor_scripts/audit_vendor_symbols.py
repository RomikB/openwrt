#!/usr/bin/env python3
"""
audit_vendor_symbols.py — Комплексный аудит импортов/экспортов, версий символов (CRC)
и ABI-зависимостей бинарных модулей ядра (vendor_feed) от ядра Qualcomm QSDK 12.4 и патчей вендора.

Использование:
    python3 vendor_scripts/audit_vendor_symbols.py
    python3 vendor_scripts/audit_vendor_symbols.py --report tmp/vendor_symbol_audit.md
"""

import argparse
import glob
import os
import re
import struct
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

TOPDIR = Path(__file__).resolve().parent.parent
VENDOR_FEED = TOPDIR / "vendor_feed"
BUILD_DIR = TOPDIR / "build_dir" / "target-arm_cortex-a7+neon-vfpv4_musl_eabi"
KERNEL_BUILD_DIR = BUILD_DIR / "linux-ipq53xx_rd15" / "linux-5.4.213"
VMLINUX = KERNEL_BUILD_DIR / "vmlinux"
SYMVERS = KERNEL_BUILD_DIR / "Module.symvers"

TOOLCHAIN_BIN = TOPDIR / "staging_dir" / "toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel" / "bin"
CROSS_PREFIX = "arm-openwrt-linux-muslgnueabi-"


def get_tool(tool_name):
    cross = TOOLCHAIN_BIN / f"{CROSS_PREFIX}{tool_name}"
    if cross.exists():
        return str(cross)
    which = subprocess.run(["which", f"{CROSS_PREFIX}{tool_name}"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if which.returncode == 0:
        return which.stdout.decode().strip()
    return tool_name


NM = get_tool("nm")
READELF = get_tool("readelf")
OBJDUMP = get_tool("objdump")


def get_vermagic(ko_path):
    try:
        out = subprocess.check_output([READELF, "-p", ".modinfo", str(ko_path)], stderr=subprocess.DEVNULL).decode(errors="ignore")
        for line in out.splitlines():
            if "vermagic=" in line:
                return line.split("vermagic=")[1].strip()
    except Exception:
        pass
    return "UNKNOWN"


def extract_exports(ko_path):
    exports = set()
    try:
        out = subprocess.check_output([READELF, "-p", "__ksymtab_strings", str(ko_path)], stderr=subprocess.DEVNULL).decode(errors="ignore")
        for line in out.splitlines():
            if "]" in line:
                s = line.split("]")[-1].strip()
                if s:
                    exports.add(s)
    except Exception:
        pass

    if not exports:
        try:
            out = subprocess.check_output([NM, "-g", "--defined-only", str(ko_path)], stderr=subprocess.DEVNULL).decode(errors="ignore")
            for line in out.splitlines():
                parts = line.strip().split()
                if len(parts) >= 3 and parts[1] in ("T", "D", "B", "R", "G"):
                    if parts[2] not in ("init_module", "cleanup_module"):
                        exports.add(parts[2])
        except Exception:
            pass
    return exports


def extract_imports(ko_path):
    imports = set()
    try:
        out = subprocess.check_output([NM, "-u", str(ko_path)], stderr=subprocess.DEVNULL).decode(errors="ignore")
        for line in out.splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[0] == "U":
                imports.add(parts[1])
            elif len(parts) == 1:
                imports.add(parts[0])
    except Exception:
        pass
    return imports


def load_kernel_symbols():
    kernel_exports = set()
    symvers_crc = {}

    # 1. Из Module.symvers
    if SYMVERS.exists():
        with open(SYMVERS, "r", errors="ignore") as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 2:
                    crc = parts[0]
                    sym = parts[1]
                    kernel_exports.add(sym)
                    symvers_crc[sym] = crc

    # 2. Из vmlinux (глобальные экспорты)
    if VMLINUX.exists():
        try:
            out = subprocess.check_output([NM, "-g", "--defined-only", str(VMLINUX)], stderr=subprocess.DEVNULL).decode(errors="ignore")
            for line in out.splitlines():
                parts = line.split()
                if len(parts) >= 3 and parts[1] in ("T", "D", "R", "B"):
                    kernel_exports.add(parts[2])
        except Exception:
            pass

    return kernel_exports, symvers_crc


def load_openwrt_build_exports():
    """Собирает экспорты всех скомпилированных OpenWrt-пакетов модулей в build_dir."""
    extra_exports = {}
    for ko in BUILD_DIR.glob("**/*.ko"):
        if "linux-5.4.213" in str(ko):
            continue
        modname = ko.name
        exp = extract_exports(ko)
        if exp:
            extra_exports[modname] = exp
    return extra_exports


def disassemble_symbol_usage(ko_path, sym_name):
    """Находит контекст использования символа в модуле через objdump."""
    contexts = []
    try:
        out = subprocess.check_output([OBJDUMP, "-d", "-r", str(ko_path)], stderr=subprocess.DEVNULL).decode(errors="ignore")
        lines = out.splitlines()
        for i, line in enumerate(lines):
            if sym_name in line:
                start = max(0, i - 8)
                end = min(len(lines), i + 8)
                snippet = "\n".join(lines[start:end])
                contexts.append(snippet)
                if len(contexts) >= 3:
                    break
    except Exception:
        pass
    return contexts


def main():
    parser = argparse.ArgumentParser(description="Аудит символов vendor_feed против ядра QSDK 12.4")
    parser.add_argument("--report", default="tmp/vendor_symbol_audit.md", help="Путь для сохранения MD отчета")
    args = parser.parse_args()

    print("[*] Загрузка символов ядра Qualcomm QSDK 12.4...")
    kernel_exports, symvers_crc = load_kernel_symbols()
    print(f"    Символов ядра (vmlinux + Module.symvers): {len(kernel_exports):,}")

    print("[*] Поиск экспортов сторонних модулей OpenWrt (nat46, amneziawg и др.)...")
    openwrt_extra_exports = load_openwrt_build_exports()
    all_openwrt_exports = set()
    for exp in openwrt_extra_exports.values():
        all_openwrt_exports.update(exp)
    print(f"    Экспортов из скомпилированных пакетов OpenWrt: {len(all_openwrt_exports):,} (из {len(openwrt_extra_exports)} модулей)")

    print("[*] Сканирование бинарных модулей ядра в vendor_feed/...")
    vendor_ko_files = sorted(list(VENDOR_FEED.glob("**/*.ko")))
    print(f"    Найдено вендорных модулей: {len(vendor_ko_files)}")

    # Сбор экспортов и импортов вендорных модулей
    vendor_modules_info = {}
    all_vendor_exports = set()
    export_origin_map = {}

    for ko in vendor_ko_files:
        modname = ko.name
        vermagic = get_vermagic(ko)
        exports = extract_exports(ko)
        imports = extract_imports(ko)

        vendor_modules_info[modname] = {
            "path": ko,
            "vermagic": vermagic,
            "exports": exports,
            "imports": imports,
        }
        all_vendor_exports.update(exports)
        for exp in exports:
            export_origin_map[exp] = modname

    # Анализ разрешения символов для каждого модуля
    module_analysis = {}
    all_missing_symbols = defaultdict(list)
    resolved_stats = {"clean_kernel": 0, "openwrt_extra": 0, "vendor_inter": 0, "missing": 0}

    for modname, info in vendor_modules_info.items():
        imports = info["imports"]
        resolved_kernel = []
        resolved_openwrt = []
        resolved_vendor = []
        missing = []

        for imp in sorted(imports):
            if imp in kernel_exports:
                resolved_kernel.append(imp)
                resolved_stats["clean_kernel"] += 1
            elif imp in all_openwrt_exports:
                pkg_src = [k for k, v in openwrt_extra_exports.items() if imp in v]
                resolved_openwrt.append((imp, pkg_src[0] if pkg_src else "openwrt"))
                resolved_stats["openwrt_extra"] += 1
            elif imp in all_vendor_exports:
                src_mod = export_origin_map.get(imp, "other_vendor")
                resolved_vendor.append((imp, src_mod))
                resolved_stats["vendor_inter"] += 1
            else:
                missing.append(imp)
                all_missing_symbols[imp].append(modname)
                resolved_stats["missing"] += 1

        module_analysis[modname] = {
            "path": info["path"],
            "vermagic": info["vermagic"],
            "total_imports": len(imports),
            "total_exports": len(info["exports"]),
            "resolved_kernel": resolved_kernel,
            "resolved_openwrt": resolved_openwrt,
            "resolved_vendor": resolved_vendor,
            "missing": missing,
        }

    # Классификация по подсистемам
    subsystems = {
        "Wi-Fi 6/7 Direct Connect": ["umac.ko", "wifi_3_0.ko", "qca_ol.ko", "qdf.ko", "ipq_cnss2.ko", "monitor.ko", "mem_manager.ko", "ath_pktlog.ko"],
        "Ethernet Switch & PHY": ["yt_switch.ko", "yt_phy_module.ko"],
        "Qualcomm PPE & Acceleration": [
            "qca-nss-dp.ko", "qca-ssdk.ko", "qca-nss-ppe.ko", "qca-nss-ppe-vp.ko",
            "qca-nss-ppe-rule.ko", "qca-nss-ppe-bridge-mgr.ko", "qca-nss-ppe-vlan.ko",
            "qca-nss-ppe-pppoe-mgr.ko", "qca-nss-ppe-lag.ko", "qca-nss-ppe-ds.ko",
            "qca-nss-ppe-tun.ko", "qca-nss-ppe-vxlanmgr.ko", "qca-nss-sfe.ko"
        ],
        "Qualcomm ECM Offload": ["ecm.ko", "ecm_sfe_l2.ko", "ecm_ae_select.ko", "ecm-wifi-plugin.ko"],
        "Mesh & QoS Peripheral": ["emesh-sp.ko", "qca-mcs.ko"]
    }

    # Вывод результатов в консоль
    print("\n" + "=" * 90)
    print(f"{'Модуль (.ko)':<30} | {'Импортов':<8} | {'Экспортов':<9} | {'Статус разрешения символов'}")
    print("=" * 90)

    for sub_name, mod_list in subsystems.items():
        print(f"\n▼ {sub_name}:")
        for m in mod_list:
            if m not in module_analysis:
                continue
            data = module_analysis[m]
            tot_imp = data["total_imports"]
            tot_exp = data["total_exports"]
            miss = data["missing"]
            if not miss:
                status = "✅ 100% RESOLVED"
            else:
                status = f"⚠️ MISSING {len(miss)}: {', '.join(miss)}"
            print(f"  {m:<28} | {tot_imp:<8} | {tot_exp:<9} | {status}")

    print("\n" + "=" * 90)
    print("СВОДНЫЙ АНАЛИЗ НЕРАЗРЕШЕННЫХ СИМВОЛОВ (ПОТЕНЦИАЛЬНЫЕ ПАТЧИ ВЕНДОРА):")
    print("=" * 90)
    for sym, mods in all_missing_symbols.items():
        print(f"\n[!] Неразрешённый символ: '{sym}'")
        print(f"    Используется в модулях: {', '.join(mods)}")
        for m in mods:
            ko_p = vendor_modules_info[m]["path"]
            contexts = disassemble_symbol_usage(ko_p, sym)
            if contexts:
                print(f"    Анализ ассемблера в {m}:")
                for ctx in contexts[:1]:
                    for cline in ctx.splitlines()[:10]:
                        print(f"      {cline}")

    # Генерация Markdown отчета
    os.makedirs(os.path.dirname(os.path.abspath(args.report)), exist_ok=True)
    with open(args.report, "w", encoding="utf-8") as f:
        f.write("# Детальный отчет аудита символов и зависимостей vendor_feed от ядра QSDK 12.4\n\n")
        f.write("## 1. Сводные метрики анализа\n\n")
        f.write(f"- **Всего вендорных модулей ядра (`.ko`)**: {len(vendor_ko_files)}\n")
        f.write(f"- **Всего точек связывания (импортов символов)**: {sum(d['total_imports'] for d in module_analysis.values()):,}\n")
        f.write(f"- **Разрешено в чистом ядре QSDK 12.4 (`vmlinux` / `Module.symvers`)**: {resolved_stats['clean_kernel']:,} ({(resolved_stats['clean_kernel'] / sum(d['total_imports'] for d in module_analysis.values()) * 100):.2f}%)\n")
        f.write(f"- **Разрешено через открытые пакеты OpenWrt (`nat46`, `cfg80211`)**: {resolved_stats['openwrt_extra']:,}\n")
        f.write(f"- **Разрешено через межмодульные связи `vendor_feed`**: {resolved_stats['vendor_inter']:,}\n")
        f.write(f"- **Требуют вендорских хуков / заглушек**: {resolved_stats['missing']} символов ({len(all_missing_symbols)} уникальных)\n\n")

        f.write("## 2. Результаты по подсистемам\n\n")
        for sub_name, mod_list in subsystems.items():
            f.write(f"### {sub_name}\n\n")
            f.write("| Модуль | Импортов | Экспортов | Статус в QSDK 12.4 | Недостающие символы / Источник |\n")
            f.write("| :--- | :---: | :---: | :--- | :--- |\n")
            for m in mod_list:
                if m not in module_analysis:
                    continue
                d = module_analysis[m]
                miss_str = ", ".join(d["missing"]) if d["missing"] else "—"
                owrt_str = ", ".join([f"{sym} (`{pkg}`)" for sym, pkg in d["resolved_openwrt"]]) if d["resolved_openwrt"] else ""
                note = miss_str if d["missing"] else (f"Включает {owrt_str}" if owrt_str else "100% Clean QSDK Kernel")
                status = "✅ Совместим (100%)" if not d["missing"] else f"⚠️ Требует стаб ({len(d['missing'])})"
                f.write(f"| `{m}` | {d['total_imports']} | {d['total_exports']} | {status} | {note} |\n")
            f.write("\n")

        f.write("## 3. Детальный разбор выявленных вендорских хуков и план их решения\n\n")
        for sym, mods in all_missing_symbols.items():
            f.write(f"### Символ `{sym}`\n")
            f.write(f"- **Модули-потребители**: {', '.join([f'`{m}`' for m in mods])}\n")
            if sym == "portmap_get_by_vid":
                f.write("- **Назначение**: Глобальный указатель функции обратного вызова для Motorcomm YT9215S свитча (`yt_switch.ko`).\n")
                f.write("- **Поведение**: При загрузке драйвер свитча присваивает `portmap_get_by_vid = _732`, при выгрузке обнуляет `portmap_get_by_vid = NULL`.\n")
                f.write("- **Решение**: Добавить экспорт глобального указателя в ядро Linux 5.4 (`target/linux/ipq53xx/rd15/patches-5.4/`): `int (*portmap_get_by_vid)(...); EXPORT_SYMBOL(portmap_get_by_vid);`.\n")
            elif sym in ("miwifi_ct_acct_hook", "xqnss_ip_account_ecm_nss_hook"):
                f.write("- **Назначение**: Фирменные счетчики аккаунтинга трафика Xiaomi (`miwifi-skb-mark` / Conntrack stats).\n")
                f.write("- **Поведение**: Опциональные вызовы учета трафика внутри `ecm.ko`.\n")
                f.write("- **Решение**: Добавить пустую функцию-заглушку в патч ядра: `void miwifi_ct_acct_hook(...) {} EXPORT_SYMBOL(miwifi_ct_acct_hook);`.\n")
            else:
                f.write("- **Решение**: Требуется анализ исходников.\n")
            f.write("\n")

    print(f"\n[+] Детальный Markdown отчет сохранен: {args.report}")


if __name__ == "__main__":
    main()
