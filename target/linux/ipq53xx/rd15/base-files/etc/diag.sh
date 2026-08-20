#!/bin/sh
# OpenWrt diag.sh for Xiaomi Router BE3600 (RD15)
# Controls front RGB LED via /sys/class/leds/rgb

. /lib/functions/leds.sh

LED_SYSFS="/sys/class/leds/rgb"
COLOR_OFF=0
COLOR_BLUE=1207959552
COLOR_ORANGE=4718592
COLOR_PURPLE=573767680

set_rgb_led() {
	local color="$1"
	local trigger="${2:-none}"
	local delay_on="${3:-200}"
	local delay_off="${4:-200}"

	[ -d "$LED_SYSFS" ] || return 0

	echo "$trigger" > "$LED_SYSFS/trigger" 2>/dev/null || true
	echo "$color" > "$LED_SYSFS/brightness" 2>/dev/null || true

	if [ "$trigger" = "timer" ]; then
		echo "$delay_on" > "$LED_SYSFS/delay_on" 2>/dev/null || true
		echo "$delay_off" > "$LED_SYSFS/delay_off" 2>/dev/null || true
	fi
}

set_state() {
	case "$1" in
	preinit|booting)
		# Orange breathing / solid during system boot
		set_rgb_led "$COLOR_ORANGE" none
		;;
	failsafe)
		# Fast orange blinking in failsafe mode
		set_rgb_led "$COLOR_ORANGE" timer 100 100
		;;
	upgrade)
		# Fast orange blinking during firmware flash
		set_rgb_led "$COLOR_ORANGE" timer 150 150
		;;
	done|running)
		# Solid blue when system is fully ready
		set_rgb_led "$COLOR_BLUE" none
		;;
	off)
		set_rgb_led "$COLOR_OFF" none
		;;
	esac
}
