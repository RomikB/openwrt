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

    # 3. Patch ELF binaries (executables and libraries, skip .ko kernel modules)
    for root, _dirs, filenames in os.walk(target_dir):
        root_path = Path(root)
        for name in filenames:
            file_path = root_path / name
            if file_path.is_symlink() or not file_path.is_file() or name.endswith(".ko"):
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

    # Configure init scripts for kmod-qca-wifi-lowmem-profile
    if orig_pkg_name == "kmod-qca-wifi-lowmem-profile":
        # 1. Update load_cnss2 to use procd supervision with START=11
        init_cnss2 = pkg_dir / "files" / "etc" / "init.d" / "load_cnss2"
        if init_cnss2.is_file():
            cnss2_content = """#!/bin/sh /etc/rc.common
#
# Copyright (c) 2022-2023 Qualcomm Technologies, Inc.
# All Rights Reserved.
#

START=11
STOP=89

USE_PROCD=1
SVC_NAME=load_cnss2

start_service() {
\tlocal cnss2_args=""
\tlocal cnssd_args="-n -s"

\tfor arg in $(cat /proc/cmdline); do
\t\tcase "$arg" in
\t\t\tcnss2*)
\t\t\t\targ="$(echo $arg | awk -F '.' '{print$2}')"
\t\t\t\tcnss2_args="$cnss2_args $arg"
\t\t\t\t;;
\t\tesac
\tdone

\techo "Loading cnss2: $cnss2_args" > /dev/console
\tif [ -f /lib/modules/5.4.213/ipq_cnss2.ko ]; then
\t\tinsmod /lib/modules/5.4.213/ipq_cnss2.ko $cnss2_args 2>/dev/null || true
\telse
\t\tmodprobe ipq_cnss2 $cnss2_args 2>/dev/null || true
\tfi

\tprocd_open_instance $SVC_NAME
\tprocd_set_param command /usr/bin/cnssdaemon $cnssd_args
\tprocd_set_param respawn
\tprocd_set_param stdout 1
\tprocd_set_param stderr 1
\tprocd_close_instance
}

stop_service() {
\tkillall cnssdaemon 2>/dev/null || true
}
"""
            init_cnss2.write_text(cnss2_content)

        # 2. Disable automatic startup for qcawifi-config-cmd and diag_socket_app
        for init_name in ["qcawifi-config-cmd", "diag_socket_app"]:
            init_file = pkg_dir / "files" / "etc" / "init.d" / init_name
            if init_file.is_file():
                c = init_file.read_text()
                c = re.sub(r"^START=\d+", "START=", c, flags=re.MULTILINE)
                init_file.write_text(c)

    # Configure init script for qca-hostap
    if orig_pkg_name == "qca-hostap":
        init_hostapd = pkg_dir / "files" / "etc" / "init.d" / "qca-hostapd"
        if init_hostapd.is_file():
            hostapd_content = """#!/bin/sh /etc/rc.common
#
# Copyright (c) 2024 Qualcomm Technologies, Inc. / OpenWrt
# QCA Wi-Fi 6 / 7 Hostapd Service for Xiaomi Router BE3600 (RD15)
#

START=21
STOP=87

USE_PROCD=1
PROCD_DEBUG=1

setup_vaps() {
\tlocal retries=10
\twhile [ $retries -gt 0 ]; do
\t\t[ -d /sys/class/net/wifi0 ] && [ -d /sys/class/net/wifi1 ] && break
\t\tsleep 1
\t\tretries=$((retries - 1))
\tdone

\tlocal phy0=$(cat /sys/class/net/wifi0/phy80211/name 2>/dev/null || echo "phy1")
\tlocal phy1=$(cat /sys/class/net/wifi1/phy80211/name 2>/dev/null || echo "phy2")

\t# Ensure br-lan is up
\t[ -d /sys/class/net/br-lan ] || brctl addbr br-lan 2>/dev/null || true
\tip link set br-lan up 2>/dev/null || true

\tsysctl -w net.bridge.bridge-nf-call-iptables=0 2>/dev/null || true
\tsysctl -w net.bridge.bridge-nf-call-arptables=0 2>/dev/null || true
\tsysctl -w net.bridge.bridge-nf-call-ip6tables=0 2>/dev/null || true

\t# Create VAPs
\tif [ ! -d /sys/class/net/ath0 ]; then
\t\tiw phy "$phy0" interface add ath0 type __ap 2>/dev/null || true
\tfi
\tif [ ! -d /sys/class/net/ath1 ]; then
\t\tiw phy "$phy1" interface add ath1 type __ap 2>/dev/null || true
\tfi

\tbrctl addif br-lan ath0 2>/dev/null || true
\tbrctl addif br-lan ath1 2>/dev/null || true
\tip link set ath0 up 2>/dev/null || true
\tip link set ath1 up 2>/dev/null || true

\t# NAT and forwarding for Wi-Fi clients
\tiptables -I FORWARD -i br-lan -j ACCEPT 2>/dev/null || true
\tiptables -I FORWARD -o br-lan -j ACCEPT 2>/dev/null || true
\tiptables -t nat -I POSTROUTING -s 192.168.1.0/24 -j MASQUERADE 2>/dev/null || true
}

generate_configs() {
\tmkdir -p /var/run/hostapd

\tcat << 'EOF' > /var/run/hostapd-ath0.conf
driver=nl80211
interface=ath0
bridge=br-lan
ssid=OpenWrt_RD15_2.4G
hw_mode=g
channel=1
ieee80211n=1
ieee80211ax=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_passphrase=12345678
ctrl_interface=/var/run/hostapd
EOF

\tcat << 'EOF' > /var/run/hostapd-ath1.conf
driver=nl80211
interface=ath1
bridge=br-lan
ssid=OpenWrt_RD15_5G
hw_mode=a
channel=36
ieee80211n=1
ieee80211ac=1
ieee80211ax=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
wpa_passphrase=12345678
ctrl_interface=/var/run/hostapd
EOF
}

start_service() {
\tsetup_vaps
\tgenerate_configs

\tprocd_open_instance hostapd_2g
\tprocd_set_param command /usr/sbin/hostapd -P /var/run/hostapd-ath0.pid -e /var/run/entropy.bin /var/run/hostapd-ath0.conf
\tprocd_set_param respawn 3600 5 5
\tprocd_set_param stdout 1
\tprocd_set_param stderr 1
\tprocd_close_instance

\tprocd_open_instance hostapd_5g
\tprocd_set_param command /usr/sbin/hostapd -P /var/run/hostapd-ath1.pid -e /var/run/entropy.bin /var/run/hostapd-ath1.conf
\tprocd_set_param respawn 3600 5 5
\tprocd_set_param stdout 1
\tprocd_set_param stderr 1
\tprocd_close_instance
}

stop_service() {
\tkillall hostapd 2>/dev/null || true
\tbrctl delif br-lan ath0 2>/dev/null || true
\tbrctl delif br-lan ath1 2>/dev/null || true
\tiw dev ath0 del 2>/dev/null || true
\tiw dev ath1 del 2>/dev/null || true
}
"""
            init_hostapd.write_text(hostapd_content)



    print(f"Patching: {orig_pkg_name}")

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
