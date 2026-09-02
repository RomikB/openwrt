#!/usr/bin/env python3
"""
extract_builtin_from_rootfs.py

Analyzes an unpacked stock firmware rootfs to discover built-in kernel modules
and their corresponding kmod-* packages by cross-referencing:
1. /lib/modules/**/*.ko (binary modules present on filesystem)
2. /etc/modules.d/* (module autoload definitions)
3. /usr/lib/opkg/info/*.list (OPKG package file ownership)
4. Optional: modules.builtin (compiled kernel built-in modules list)
"""

import os
import sys
import glob
import json
import argparse
from collections import defaultdict


def normalize_mod_name(name):
    """Normalize kernel module name: strip .ko and replace hyphens/underscores."""
    name = os.path.splitext(os.path.basename(name))[0]
    return name.lower().replace("-", "_")


def find_default_modules_builtin(workspace_root="."):
    """Find compiled modules.builtin file in build_dir."""
    pattern = os.path.join(workspace_root, "build_dir", "**", "linux-5.4*", "modules.builtin")
    matches = glob.glob(pattern, recursive=True)
    return matches[0] if matches else None


def load_modules_builtin(builtin_path):
    """Load compiled modules.builtin and create normalized lookup map."""
    if not builtin_path or not os.path.isfile(builtin_path):
        return {}, []

    kpath_map = {}  # norm_name -> kernel_relative_path
    all_lines = []
    with open(builtin_path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            all_lines.append(line)
            norm = normalize_mod_name(line)
            kpath_map[norm] = line

    return kpath_map, all_lines


def scan_ko_modules(rootfs):
    """Scan all .ko files in rootfs and return a set of normalized module names."""
    ko_map = {}  # normalized_name -> actual path
    search_dirs = [
        os.path.join(rootfs, "lib", "modules"),
        os.path.join(rootfs, "lib"),
        rootfs
    ]

    for sdir in search_dirs:
        if os.path.exists(sdir):
            for root, _, files in os.walk(sdir):
                for f in files:
                    if f.endswith(".ko"):
                        full_path = os.path.join(root, f)
                        norm = normalize_mod_name(f)
                        if norm not in ko_map:
                            ko_map[norm] = os.path.relpath(full_path, rootfs)
            if ko_map:
                break

    return ko_map


def parse_opkg_mappings(rootfs):
    """
    Parse opkg info directory to map /etc/modules.d/<file> to package name,
    and also collect all files owned by each kmod-* package.
    """
    modfile_to_pkg = {}
    pkg_files = defaultdict(list)
    
    opkg_info_dirs = [
        os.path.join(rootfs, "usr", "lib", "opkg", "info"),
        os.path.join(rootfs, "lib", "opkg", "info"),
    ]
    
    found_info_dir = None
    for d in opkg_info_dirs:
        if os.path.isdir(d):
            found_info_dir = d
            break

    if found_info_dir:
        for list_path in glob.glob(os.path.join(found_info_dir, "*.list")):
            pkg_name = os.path.basename(list_path)[:-5]  # remove .list
            with open(list_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    pkg_files[pkg_name].append(line)
                    if "/etc/modules.d/" in line:
                        mod_filename = os.path.basename(line)
                        modfile_to_pkg[mod_filename] = pkg_name

    # Fallback to parsing /etc/modules.d filenames directly if opkg info was missing
    modules_d = os.path.join(rootfs, "etc", "modules.d")
    if os.path.isdir(modules_d):
        for f in os.listdir(modules_d):
            if f not in modfile_to_pkg:
                clean_name = f
                if "-" in clean_name and clean_name.split("-")[0].isdigit():
                    clean_name = "-".join(clean_name.split("-")[1:])
                inferred_pkg = f"kmod-{clean_name}" if not clean_name.startswith("kmod-") else clean_name
                modfile_to_pkg[f] = inferred_pkg

    return modfile_to_pkg, pkg_files


def parse_modules_d(rootfs):
    """
    Parse all files in /etc/modules.d and extract module entries.
    Returns dict: filename -> list of (raw_module_entry, module_name, load_args)
    """
    modules_d_dir = os.path.join(rootfs, "etc", "modules.d")
    entries = {}
    
    if not os.path.isdir(modules_d_dir):
        return entries

    for fname in sorted(os.listdir(modules_d_dir)):
        fpath = os.path.join(modules_d_dir, fname)
        if not os.path.isfile(fpath):
            continue
        file_mods = []
        with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split()
                mod_raw = parts[0]
                args = " ".join(parts[1:]) if len(parts) > 1 else ""
                file_mods.append((mod_raw, normalize_mod_name(mod_raw), args))
        entries[fname] = file_mods

    return entries


def analyze_rootfs(rootfs, modules_builtin_path=None):
    """Perform complete cross-reference analysis on rootfs."""
    if not os.path.isdir(rootfs):
        raise FileNotFoundError(f"Rootfs directory not found: {rootfs}")

    ko_map = scan_ko_modules(rootfs)
    modfile_to_pkg, pkg_files = parse_opkg_mappings(rootfs)
    modules_d_entries = parse_modules_d(rootfs)
    kbuiltin_map, kbuiltin_all = load_modules_builtin(modules_builtin_path)

    builtin_modules = []
    dynamic_modules = []
    pkg_stats = defaultdict(lambda: {"builtin": [], "dynamic": []})

    for modfile, mod_list in modules_d_entries.items():
        pkg = modfile_to_pkg.get(modfile, "unknown")
        for raw_name, norm_name, args in mod_list:
            item = {
                "module": raw_name,
                "normalized": norm_name,
                "modules_d_file": modfile,
                "package": pkg,
                "args": args,
                "kernel_builtin_path": kbuiltin_map.get(norm_name, None)
            }
            if norm_name in ko_map:
                item["ko_path"] = ko_map[norm_name]
                dynamic_modules.append(item)
                pkg_stats[pkg]["dynamic"].append(raw_name)
            else:
                item["ko_path"] = None
                builtin_modules.append(item)
                pkg_stats[pkg]["builtin"].append(raw_name)

    unique_builtin_mods = sorted(list({item["module"] for item in builtin_modules}))
    unique_builtin_pkgs = sorted(list({item["package"] for item in builtin_modules}))

    return {
        "rootfs": os.path.abspath(rootfs),
        "modules_builtin_path": os.path.abspath(modules_builtin_path) if modules_builtin_path else None,
        "total_ko_files": len(ko_map),
        "total_modules_d_files": len(modules_d_entries),
        "total_compiled_builtin": len(kbuiltin_all),
        "builtin_modules": builtin_modules,
        "dynamic_modules": dynamic_modules,
        "unique_builtin_modules": unique_builtin_mods,
        "unique_builtin_packages": unique_builtin_pkgs,
        "package_stats": pkg_stats,
    }


def print_table_report(results):
    """Print nicely formatted report to terminal."""
    builtin = results["builtin_modules"]
    unique_mods = results["unique_builtin_modules"]
    unique_pkgs = results["unique_builtin_packages"]
    pkg_stats = results["package_stats"]
    kpath_available = results["modules_builtin_path"] is not None

    print("=" * 95)
    print(" STOCK FIRMWARE BUILT-IN KERNEL MODULES & KMOD PACKAGES ANALYSIS")
    print("=" * 95)
    print(f"Rootfs path:             {results['rootfs']}")
    if kpath_available:
        print(f"Compiled modules.builtin: {results['modules_builtin_path']} ({results['total_compiled_builtin']} entries)")
    print(f"Total .ko files in rootfs: {results['total_ko_files']}")
    print(f"Autoload files scanned:   {results['total_modules_d_files']}")
    print(f"Dynamic modules (.ko):    {len(results['dynamic_modules'])}")
    print(f"Built-in modules:         {len(builtin)} (unique: {len(unique_mods)})")
    print(f"kmod-* packages involved: {len(unique_pkgs)}")
    print("-" * 95)

    print("\n[1] DETAILED LIST OF BUILT-IN MODULES (Defined in /etc/modules.d/ without .ko file):")
    if kpath_available:
        print(f"{'#':<4} {'Module':<20} {'Autoload File':<22} {'OPKG Package':<25} {'Kernel Source Path'}")
        print("-" * 95)
        for idx, item in enumerate(builtin, 1):
            kpath = item["kernel_builtin_path"] or "(non-modular / core / merged)"
            print(f"{idx:<4} {item['module']:<20} {item['modules_d_file']:<22} {item['package']:<25} {kpath}")
    else:
        print(f"{'#':<4} {'Module':<24} {'Autoload File':<24} {'OPKG Package':<26}")
        print("-" * 95)
        for idx, item in enumerate(builtin, 1):
            print(f"{idx:<4} {item['module']:<24} {item['modules_d_file']:<24} {item['package']:<26}")

    print("\n" + "-" * 95)
    print(f"[2] SUMMARY: UNIQUE BUILT-IN MODULES ({len(unique_mods)}):")
    print("-" * 95)
    col_width = 23
    for i in range(0, len(unique_mods), 4):
        row = unique_mods[i:i+4]
        print("  " + "".join(f"{m:<{col_width}}" for m in row))

    print("\n" + "-" * 95)
    print(f"[3] SUMMARY: UNIQUE KMOD PACKAGES WITH BUILT-IN MODULES ({len(unique_pkgs)}):")
    print("-" * 95)
    for idx, pkg in enumerate(unique_pkgs, 1):
        st = pkg_stats[pkg]
        built_str = ", ".join(st["builtin"])
        if st["dynamic"]:
            dyn_str = f" [mixed: also has {len(st['dynamic'])} dynamic .ko: {', '.join(st['dynamic'])}]"
        else:
            dyn_str = " [100% built-in]"
        print(f"  {idx:<2}. {pkg:<26} -> modules: {built_str}{dyn_str}")

    if kpath_available:
        matched_count = sum(1 for m in builtin if m["kernel_builtin_path"])
        print("\n" + "-" * 95)
        print(f"[4] CROSS-REFERENCE WITH COMPILED modules.builtin:")
        print("-" * 95)
        print(f"  Direct exact matches in kernel source tree: {matched_count} / {len(builtin)}")
        non_matched = [m["module"] for m in builtin if not m["kernel_builtin_path"]]
        if non_matched:
            print(f"  Core built-in / merged in 5.4 kernel ({len(non_matched)}): {', '.join(non_matched)}")

    print("=" * 95)


def save_results(results, output_dir):
    """Save results to text files and JSON in output directory."""
    os.makedirs(output_dir, exist_ok=True)

    mods_file = os.path.join(output_dir, "builtin_modules.txt")
    with open(mods_file, "w", encoding="utf-8") as f:
        for m in results["unique_builtin_modules"]:
            f.write(f"{m}\n")

    pkgs_file = os.path.join(output_dir, "builtin_packages.txt")
    with open(pkgs_file, "w", encoding="utf-8") as f:
        for p in results["unique_builtin_packages"]:
            f.write(f"{p}\n")

    json_file = os.path.join(output_dir, "builtin_report.json")
    serializable = dict(results)
    serializable["package_stats"] = {k: v for k, v in results["package_stats"].items()}
    with open(json_file, "w", encoding="utf-8") as f:
        json.dump(serializable, f, indent=2)

    print(f"\nSaved analysis results to directory: {output_dir}")
    print(f"  - {mods_file}")
    print(f"  - {pkgs_file}")
    print(f"  - {json_file}")


def main():
    parser = argparse.ArgumentParser(
        description="Extract built-in kernel modules and kmod-* packages from stock firmware rootfs, optionally cross-referenced with compiled modules.builtin."
    )
    parser.add_argument(
        "--rootfs", "-r",
        default="./tmp/rootfs",
        help="Path to unpacked rootfs directory (default: ./tmp/rootfs)"
    )
    parser.add_argument(
        "--modules-builtin", "-b",
        default=None,
        help="Path to compiled modules.builtin (default: auto-detect in build_dir)"
    )
    parser.add_argument(
        "--output-dir", "-o",
        default=None,
        help="Optional directory to save result files (builtin_modules.txt, builtin_packages.txt, JSON)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output raw JSON to stdout instead of human-readable table"
    )
    parser.add_argument(
        "--only-modules",
        action="store_true",
        help="Print only the list of built-in module names (one per line)"
    )
    parser.add_argument(
        "--only-packages",
        action="store_true",
        help="Print only the list of kmod-* package names (one per line)"
    )

    args = parser.parse_args()

    rootfs_path = args.rootfs
    if not os.path.isdir(rootfs_path):
        alt_paths = [
            "./tmp/rootfs",
            "../tmp/rootfs",
            "./target/linux/ipq53xx/rd15/base-files"
        ]
        found = False
        for p in alt_paths:
            if os.path.isdir(p):
                rootfs_path = p
                found = True
                break
        if not found:
            print(f"Error: rootfs directory '{args.rootfs}' not found.", file=sys.stderr)
            sys.exit(1)

    builtin_path = args.modules_builtin
    if not builtin_path:
        builtin_path = find_default_modules_builtin(".")

    try:
        results = analyze_rootfs(rootfs_path, builtin_path)
    except Exception as e:
        print(f"Error during rootfs analysis: {e}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        serializable = dict(results)
        serializable["package_stats"] = {k: v for k, v in results["package_stats"].items()}
        print(json.dumps(serializable, indent=2))
    elif args.only_modules:
        for m in results["unique_builtin_modules"]:
            print(m)
    elif args.only_packages:
        for p in results["unique_builtin_packages"]:
            print(p)
    else:
        print_table_report(results)

    if args.output_dir:
        save_results(results, args.output_dir)


if __name__ == "__main__":
    main()
