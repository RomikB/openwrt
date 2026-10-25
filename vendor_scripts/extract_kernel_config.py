#!/usr/bin/env python3
"""
extract_kernel_config.py

Extracts the embedded kernel .config (IKCONFIG) from a precompiled vendor Linux kernel FIT image.
"""

import sys
import os
import struct
import lzma
import gzip
import glob
import re

def parse_fit_kernel(kernel_path):
    with open(kernel_path, "rb") as f:
        buf = f.read()

    if len(buf) < 64:
        raise ValueError(f"File {kernel_path} is too small to be a valid FIT image.")

    magic, totalsize, off_dt_struct, off_dt_strings = struct.unpack(">IIII", buf[:16])
    if magic != 0xd00dfeed:
        raise ValueError(f"Invalid FIT image magic: {hex(magic)} (expected 0xd00dfeed)")

    def get_str(offset):
        end = buf.find(b"\x00", off_dt_strings + offset)
        if end == -1:
            return ""
        return buf[off_dt_strings + offset:end].decode("latin1", errors="ignore")

    p = off_dt_struct
    kernel_data = None

    while p < off_dt_strings and p < len(buf):
        tag = struct.unpack(">I", buf[p:p+4])[0]
        p += 4
        if tag == 1:  # FDT_BEGIN_NODE
            name_end = buf.find(b"\x00", p)
            p = (name_end + 1 + 3) & ~3
        elif tag == 2:  # FDT_END_NODE
            pass
        elif tag == 3:  # FDT_PROP
            plen, nameoff = struct.unpack(">II", buf[p:p+8])
            p += 8
            prop_name = get_str(nameoff)
            if prop_name == "data" and plen > 500000:
                kernel_data = buf[p:p+plen]
            p = (p + plen + 3) & ~3
        elif tag == 4:  # FDT_NOP
            pass
        elif tag == 9:  # FDT_END
            break

    if not kernel_data:
        raise ValueError("Could not find kernel payload data inside FIT image.")

    return kernel_data

def decompress_payload(kernel_data):
    try:
        return lzma.decompress(kernel_data)
    except Exception:
        return lzma.decompress(kernel_data, format=lzma.FORMAT_ALONE)

def extract_ikconfig(decompressed_kernel):
    ikcfg_st = decompressed_kernel.find(b"IKCFG_ST")
    ikcfg_ed = decompressed_kernel.find(b"IKCFG_ED")

    if ikcfg_st == -1 or ikcfg_ed == -1 or ikcfg_ed <= ikcfg_st:
        raise ValueError("IKCONFIG markers (IKCFG_ST / IKCFG_ED) not found in decompressed kernel.")

    gzip_data = decompressed_kernel[ikcfg_st + 8:ikcfg_ed]
    config_text = gzip.decompress(gzip_data).decode("utf-8", errors="ignore")
    return config_text

def parse_configs_y(config_text):
    configs_y = set()
    for line in config_text.splitlines():
        line = line.strip()
        if line.endswith("=y"):
            opt = line.split("=")[0].strip()
            configs_y.add(opt)
    return configs_y

def collect_mk_variables(openwrt_root):
    var_map = {
        "LINUX_KARCH": "arm",
        "ARCH": "arm",
        "LED_TRIGGER_DIR": "drivers/leds/trigger",
        "USBNET_DIR": "drivers/net/usb",
        "USBHID_DIR": "drivers/hid/usbhid",
        "USBINPUT_DIR": "input/misc",
        "WATCHDOG_DIR": "watchdog",
        "V4L2_DIR": "v4l2-core",
        "V4L2_USB_DIR": "usb",
        "V4L2_MEM2MEM_DIR": "platform",
    }
    modules_mk_pattern = os.path.join(openwrt_root, "package", "kernel", "linux", "modules", "*.mk")
    for mk in sorted(glob.glob(modules_mk_pattern)):
        with open(mk, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                m = re.match(r"^([A-Za-z0-9_]+)\s*[:?]?=\s*(.*)$", line.strip())
                if m:
                    name, val = m.group(1), m.group(2).strip()
                    if not name.startswith("KernelPackage") and not name.startswith("Package") and not name.startswith("CONFIG_"):
                        # Clean trailing backslashes and comments
                        val = val.split("#")[0].strip().rstrip("\\").strip()
                        if val and "$(" not in val:
                            var_map[name] = val
    return var_map

def expand_path(path_str, var_map):
    res = path_str.replace("$(LINUX_DIR)/", "")
    for k, v in var_map.items():
        res = res.replace(f"$({k})", v)
    return res

def find_builtin_modules(configs_y, openwrt_root):
    var_map = collect_mk_variables(openwrt_root)
    modules_mk_pattern = os.path.join(openwrt_root, "package", "kernel", "linux", "modules", "*.mk")
    builtin_modules = set()

    for mk_file in sorted(glob.glob(modules_mk_pattern)):
        with open(mk_file, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        packages = re.split(r"define KernelPackage/", content)
        for pkg in packages[1:]:
            lines = pkg.split("\n")
            kconfig = []
            files = []
            in_kconfig = False
            in_files = False

            for l in lines:
                if l.startswith("endef"):
                    break
                if "KCONFIG:=" in l or "KCONFIG+=" in l:
                    in_kconfig = True
                    in_files = False
                    val = l.split("=", 1)[1].strip()
                    kconfig.extend(val.split())
                elif "FILES:=" in l or "FILES+=" in l:
                    in_files = True
                    in_kconfig = False
                    val = l.split("=", 1)[1].strip()
                    files.extend(val.split())
                elif in_kconfig and (l.startswith("\t") or l.startswith("  ")):
                    kconfig.extend(l.strip().split())
                elif in_files and (l.startswith("\t") or l.startswith("  ")):
                    files.extend(l.strip().split())
                elif not (l.startswith("\t") or l.startswith("  ")):
                    in_kconfig = False
                    in_files = False

            is_builtin = False
            for kc in kconfig:
                kc_clean = kc.split("=")[0].strip("\\")
                if kc_clean in configs_y:
                    is_builtin = True
                    break

            if is_builtin:
                for fpath in files:
                    fpath_clean = expand_path(fpath.strip("\\"), var_map)
                    if fpath_clean.endswith(".ko") and "$(" not in fpath_clean:
                        builtin_modules.add(fpath_clean)

    return sorted(list(builtin_modules))

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <path_to_fit_kernel> <output_dir> [openwrt_root]", file=sys.stderr)
        sys.exit(1)

    kernel_path = sys.argv[1]
    output_dir = sys.argv[2]
    openwrt_root = sys.argv[3] if len(sys.argv) > 3 else os.getcwd()

    if not os.path.isfile(kernel_path):
        print(f"Error: Kernel file not found at {kernel_path}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    print(f"Parsing FIT kernel image: {kernel_path}")
    kernel_payload = parse_fit_kernel(kernel_path)

    print(f"Decompressing kernel LZMA payload ({len(kernel_payload)} bytes)...")
    decompressed = decompress_payload(kernel_payload)
    print(f"Decompressed kernel size: {len(decompressed)} bytes")

    print("Extracting IKCONFIG...")
    config_text = extract_ikconfig(decompressed)
    configs_y = parse_configs_y(config_text)
    print(f"Extracted kernel config: {len(config_text.splitlines())} lines, {len(configs_y)} built-in (=y) options")

    config_out = os.path.join(output_dir, "config-5.4.vendor")
    with open(config_out, "w", encoding="utf-8") as f:
        f.write(config_text)
    print(f"Saved kernel config to: {config_out}")

if __name__ == "__main__":
    main()
