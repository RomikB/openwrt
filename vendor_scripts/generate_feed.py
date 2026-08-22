#!/usr/bin/env python3
import os
import re
import shutil
import sys

# Validate argument count
if len(sys.argv) < 6:
    print("This script is an internal helper. Please run the main script from the OpenWrt root directory:", file=sys.stderr)
    print("  ./vendor_scripts/prepare_feed.sh [firmware_file.bin]", file=sys.stderr)
    sys.exit(1)

import json

# Parse command line arguments
status_file = sys.argv[1]
extracted_rootfs = sys.argv[2]
feed_dir = sys.argv[3]
add_pkgs = sys.argv[4].split()
ignore_pkgs = set(sys.argv[5].split())
deps_json_file = sys.argv[6] if len(sys.argv) > 6 else os.path.join(os.path.dirname(feed_dir), "tmp/kmod_deps.json")

# Load kernel module dependencies extracted from .ko binaries
extra_kmod_deps = {}
if os.path.isfile(deps_json_file):
    with open(deps_json_file, 'r') as f:
        extra_kmod_deps = json.load(f)
    print(f"Loaded dynamic kernel module dependencies from {deps_json_file}")

# Parse opkg status file for package metadata and dependencies
pkg_info = {}
current_pkg = None

with open(status_file, 'r') as f:
    for line in f:
        line_str = line.strip()
        if line_str.startswith('Package:'):
            current_pkg = line_str.split(':', 1)[1].strip()
            pkg_info[current_pkg] = {'version': '1.0', 'depends': [], 'conffiles': []}
        elif current_pkg:
            if line_str.startswith('Version:'):
                pkg_info[current_pkg]['version'] = line_str.split(':', 1)[1].strip()
            elif line_str.startswith('Depends:'):
                raw_deps = line_str.split(':', 1)[1].strip()
                raw_deps = re.sub(r'\([^)]*\)', '', raw_deps)
                deps = [d.strip() for d in raw_deps.split(',') if d.strip()]
                pkg_info[current_pkg]['depends'] = deps

# Load configuration file lists from opkg info
for pkg in pkg_info:
    conffiles_file = os.path.join(extracted_rootfs, 'usr/lib/opkg/info', f"{pkg}.conffiles")
    if os.path.isfile(conffiles_file):
        with open(conffiles_file, 'r') as cf:
            cfs = [l.strip() for l in cf if l.strip()]
            pkg_info[pkg]['conffiles'] = cfs

# Resolve target package list and transitive dependencies
visited = set()
to_visit = list(add_pkgs)
resolved = []
while to_visit:
    pkg = to_visit.pop(0)
    if pkg in ignore_pkgs or pkg in visited:
        continue
    visited.add(pkg)
    resolved.append(pkg)
    deps = [d for d in pkg_info.get(pkg, {}).get('depends', []) if d in pkg_info]
    for extra in extra_kmod_deps.get(pkg, []):
        if extra not in deps and extra in pkg_info:
            deps.append(extra)
    for dep in deps:
        if dep not in ignore_pkgs and dep not in visited:
            to_visit.append(dep)

# Create output feed directory
os.makedirs(feed_dir, exist_ok=True)

# Generate package directories, copy prebuilt files, and build Makefiles
for pkg in resolved:
    pkg_vendor = f"{pkg}-vendor"
    pkg_dir = os.path.join(feed_dir, pkg_vendor)
    files_dir = os.path.join(pkg_dir, 'files')
    os.makedirs(files_dir, exist_ok=True)

    list_file = os.path.join(extracted_rootfs, 'usr/lib/opkg/info', f"{pkg}.list")
    if os.path.isfile(list_file):
        with open(list_file, 'r') as lf:
            rel_paths = [l.strip().lstrip('/') for l in lf if l.strip()]
        for rel_path in rel_paths:
            src = os.path.join(extracted_rootfs, rel_path)
            dst = os.path.join(files_dir, rel_path)

            if not os.path.exists(src) and not os.path.islink(src):
                continue

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

    full_version = pkg_info.get(pkg, {}).get('version', '1.0')
    if '-' in full_version:
        pkg_version, pkg_release = full_version.rsplit('-', 1)
    else:
        pkg_version = full_version
        pkg_release = '1'

    filtered_deps = [d for d in pkg_info.get(pkg, {}).get('depends', []) if d in pkg_info and d not in ignore_pkgs]
    for extra_dep in extra_kmod_deps.get(pkg, []):
        if extra_dep not in filtered_deps and extra_dep in pkg_info and extra_dep not in ignore_pkgs:
            filtered_deps.append(extra_dep)
    depends_str = ' '.join(f"+{d}-vendor" for d in filtered_deps)

    conffiles = pkg_info.get(pkg, {}).get('conffiles', [])
    conffiles_block = ""
    if conffiles:
        cf_lines = '\n'.join(conffiles)
        conffiles_block = f"define Package/{pkg_vendor}/conffiles\n{cf_lines}\nendef\n\n"

    depends_line = f"  DEPENDS:={depends_str}\n" if depends_str else ""

    makefile_content = f"""include $(TOPDIR)/rules.mk

PKG_NAME:={pkg_vendor}
PKG_VERSION:={pkg_version}
PKG_RELEASE:={pkg_release}

include $(INCLUDE_DIR)/package.mk

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
	$(INSTALL_DIR) $(1)
	$(if $(wildcard ./files/*),$(CP) ./files/* $(1)/)
endef

$(eval $(call BuildPackage,{pkg_vendor}))
"""

    with open(os.path.join(pkg_dir, 'Makefile'), 'w') as mf:
        mf.write(makefile_content)

print(f"Generated feed for {len(resolved)} packages: {', '.join(resolved)}")
