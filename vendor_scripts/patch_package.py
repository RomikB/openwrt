#!/usr/bin/env python3
"""patch_package.py

Patches vendor packages by adding 'v_l' prefix to all vendor shared libraries,
updating SONAME, DT_NEEDED dependencies, PT_INTERP, and library symlinks.

Rules:
  kmod* (kernel modules)
    - Skipped (no changes).

  All shared libraries (*.so*):
    - Renamed with 'v_l' prefix (e.g. libubox.so -> v_lubox.so,
      libc.so -> v_lc.so, libgcc_s.so.1 -> v_lgcc_s.so.1,
      libjson-c.so.5.1.0 -> v_ljson-c.so.5.1.0).
    - Symlinks updated to point to 'v_l' targets and renamed with 'v_l'.
    - ld symlinks updated to ld-vendor.so.1, ldd -> vldd.
    - DT_SONAME updated to 'v_l' name.
    - DT_NEEDED updated for all referenced vendor libraries.

  All executable binaries:
    - PT_INTERP updated to /lib/ld-vendor.so.1.
    - DT_NEEDED updated for all referenced vendor libraries.

Usage:
    python3 ./vendor_scripts/patch_package.py <package_dir>
"""

import os
import re
import sys
from pathlib import Path

# Add vendor_scripts directory to sys.path to import patch_library
SCRIPTS_DIR = Path(__file__).resolve().parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from patch_library import ELFEditor, ELFError

VENDOR_INTERP = "/lib/ld-vendor.so.1"


def is_elf(file_path: Path) -> bool:
    """Return True if *file_path* starts with the ELF magic header."""
    try:
        with file_path.open("rb") as fh:
            return fh.read(4) == b"\x7fELF"
    except Exception:
        return False


def is_lib_name(name: str) -> bool:
    """Return True if *name* is a shared library, dynamic linker, or ldd tool."""
    return ".so" in name or name.startswith("ld-") or name == "ldd"


def get_vendor_lib_name(name: str) -> str:
    """Return the vendor-prefixed library/link name (replaces 'lib' with 'v_l')."""
    if not name:
        return name

    if name == "ldd":
        return "vldd"

    if name.startswith("ld-") and ".so" in name:
        return "ld-vendor.so.1"

    if name == "libc.so" or name.startswith("libc.so."):
        return "v_lc.so"

    if name.startswith("lib") and (".so" in name or name.endswith(".so")):
        return "v_l" + name[3:]

    return name


def patch_package_directory(target_dir: Path) -> None:
    """
    Scans a directory (e.g. files/), renames libraries/symlinks,
    and updates ELF metadata (INTERP, SONAME, NEEDED).
    """
    if not target_dir.is_dir():
        return

    # 1. Update and rename symlinks for libraries
    for root, _dirs, filenames in os.walk(target_dir):
        root_path = Path(root)
        for name in filenames:
            file_path = root_path / name
            if not file_path.is_symlink():
                continue

            # Only process library symlinks
            if not is_lib_name(name):
                continue

            target = os.readlink(file_path)
            target_path = Path(target)

            new_link_name = get_vendor_lib_name(name)
            new_target_name = get_vendor_lib_name(target_path.name)

            if str(target_path.parent) != ".":
                new_target = str(target_path.parent / new_target_name)
            else:
                new_target = new_target_name

            if new_link_name != name or new_target != target:
                file_path.unlink()
                final_link_path = root_path / new_link_name
                os.symlink(new_target, final_link_path)
                print(
                    f"    Symlink  {name!r} -> {new_link_name!r}"
                    f"  (target: {target!r} -> {new_target!r})"
                )

    # 2. Rename regular library files (only .so/ld-musl/ldd files)
    for root, _dirs, filenames in os.walk(target_dir):
        root_path = Path(root)
        for name in filenames:
            file_path = root_path / name
            if file_path.is_symlink() or not file_path.is_file():
                continue

            if not is_lib_name(name):
                continue

            new_name = get_vendor_lib_name(name)
            if new_name != name:
                new_path = root_path / new_name
                file_path.rename(new_path)
                print(f"    Renamed  {name!r} -> {new_name!r}")

    # 3. Patch ELF binaries (executables and libraries)
    for root, _dirs, filenames in os.walk(target_dir):
        root_path = Path(root)
        for name in filenames:
            file_path = root_path / name
            if file_path.is_symlink() or not file_path.is_file():
                continue

            if not is_elf(file_path):
                continue

            try:
                editor = ELFEditor(file_path)
                patched = False

                # Patch PT_INTERP for executables
                if editor.interp_segment is not None:
                    current_interp = editor.interp_segment.get_interp_name()
                    if current_interp != VENDOR_INTERP:
                        editor.patch_interp(VENDOR_INTERP)
                        patched = True

                # Patch DT_SONAME for shared libraries
                soname_info = editor.get_soname()
                if soname_info:
                    old_soname = soname_info["name"]
                    new_soname = get_vendor_lib_name(old_soname)
                    if new_soname != old_soname:
                        editor.patch_soname(new_soname)
                        patched = True

                # Patch DT_NEEDED for all referenced vendor libraries
                for needed in editor.get_needed():
                    old_needed = needed["name"]
                    new_needed = get_vendor_lib_name(old_needed)
                    if new_needed != old_needed:
                        editor.patch_needed(old_needed, new_needed)
                        patched = True

                if patched:
                    editor.save(file_path)
            except ELFError as e:
                print(f"    Skip ELF patch for {file_path.name}: {e}")
            except Exception as e:
                print(f"    Error patching {file_path.name}: {e}")


def patch_vendor_package(pkg_dir: Path) -> None:
    """Patches an individual vendor package directory."""
    dir_name = pkg_dir.name
    orig_pkg_name = dir_name[:-7] if dir_name.endswith("-vendor") else dir_name

    # Enable automatic boot startup for qca-nss-ecm in OpenWrt rc.common
    init_ecm = pkg_dir / "files" / "etc" / "init.d" / "qca-nss-ecm"
    if init_ecm.is_file():
        content = init_ecm.read_text()
        if "#!/bin/sh  /etc/rc.common" in content:
            content = content.replace("#!/bin/sh  /etc/rc.common", "#!/bin/sh /etc/rc.common")
            init_ecm.write_text(content)

    is_kmod = orig_pkg_name.startswith("kmod")

    print(f"Patching: {orig_pkg_name} [kmod={is_kmod}]")

    if is_kmod:
        print("  Kernel module -- skipping.")
        return

    files_dir = pkg_dir / "files"
    if files_dir.is_dir():
        patch_package_directory(files_dir)


def main() -> None:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <package_dir>", file=sys.stderr)
        sys.exit(1)

    pkg_dir = Path(sys.argv[1]).resolve()
    if not pkg_dir.is_dir():
        print(f"Error: {pkg_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    patch_vendor_package(pkg_dir)


if __name__ == "__main__":
    main()
