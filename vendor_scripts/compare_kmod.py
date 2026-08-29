#!/usr/bin/env python3
"""
compare_kmod.py - Утилита для детального сравнения совместимости модулей ядра (.ko)
и пакетов kmod между нативной сборкой OpenWrt и вендорской стоковой прошивкой (Xiaomi/QSDK).

Использование:
  1. Сравнение пакета kmod:
     ./vendor_scripts/compare_kmod.py kmod-nf-ipt
     ./vendor_scripts/compare_kmod.py kmod-nf-reject

  2. Сравнение конкретных файлов .ko:
     ./vendor_scripts/compare_kmod.py build_dir/.../x_tables.ko tmp/rootfs/lib/modules/5.4.213/x_tables.ko
     ./vendor_scripts/compare_kmod.py x_tables.ko

  3. Проверка всех пакетов из native.list:
     ./vendor_scripts/compare_kmod.py --all
"""

import sys
import os
import glob
import tarfile
import tempfile
import subprocess
import argparse
from pathlib import Path

TOPDIR = Path(__file__).resolve().parent.parent
VENDOR_ROOTFS = TOPDIR / "tmp" / "rootfs"
VENDOR_MODULES_DIR = VENDOR_ROOTFS / "lib" / "modules" / "5.4.213"
VENDOR_PACKAGES_DIR = TOPDIR / "vendor_packages"
BIN_DIR = TOPDIR / "bin"
BUILD_DIR = TOPDIR / "build_dir" / "target-arm_cortex-a7+neon-vfpv4_musl_eabi" / "linux-ipq53xx_rd15" / "linux-5.4.213"

# Поиск тулчейна ядра для кросс-инструментов
TOOLCHAIN_BIN = TOPDIR / "staging_dir" / "toolchain-arm_cortex-a7+neon-vfpv4_gcc-7.5.0_kernel" / "bin"
CROSS_PREFIX = "arm-openwrt-linux-muslgnueabi-"


def get_tool(tool_name):
    """Возвращает путь к инструменту кросс-компилятора или хостовой утилите."""
    cross_tool = TOOLCHAIN_BIN / f"{CROSS_PREFIX}{tool_name}"
    if cross_tool.exists():
        return str(cross_tool)
    which = subprocess.run(["which", f"{CROSS_PREFIX}{tool_name}"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if which.returncode == 0:
        return which.stdout.decode().strip()
    return tool_name


OBJDUMP = get_tool("objdump")
OBJCOPY = get_tool("objcopy")
READELF = get_tool("readelf")
NM = get_tool("nm")


def get_vermagic(ko_path):
    """Извлекает vermagic из секции .modinfo файла .ko."""
    try:
        out = subprocess.check_output([READELF, "-p", ".modinfo", str(ko_path)], stderr=subprocess.DEVNULL).decode()
        for line in out.splitlines():
            if "vermagic=" in line:
                return line.split("vermagic=")[1].strip()
    except Exception:
        pass
    return "UNKNOWN"


def get_symbols(ko_path):
    """
    Извлекает экспортируемые (__ksymtab_strings) и импортируемые (U) символы.
    """
    exported = set()
    imported = set()
    
    # 1. Экспортируемые модулем символы ядра из __ksymtab_strings
    try:
        out = subprocess.check_output([READELF, "-p", "__ksymtab_strings", str(ko_path)], stderr=subprocess.DEVNULL).decode()
        for line in out.splitlines():
            if "]" in line:
                s = line.split("]")[-1].strip()
                if s:
                    exported.add(s)
    except Exception:
        pass

    # 2. Импортируемые символы через nm -u
    try:
        out = subprocess.check_output([NM, "-u", str(ko_path)], stderr=subprocess.DEVNULL).decode()
        for line in out.splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[0] == "U":
                imported.add(parts[1])
            elif len(parts) == 1:
                imported.add(parts[0])
    except Exception:
        pass

    # Фолбэк для экспортов через nm, если ksymtab_strings пуст
    if not exported:
        try:
            out = subprocess.check_output([NM, "-g", str(ko_path)], stderr=subprocess.DEVNULL).decode()
            for line in out.splitlines():
                parts = line.strip().split()
                if len(parts) >= 3 and parts[1] in "TRDB" and not parts[2].startswith("__"):
                    exported.add(parts[2])
        except Exception:
            pass

    return exported, imported


def get_section_size(ko_path, section_name=".text"):
    """Возвращает размер указанной секции в байтах."""
    try:
        out = subprocess.check_output([READELF, "-S", "--wide", str(ko_path)], stderr=subprocess.DEVNULL).decode()
        for line in out.splitlines():
            if section_name in line:
                parts = line.split()
                for p in parts:
                    if len(p) == 6 and all(c in "0123456789abcdefABCDEF" for c in p):
                        return int(p, 16)
    except Exception:
        pass
    return 0


def compare_binary_text(our_ko, ven_ko):
    """
    Извлекает секцию .text обоих файлов через objcopy и сравнивает побитово.
    Возвращает (is_identical, our_size, ven_size, diff_bytes_count).
    """
    with tempfile.NamedTemporaryFile(suffix=".bin") as f1, tempfile.NamedTemporaryFile(suffix=".bin") as f2:
        try:
            subprocess.run([OBJCOPY, "-O", "binary", "--only-section=.text", str(our_ko), f1.name], check=True, stderr=subprocess.DEVNULL)
            subprocess.run([OBJCOPY, "-O", "binary", "--only-section=.text", str(ven_ko), f2.name], check=True, stderr=subprocess.DEVNULL)
            b1 = f1.read()
            b2 = f2.read()
            is_ident = (b1 == b2)
            diff_count = 0
            if not is_ident:
                min_len = min(len(b1), len(b2))
                diff_count = sum(1 for i in range(min_len) if b1[i] != b2[i]) + abs(len(b1) - len(b2))
            return is_ident, len(b1), len(b2), diff_count
        except Exception as e:
            print(f"[!] Ошибка побитового сравнения: {e}")
            return False, 0, 0, -1


def compare_functions_breakdown(our_ko, ven_ko):
    """
    Сравнивает дизассемблированные функции модуля построчно.
    """
    try:
        o_dump = subprocess.check_output([OBJDUMP, "-d", str(our_ko)], stderr=subprocess.DEVNULL).decode().splitlines()
        v_dump = subprocess.check_output([OBJDUMP, "-d", str(ven_ko)], stderr=subprocess.DEVNULL).decode().splitlines()

        def parse_funcs(lines):
            funcs = {}
            cur = None
            for l in lines:
                if "<" in l and ">:" in l and not l.startswith(" "):
                    cur = l.split("<")[1].split(">")[0]
                    funcs[cur] = []
                elif cur and l.strip():
                    funcs[cur].append(l.strip())
            return funcs

        o_f = parse_funcs(o_dump)
        v_f = parse_funcs(v_dump)
        return o_f, v_f
    except Exception:
        return {}, {}


def compare_single_module(our_ko, ven_ko, verbose=True):
    """Детально сравнивает два .ko файла."""
    name = Path(our_ko).name
    print(f"\n{'='*75}")
    print(f"[*] Сравнение модуля: {name}")
    print(f"    Наш файл:   {our_ko}")
    print(f"    Сток файл:  {ven_ko}")
    print(f"{'='*75}")

    # 1. Vermagic
    v1 = get_vermagic(our_ko)
    v2 = get_vermagic(ven_ko)
    v_match = (v1 == v2)
    print(f"1. Vermagic: {'[OK]' if v_match else '[FAIL]'}")
    print(f"   - Наш:    {v1}")
    print(f"   - Сток:   {v2}")

    # 2. Символы экспорта (ABI)
    exp1, imp1 = get_symbols(our_ko)
    exp2, imp2 = get_symbols(ven_ko)
    
    missing_exp = exp2 - exp1
    extra_exp = exp1 - exp2
    exp_ok = (len(missing_exp) == 0)
    print(f"\n2. Экспортируемые функции (ABI): {'[OK]' if exp_ok else '[FAIL]'}")
    print(f"   - Экспортов у нас: {len(exp1)}, в стоке: {len(exp2)}")
    if missing_exp:
        print(f"   [!] Отсутствуют экспорты в нативном модуле: {sorted(missing_exp)}")
    if extra_exp:
        print(f"   [i] Дополнительные экспорты: {sorted(extra_exp)}")
    if exp_ok and exp1:
        sample = sorted(list(exp1))[:5]
        print(f"   - Примеры экспортов: {', '.join(sample)}{'...' if len(exp1) > 5 else ''}")

    # 3. Импортируемые символы ядра
    missing_imp = imp1 - imp2
    extra_imp = imp2 - imp1
    print(f"\n3. Импортируемые символы ядра: {'[OK]' if imp1 == imp2 else '[OK - DIFF]'}")
    print(f"   - Наш модуль требует: {len(imp1)} символов")
    print(f"   - Сток требует:       {len(imp2)} символов")
    if missing_imp:
        print(f"   [i] Символы, требуемые только у нас ({len(missing_imp)}): {sorted(list(missing_imp))[:5]}...")
    if extra_imp:
        print(f"   [i] Символы, требуемые только в стоке ({len(extra_imp)}): {sorted(list(extra_imp))[:5]}...")

    # 4. Бинарное сравнение .text
    is_ident, s1, s2, diff_bytes = compare_binary_text(our_ko, ven_ko)
    print(f"\n4. Бинарное сравнение секции .text:")
    print(f"   - Наш размер:   {s1} байт")
    print(f"   - Сток размер:  {s2} байт")
    print(f"   - Разница:      {s1 - s2:+d} байт")
    if is_ident:
        print(f"   -> [100% BIT-FOR-BIT IDENTICAL] Модуль совпадает байт-в-байт со стоком!")
    else:
        pct = (1.0 - (diff_bytes / max(s1, s2, 1))) * 100
        print(f"   -> Побайтовое сходство: {pct:.2f}% (разница {diff_bytes} байт)")

    # 5. Разбор функций
    if verbose and not is_ident:
        o_f, v_f = compare_functions_breakdown(our_ko, ven_ko)
        if o_f and v_f:
            print(f"\n5. Функциональный состав (дизассемблер):")
            print(f"   - Найдено функций: у нас {len(o_f)}, в стоке {len(v_f)}")

    status = "IDENTICAL" if is_ident else ("COMPATIBLE" if exp_ok else "INCOMPATIBLE")
    print(f"\n>>> ИТОГ ПО МОДУЛЮ {name}: [{status}]")
    return is_ident, exp_ok


def find_our_ko(ko_name):
    """Ищет собранный .ko файл в build_dir."""
    candidates = list(BUILD_DIR.glob(f"**/{ko_name}"))
    if candidates:
        return candidates[0]
    return None


def extract_ipk_files(ipk_path, dest_dir):
    """Распаковывает data.tar.* из .ipk."""
    with tarfile.open(ipk_path, "r:*") as tar:
        for member in tar.getmembers():
            if "data.tar" in member.name:
                data_tar = tar.extractfile(member)
                with tarfile.open(fileobj=data_tar, mode="r:*") as dtar:
                    dtar.extractall(dest_dir)
                break


def compare_package(pkg_name):
    """Сравнивает пакет kmod (файлы, зависимости, модули)."""
    print(f"\n{'#'*75}")
    print(f"[#] Сравнение пакета: {pkg_name}")
    print(f"{'#'*75}")

    # Поиск нативного IPK
    native_ipks = list(BIN_DIR.glob(f"**/{pkg_name}_*.ipk"))
    vendor_ipks = list(VENDOR_PACKAGES_DIR.glob(f"{pkg_name}*.ipk"))

    print(f"- Нативный IPK:   {native_ipks[0] if native_ipks else 'НЕ НАЙДЕН'}")
    print(f"- Вендорский IPK:  {vendor_ipks[0] if vendor_ipks else 'НЕ НАЙДЕН'}")

    with tempfile.TemporaryDirectory() as tmp_our, tempfile.TemporaryDirectory() as tmp_ven:
        our_kos = []
        ven_kos = []

        if native_ipks:
            extract_ipk_files(native_ipks[0], tmp_our)
            our_kos = list(Path(tmp_our).glob("**/*.ko"))

        if vendor_ipks:
            extract_ipk_files(vendor_ipks[0], tmp_ven)
            ven_kos = list(Path(tmp_ven).glob("**/*.ko"))

        # Если в вендорском IPK нет .ko (например, built-in в ядро), проверяем vendor rootfs
        if not ven_kos and our_kos:
            for our_k in our_kos:
                v_k = VENDOR_MODULES_DIR / our_k.name
                if v_k.exists():
                    ven_kos.append(v_k)

        if not our_kos and not ven_kos:
            print(f"[i] В пакете {pkg_name} нет отдельных файлов .ko (компонент встроен монолитно в ядро).")
            return True

        all_ko_names = sorted(set([k.name for k in our_kos] + [k.name for k in ven_kos]))
        print(f"- Модули в составе пакета: {all_ko_names}")

        all_ok = True
        for ko_name in all_ko_names:
            our_k = next((k for k in our_kos if k.name == ko_name), None)
            if not our_k:
                our_k = find_our_ko(ko_name)

            ven_k = next((k for k in ven_kos if k.name == ko_name), None)
            if not ven_k and (VENDOR_MODULES_DIR / ko_name).exists():
                ven_k = VENDOR_MODULES_DIR / ko_name

            if our_k and ven_k and our_k.exists() and ven_k.exists():
                is_ident, exp_ok = compare_single_module(our_k, ven_k)
                if not exp_ok:
                    all_ok = False
            else:
                print(f"[!] Не удалось сопоставить файл {ko_name}: our={our_k}, ven={ven_k}")
                all_ok = False

        return all_ok


def main():
    parser = argparse.ArgumentParser(description="Сравнение совместимости модулей ядра и пакетов OpenWrt vs Сток")
    parser.add_argument("target", nargs="?", help="Имя пакета (kmod-nf-ipt) или путь к .ko файлу")
    parser.add_argument("vendor_target", nargs="?", help="Путь к вендорскому .ko файлу (опционально)")
    parser.add_argument("--all", action="store_true", help="Проверить все пакеты из vendor_scripts/native.list")
    args = parser.parse_args()

    if args.all:
        native_list = TOPDIR / "vendor_scripts" / "native.list"
        if not native_list.exists():
            print(f"[!] Файл {native_list} не найден.")
            sys.exit(1)
        packages = [line.strip() for line in native_list.read_text().splitlines() if line.strip()]
        print(f"[*] Проверка {len(packages)} пакетов из {native_list}...")
        for pkg in packages:
            compare_package(pkg)
        return

    if not args.target:
        parser.print_help()
        sys.exit(1)

    target = args.target

    # Режим 1: Переданы два конкретных .ko файла
    if args.vendor_target:
        compare_single_module(target, args.vendor_target)
        return

    # Режим 2: Передан один .ko файл
    if target.endswith(".ko"):
        ko_name = Path(target).name
        our_ko = Path(target) if Path(target).exists() else find_our_ko(ko_name)
        ven_ko = VENDOR_MODULES_DIR / ko_name
        if our_ko and ven_ko.exists():
            compare_single_module(our_ko, ven_ko)
        else:
            print(f"[!] Не удалось найти файлы для {target}: our={our_ko}, ven={ven_ko}")
        return

    # Режим 3: Передано имя пакета (kmod-...)
    compare_package(target)


if __name__ == "__main__":
    main()
