#!/usr/bin/env python3
"""extract_kmod_deps.py

Extracts kernel module dependencies directly from .ko binary files in the
extracted firmware rootfs and generates a JSON dependency map.

Usage:
    python3 ./vendor_scripts/extract_kmod_deps.py <extracted_rootfs> <output_json>
"""

import glob
import json
import os
import re
import sys


def extract_dependencies(rootfs_dir: str) -> dict:
    """Extracts package dependencies by inspecting .ko files and opkg .list files."""
    mod_to_pkg = {}
    info_dir = os.path.join(rootfs_dir, "usr/lib/opkg/info")

    # 1. Build a map of module names (with _ and - variations) to owning opkg package
    for list_path in glob.glob(os.path.join(info_dir, "*.list")):
        pkg_name = os.path.basename(list_path)[:-5]
        try:
            with open(list_path, "r", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if line.endswith(".ko"):
                        mod_name = os.path.splitext(os.path.basename(line))[0]
                        mod_to_pkg[mod_name] = pkg_name
                        mod_to_pkg[mod_name.replace("_", "-")] = pkg_name
                        mod_to_pkg[mod_name.replace("-", "_")] = pkg_name
        except Exception as e:
            print(f"Warning: Failed to read {list_path}: {e}", file=sys.stderr)

    # 2. Extract depends= from each .ko file
    pkg_deps = {}
    ko_files = glob.glob(os.path.join(rootfs_dir, "lib/modules/*/*.ko")) + \
               glob.glob(os.path.join(rootfs_dir, "lib/modules/*.ko"))

    for ko_path in ko_files:
        mod_name = os.path.splitext(os.path.basename(ko_path))[0]
        pkg = mod_to_pkg.get(mod_name) or mod_to_pkg.get(mod_name.replace("_", "-")) or mod_to_pkg.get(mod_name.replace("-", "_"))
        if not pkg:
            continue

        try:
            with open(ko_path, "rb") as f:
                data = f.read()

            # Find all depends= occurrences in .modinfo / ELF strings
            matches = re.findall(b"depends=([^\x00]*)", data)
            for m in matches:
                dep_str = m.decode("utf-8", errors="ignore").strip()
                if not dep_str:
                    continue
                dep_mods = [d.strip() for d in dep_str.split(",") if d.strip()]
                for dep_m in dep_mods:
                    dep_pkg = mod_to_pkg.get(dep_m) or mod_to_pkg.get(dep_m.replace("_", "-")) or mod_to_pkg.get(dep_m.replace("-", "_"))
                    if dep_pkg and dep_pkg != pkg:
                        pkg_deps.setdefault(pkg, set()).add(dep_pkg)
        except Exception as e:
            print(f"Warning: Failed to parse {ko_path}: {e}", file=sys.stderr)

    # Convert sets to sorted lists for deterministic JSON output
    return {k: sorted(list(v)) for k, v in sorted(pkg_deps.items())}


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <extracted_rootfs> <output_json>", file=sys.stderr)
        sys.exit(1)

    rootfs_dir = sys.argv[1]
    output_json = sys.argv[2]

    if not os.path.isdir(rootfs_dir):
        print(f"Error: Directory {rootfs_dir} does not exist", file=sys.stderr)
        sys.exit(1)

    os.makedirs(os.path.dirname(os.path.abspath(output_json)), exist_ok=True)
    deps = extract_dependencies(rootfs_dir)

    with open(output_json, "w") as f:
        json.dump(deps, f, indent=2)

    print(f"Extracted dependencies for {len(deps)} kernel packages to {output_json}")


if __name__ == "__main__":
    main()
