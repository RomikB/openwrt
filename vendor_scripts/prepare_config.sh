#!/bin/sh

set -e

enable() {
    echo "CONFIG_${1}=${2:-y}" >> .config
}

disable() {
    echo "# CONFIG_${1} is not set" >> .config
}

echo "Preparing target configuration for Xiaomi Router BE3600 (RD15)..."

rm -f .config

enable TARGET_ipq53xx
enable TARGET_ipq53xx_rd15
enable TARGET_ipq53xx_rd15_DEVICE_xiaomi-rd15-prebuild
disable USE_SECCOMP

make defconfig

echo "Configuration successfully prepared."
