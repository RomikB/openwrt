#!/bin/sh
#
# Netifd Wireless Driver Integration for Qualcomm Direct Connect on OpenWrt 24
# Bridges netifd UCI state and ubus 'network.wireless' with qca-hostapd and iwinfo
#

. /lib/netifd/netifd-wireless.sh

init_wireless_driver "$@"

drv_mac80211_init_device_config() {
	config_add_string channel band htmode hwmode country disabled
}

drv_mac80211_init_iface_config() {
	config_add_string ssid encryption key ifname mode network isolate hidden disabled
}

drv_mac80211_init_vlan_config() {
	:
}

drv_mac80211_init_station_config() {
	:
}

mac80211_setup_vif() {
	local vif="$1"
	local ifname

	json_get_vars ifname
	if [ -z "$ifname" ]; then
		if [ "$__netifd_device" = "radio0" ]; then
			ifname="ath0"
		else
			ifname="ath1"
		fi
	fi

	wireless_add_vif "$vif" "$ifname"
}

restart_hostapd_instance() {
	local ifname="$1"
	local conf="/var/run/hostapd-${ifname}.conf"
	local active="/var/run/hostapd-${ifname}.conf.active"
	local pid_file="/var/run/hostapd-${ifname}.pid"
	local sock_file="/var/run/hostapd/${ifname}"

	[ -f "$conf" ] || return 0

	local pids=$(pgrep -f "hostapd-${ifname}.conf")

	# If process is running, socket exists, and configuration matches, do nothing
	if [ -n "$pids" ] && [ -S "$sock_file" ] && [ -f "$active" ] && cmp -s "$conf" "$active"; then
		return 0
	fi

	# Stop old instance cleanly
	if [ -n "$pids" ]; then
		kill -15 $pids 2>/dev/null || true
		sleep 1
		kill -9 $pids 2>/dev/null || true
	fi
	local old_pid=$(cat "$pid_file" 2>/dev/null)
	[ -n "$old_pid" ] && kill -9 "$old_pid" 2>/dev/null || true

	rm -f "$pid_file" "$sock_file" "$active"
	mkdir -p /var/run/hostapd

	# Ensure bridge association and link state
	[ -d "/sys/class/net/${ifname}" ] && brctl addif br-lan "$ifname" 2>/dev/null || true
	[ -d "/sys/class/net/${ifname}" ] && ip link set "$ifname" up 2>/dev/null || true

	# Start fresh hostapd daemon
	/usr/sbin/hostapd -B -P "$pid_file" -e /var/run/entropy.bin "$conf" 2>/dev/null || true
	cp -f "$conf" "$active" 2>/dev/null || true
}

drv_mac80211_setup() {
	local dev="$1"

	# Regenerate hostapd configurations from UCI
	[ -x /lib/wifi/hostapd_config.sh ] && /lib/wifi/hostapd_config.sh all

	local ifname="ath0"
	[ "$dev" = "radio1" ] && ifname="ath1"

	# Smartly restart only if changed or unhealthy
	restart_hostapd_instance "$ifname"

	# Register configured VAPs for this device with netifd
	for_each_interface "ap sta adhoc mesh monitor" mac80211_setup_vif

	# Immediately mark radio as up in netifd / ubus
	wireless_set_up
}

drv_mac80211_teardown() {
	local dev="$1"
	local ifname="ath0"
	[ "$dev" = "radio1" ] && ifname="ath1"

	local pids=$(pgrep -f "hostapd-${ifname}.conf")
	[ -n "$pids" ] && kill -9 $pids 2>/dev/null || true
	local old_pid=$(cat "/var/run/hostapd-${ifname}.pid" 2>/dev/null)
	[ -n "$old_pid" ] && kill -9 "$old_pid" 2>/dev/null || true
	rm -f "/var/run/hostapd-${ifname}.pid" "/var/run/hostapd-${ifname}.conf.active" "/var/run/hostapd/${ifname}"

	wireless_set_down
}

add_driver mac80211
