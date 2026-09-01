#!/usr/bin/env bash
# build_fit_kernel.sh — Упаковка скомпилированного ядра QSDK 12.4 в FIT образ для Xiaomi RD15
set -e

TOPDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_BIN="$TOPDIR/staging_dir/host/bin"
KERNEL_DIR="$TOPDIR/build_dir/target-arm_cortex-a7+neon-vfpv4_musl_eabi/linux-ipq53xx_rd15/linux-5.4.213"
OUR_IMAGE="$KERNEL_DIR/arch/arm/boot/Image"
OUR_DTB="$TOPDIR/target/linux/ipq53xx/rd15/ipq5332-rd15.dtb"
OUT_KERNEL="${1:-$TOPDIR/target/linux/ipq53xx/rd15/kernel}"

if [ ! -f "$OUR_IMAGE" ]; then
    echo "[!] Ошибка: скомпилированное ядро не найдено: $OUR_IMAGE" >&2
    exit 1
fi

if [ ! -f "$OUR_DTB" ]; then
    echo "[!] Ошибка: DTB файл не найден: $OUR_DTB" >&2
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[*] Сжатие ядра Linux 5.4.213 (QSDK 12.4) алгоритмом LZMA..."
"$HOST_BIN/lzma" e "$OUR_IMAGE" "$TMP_DIR/Image.lzma" -lc1 -lp2 -pb2

cat << 'EOF' > "$TMP_DIR/kernel.its"
/dts-v1/;

/ {
    description = "ARM OpenWrt FIT (Flattened Image Tree) - Clean QSDK 12.4 Kernel";
    #address-cells = <1>;

    images {
        kernel@1 {
            description = "ARM OpenWrt Linux-5.4.213 (QSDK 12.4)";
            data = /incbin/("Image.lzma");
            type = "kernel";
            arch = "arm";
            os = "linux";
            compression = "lzma";
            load = <0x40008000>;
            entry = <0x40008000>;
            hash@1 {
                algo = "crc32";
            };
            hash@2 {
                algo = "sha1";
            };
        };

        fdt@1 {
            description = "ARM OpenWrt ipq5332-mi04.1-c2 device tree blob";
            data = /incbin/("dtb");
            type = "flat_dt";
            arch = "arm";
            compression = "none";
            hash@1 {
                algo = "crc32";
            };
            hash@2 {
                algo = "sha1";
            };
        };
    };

    configurations {
        default = "config@1";
        config@1 {
            description = "OpenWrt";
            kernel = "kernel@1";
            fdt = "fdt@1";
        };
    };
};
EOF

cp "$OUR_DTB" "$TMP_DIR/dtb"

echo "[*] Сборка FIT-образа ядра через mkimage..."
PATH="$HOST_BIN:$PATH" "$HOST_BIN/mkimage" -f "$TMP_DIR/kernel.its" "$TMP_DIR/kernel.fit" >/dev/null

mkdir -p "$(dirname "$OUT_KERNEL")"
cp -f "$TMP_DIR/kernel.fit" "$OUT_KERNEL"

echo "[+] FIT-образ ядра успешно сформирован: $OUT_KERNEL ($(stat -c%s "$OUT_KERNEL") байт)"
"$HOST_BIN/mkimage" -l "$OUT_KERNEL"
