#!/usr/bin/env python3
"""generate_package.py

Modular OpenWrt vendor package generator and subtarget updater.
Handles copying package files, preserving symlinks, managing board-specific
subtarget files (files-$(SUBTARGET)), and generating package Makefiles.
"""

import argparse
import fnmatch
import os
import re
import shutil
import sys
from typing import Dict, List, Optional, Set

# Declarative dictionary of packages that contain board/subtarget-specific files.
# Key: original package name without '-vendor' suffix (e.g. 'qca-firmware').
# Value: list of glob patterns for relative paths that belong to files-$(SUBTARGET)/.
SUBTARGET_SPECIFIC_PATTERNS: Dict[str, List[str]] = {
    "qca-firmware": [
        "*bdwlan.b0060*",
    ],
}


def is_subtarget_specific(pkg: str, rel_path: str) -> bool:
    """Return True if rel_path matches any subtarget pattern for pkg."""
    patterns = SUBTARGET_SPECIFIC_PATTERNS.get(pkg, [])
    for pat in patterns:
        if fnmatch.fnmatch(rel_path, pat) or fnmatch.fnmatch(os.path.basename(rel_path), pat):
            return True
    return False


def copy_file_or_link(src: str, dst: str) -> None:
    """Copy file or recreate symlink from src to dst preserving structure."""
    if os.path.islink(src):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.lexists(dst):
            os.remove(dst)
        link_target = os.readlink(src)
        os.symlink(link_target, dst)
    elif os.path.isdir(src):
        os.makedirs(dst, exist_ok=True)
    elif os.path.isfile(src):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)


def update_package_subtarget_files(
    extracted_rootfs: str,
    feed_dir: str,
    pkg: str,
    subtarget: str,
) -> int:
    """Update files-$(SUBTARGET) for an existing package in the feed.

    Returns the number of files/symlinks copied.
    """
    pkg_vendor = f"{pkg}-vendor"
    pkg_dir = os.path.join(feed_dir, pkg_vendor)
    if not os.path.isdir(pkg_dir):
        print(f"Warning: Package directory not found at {pkg_dir}, skipping subtarget update.", file=sys.stderr)
        return 0

    list_file = os.path.join(extracted_rootfs, "usr/lib/opkg/info", f"{pkg}.list")
    if not os.path.isfile(list_file):
        print(f"Warning: File list for package '{pkg}' not found at {list_file}", file=sys.stderr)
        return 0

    subtarget_dir = os.path.join(pkg_dir, f"files-{subtarget}")
    if os.path.exists(subtarget_dir):
        shutil.rmtree(subtarget_dir)

    copied_count = 0
    with open(list_file, "r") as lf:
        rel_paths = [l.strip().lstrip("/") for l in lf if l.strip()]

    for rel_path in rel_paths:
        if is_subtarget_specific(pkg, rel_path):
            src = os.path.join(extracted_rootfs, rel_path)
            if not os.path.exists(src) and not os.path.islink(src):
                continue
            dst = os.path.join(subtarget_dir, rel_path)
            copy_file_or_link(src, dst)
            copied_count += 1

    print(f"Updated {copied_count} subtarget-specific files in {pkg_vendor}/files-{subtarget}")
    return copied_count


def generate_single_package(
    pkg: str,
    pkg_meta: dict,
    extracted_rootfs: str,
    feed_dir: str,
    subtarget: str,
    native_pkgs: Set[str],
    ignore_pkgs: Set[str],
    extra_kmod_deps: Dict[str, List[str]],
) -> str:
    """Generate complete vendor package directory, copy files, and write Makefile."""
    pkg_vendor = f"{pkg}-vendor"
    pkg_dir = os.path.join(feed_dir, pkg_vendor)
    files_dir = os.path.join(pkg_dir, "files")
    os.makedirs(files_dir, exist_ok=True)

    has_subtarget_files = pkg in SUBTARGET_SPECIFIC_PATTERNS

    # Copy files according to opkg info list
    list_file = os.path.join(extracted_rootfs, "usr/lib/opkg/info", f"{pkg}.list")
    if os.path.isfile(list_file):
        with open(list_file, "r") as lf:
            rel_paths = [l.strip().lstrip("/") for l in lf if l.strip()]
        for rel_path in rel_paths:
            src = os.path.join(extracted_rootfs, rel_path)
            if not os.path.exists(src) and not os.path.islink(src):
                continue

            if has_subtarget_files and is_subtarget_specific(pkg, rel_path):
                dst = os.path.join(pkg_dir, f"files-{subtarget}", rel_path)
            else:
                dst = os.path.join(files_dir, rel_path)

            copy_file_or_link(src, dst)

    # Determine version and release
    full_version = pkg_meta.get("version", "1.0")
    if "-" in full_version:
        pkg_version, pkg_release = full_version.rsplit("-", 1)
    else:
        pkg_version = full_version
        pkg_release = "1"

    # Resolve dependencies
    raw_deps = [
        d for d in pkg_meta.get("depends", [])
        if (d in pkg_meta.get("_all_pkgs", set()) or d in native_pkgs) and d not in ignore_pkgs
    ]
    for extra_dep in extra_kmod_deps.get(pkg, []):
        if extra_dep not in raw_deps and (extra_dep in pkg_meta.get("_all_pkgs", set()) or extra_dep in native_pkgs) and extra_dep not in ignore_pkgs:
            raw_deps.append(extra_dep)

    filtered_deps = []
    for d in raw_deps:
        if d in native_pkgs:
            filtered_deps.append(f"+{d}")
        else:
            filtered_deps.append(f"+{d}-vendor")
    depends_str = " ".join(filtered_deps)
    depends_line = f"  DEPENDS:={depends_str}\n" if depends_str else ""

    conffiles = pkg_meta.get("conffiles", [])
    conffiles_block = ""
    if conffiles:
        cf_lines = "\n".join(conffiles)
        conffiles_block = f"define Package/{pkg_vendor}/conffiles\n{cf_lines}\nendef\n\n"

    extra_flags = ""
    extra_install = ""
    if has_subtarget_files:
        extra_flags = """PKG_FLAGS:=nonshared
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(SUBTARGET)
PKG_CONFIG_DEPENDS:=CONFIG_TARGET_SUBTARGET
"""
        extra_install = "\t$(if $(wildcard ./files-$(SUBTARGET)/*),$(CP) ./files-$(SUBTARGET)/* $(1)/)\n"

    makefile_content = f"""include $(TOPDIR)/rules.mk

PKG_NAME:={pkg_vendor}
PKG_VERSION:={pkg_version}
PKG_RELEASE:={pkg_release}
{extra_flags}include $(INCLUDE_DIR)/package.mk

define Package/{pkg_vendor}
  SECTION:=vendor
  CATEGORY:=Vendor Prebuilt
  TITLE:=Prebuilt {pkg} package
{depends_line}endef

define Package/{pkg_vendor}/description
  Prebuilt {pkg} package extracted from vendor firmware.
endef

{conffiles_block}define Build/Configure
endef

define Build/Compile
endef

define Package/{pkg_vendor}/install
\t$(INSTALL_DIR) $(1)
\t$(if $(wildcard ./files/*),$(CP) ./files/* $(1)/)
{extra_install}endef

$(eval $(call BuildPackage,{pkg_vendor}))
"""

    makefile_path = os.path.join(pkg_dir, "Makefile")
    with open(makefile_path, "w") as mf:
        mf.write(makefile_content)

    return pkg_dir


def main() -> None:
    parser = argparse.ArgumentParser(description="OpenWrt vendor package generator and subtarget updater")
    parser.add_argument("--rootfs", required=True, help="Path to extracted vendor rootfs")
    parser.add_argument("--feed", required=True, help="Path to vendor_feed directory")
    parser.add_argument("--subtarget", required=True, help="Target subtarget model (e.g. rd15, rd16)")
    parser.add_argument("--update", action="store_true", help="Only update subtarget-specific files for package(s)")
    parser.add_argument("packages", nargs="*", help="List of package names (e.g. qca-firmware). If empty with --update, all configured subtarget packages are updated.")

    args = parser.parse_args()

    if args.update:
        targets = args.packages if args.packages else list(SUBTARGET_SPECIFIC_PATTERNS.keys())
        for pkg in targets:
            update_package_subtarget_files(args.rootfs, args.feed, pkg, args.subtarget)
    else:
        print("Error: Full single package generation requires status file metadata. Use generate_feed.py for initial feed build.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
