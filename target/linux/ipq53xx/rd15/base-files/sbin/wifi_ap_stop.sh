#!/bin/sh
#
# Wi-Fi AP Stop Script for Xiaomi Router BE3600 (RD15)
#

echo "Stopping hostapd..."
killall hostapd 2>/dev/null || true
rm -f /var/run/hostapd-ath0.pid /var/run/hostapd-ath1.pid

echo "Detaching and destroying VAPs..."
brctl delif br-lan ath0 2>/dev/null || true
brctl delif br-lan ath1 2>/dev/null || true
iw dev ath0 del 2>/dev/null || true
iw dev ath1 del 2>/dev/null || true

echo "Wi-Fi AP stopped."
