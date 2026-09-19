#!/bin/sh
# OpenWrt diag.sh for Xiaomi Router BE3600 (RD15)
# Controls front dual-color LEDs (blue:status, orange:status)

. /lib/functions/leds.sh

LED_BLUE="/sys/class/leds/blue:status"
LED_ORANGE="/sys/class/leds/orange:status"

set_state() {
	case "$1" in
	preinit|booting)
		# Solid orange during system boot
		[ -d "$LED_BLUE" ] && echo 0 > "$LED_BLUE/brightness" 2>/dev/null
		if [ -d "$LED_ORANGE" ]; then
			echo none > "$LED_ORANGE/trigger" 2>/dev/null
			echo 255 > "$LED_ORANGE/brightness" 2>/dev/null
		fi
		;;
	failsafe)
		# Fast orange blinking in failsafe mode (100ms on, 100ms off)
		[ -d "$LED_BLUE" ] && echo 0 > "$LED_BLUE/brightness" 2>/dev/null
		if [ -d "$LED_ORANGE" ]; then
			echo timer > "$LED_ORANGE/trigger" 2>/dev/null
			echo 100 > "$LED_ORANGE/delay_on" 2>/dev/null
			echo 100 > "$LED_ORANGE/delay_off" 2>/dev/null
		fi
		;;
	upgrade)
		# Fast orange blinking during firmware upgrade (150ms on, 150ms off)
		[ -d "$LED_BLUE" ] && echo 0 > "$LED_BLUE/brightness" 2>/dev/null
		if [ -d "$LED_ORANGE" ]; then
			echo timer > "$LED_ORANGE/trigger" 2>/dev/null
			echo 150 > "$LED_ORANGE/delay_on" 2>/dev/null
			echo 150 > "$LED_ORANGE/delay_off" 2>/dev/null
		fi
		;;
	done|running)
		# Solid blue when system is fully ready
		[ -d "$LED_ORANGE" ] && echo 0 > "$LED_ORANGE/brightness" 2>/dev/null
		if [ -d "$LED_BLUE" ]; then
			echo none > "$LED_BLUE/trigger" 2>/dev/null
			echo 255 > "$LED_BLUE/brightness" 2>/dev/null
		fi
		;;
	off)
		[ -d "$LED_BLUE" ] && echo 0 > "$LED_BLUE/brightness" 2>/dev/null
		[ -d "$LED_ORANGE" ] && echo 0 > "$LED_ORANGE/brightness" 2>/dev/null
		;;
	esac
}
