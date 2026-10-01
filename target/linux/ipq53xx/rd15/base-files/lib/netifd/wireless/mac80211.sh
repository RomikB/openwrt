#!/bin/sh
#
# Netifd Wireless Driver Integration for Qualcomm Direct Connect on OpenWrt 24
# Bridges netifd UCI state and ubus 'network.wireless' with qca-hostapd and qca-wpa-supplicant
#

. /lib/netifd/netifd-wireless.sh

init_wireless_driver "$@"

drv_mac80211_init_device_config() {
	config_add_string channel band htmode hwmode country disabled
}

drv_mac80211_init_iface_config() {
	config_add_string ssid encryption key ifname mode network isolate hidden disabled bssid wds wmm ieee80211w sae_password sae_pwe macaddr wps_pushbutton
}

drv_mac80211_init_vlan_config() {
	:
}

drv_mac80211_init_station_config() {
	:
}

wait_hostapd_sock() {
	local sock="$1"
	local timeout="${2:-15}"
	local i=0
	while [ $i -lt $timeout ]; do
		[ -S "$sock" ] && return 0
		sleep 1
		i=$((i + 1))
	done
	return 1
}

ensure_vap_netdev() {
	local dev="$1"
	local ifname="$2"
	local mode="$3"

	[ -d "/sys/class/net/${ifname}" ] && return 0

	local wlandev="wifi0"
	local phy="phy1"
	if [ "$dev" = "radio1" ]; then
		wlandev="wifi1"
		phy="phy2"
	fi

	local i=0
	while [ $i -lt 10 ]; do
		[ -d "/sys/class/net/${wlandev}" ] && break
		sleep 1
		i=$((i + 1))
	done

	local pmode="ap"
	local wlanmode="__ap"
	if [ "$mode" = "sta" ] || [ "$mode" = "sta-wds" ]; then
		pmode="sta"
		wlanmode="managed"
	fi

	if ! iw phy "$phy" interface add "$ifname" type "$wlanmode" 2>/dev/null; then
		wlanconfig "$ifname" create wlandev "$wlandev" wlanmode "$pmode" -cfg80211 2>/dev/null || \
		wlanconfig "$ifname" create wlandev "$wlandev" wlanmode "$pmode" 2>/dev/null || true
	fi
}

restart_hostapd_instance() {
	local ifname="$1"
	local bridge="$2"
	local conf="/var/run/hostapd-${ifname}.conf"
	local active="/var/run/hostapd-${ifname}.conf.active"
	local pid_file="/var/run/hostapd-${ifname}.pid"
	local sock_file="/var/run/hostapd/${ifname}"

	[ -f "$conf" ] || return 0

	local pids=$(pgrep -f "hostapd.*${conf}")
	if [ -n "$pids" ]; then
		# If socket is ready and active configuration matches, keep running instance
		if [ -S "$sock_file" ] && [ -f "$active" ] && cmp -s "$conf" "$active"; then
			return 0
		fi

		# If socket is still starting up, wait briefly before killing
		if [ ! -S "$sock_file" ]; then
			if wait_hostapd_sock "$sock_file" 5 && [ -f "$active" ] && cmp -s "$conf" "$active"; then
				return 0
			fi
		fi

		# Check if physical/RF parameters did NOT change between active and new config.
		# If only logical parameters (SSID, encryption, password, PMF, isolate) changed,
		# perform dynamic reload via hostapd_cli to avoid dropping RF link and triggering
		# 60-second DFS CAC on 5 GHz (160 MHz).
		if [ -S "$sock_file" ] && [ -f "$active" ]; then
			local rf_active rf_conf
			rf_active=$(grep -E '^(driver|interface|bridge|hw_mode|channel|country_code|ieee80211[acdenx]|ht_capab|.*_oper_|ssid)' "$active" 2>/dev/null)
			rf_conf=$(grep -E '^(driver|interface|bridge|hw_mode|channel|country_code|ieee80211[acdenx]|ht_capab|.*_oper_|ssid)' "$conf" 2>/dev/null)
			if [ "$rf_active" = "$rf_conf" ]; then
				local res
				res=$(hostapd_cli -i "$ifname" reload_config 2>/dev/null)
				[ "$res" != "OK" ] && res=$(hostapd_cli -i "$ifname" reload 2>/dev/null)
				if [ "$res" = "OK" ]; then
					cp -f "$conf" "$active" 2>/dev/null || true
					logger -t mac80211 "Successfully reloaded hostapd for $ifname without RF reset"
					return 0
				fi
			fi
		fi

		# Configuration changed physical parameters or daemon unresponsive: restart cleanly
		kill -15 $pids 2>/dev/null || true
		sleep 1
		kill -9 $pids 2>/dev/null || true
	fi
	local old_pid=$(cat "$pid_file" 2>/dev/null)
	[ -n "$old_pid" ] && kill -9 "$old_pid" 2>/dev/null || true

	rm -f "$pid_file" "$sock_file" "$active"
	mkdir -p /var/run/hostapd

	# Ensure bridge association and link state
	if [ -n "$bridge" ] && [ -d "/sys/class/net/${bridge}" ]; then
		brctl addif "$bridge" "$ifname" 2>/dev/null || true
	fi
	ip link set "$ifname" up 2>/dev/null || true

	# Start fresh hostapd daemon
	/usr/sbin/hostapd -B -P "$pid_file" -e /var/run/entropy.bin "$conf" 2>/dev/null || true
	cp -f "$conf" "$active" 2>/dev/null || true

	# Wait for control socket to be created before returning to netifd
	if ! wait_hostapd_sock "$sock_file" 15; then
		logger -t mac80211 "WARNING: $sock_file not ready within 15s"
	fi
}

restart_supplicant_instance() {
	local ifname="$1"
	local bridge="$2"
	local conf="/var/run/wpa_supplicant-${ifname}.conf"
	local active="/var/run/wpa_supplicant-${ifname}.conf.active"
	local pid_file="/var/run/wpa_supplicant-${ifname}.pid"
	local sock_file="/var/run/wpa_supplicant/${ifname}"

	[ -f "$conf" ] || return 0

	local pids=$(pgrep -f "wpa_supplicant.*${conf}")
	if [ -n "$pids" ]; then
		if [ -S "$sock_file" ] && [ -f "$active" ] && cmp -s "$conf" "$active"; then
			return 0
		fi

		if [ ! -S "$sock_file" ]; then
			if wait_hostapd_sock "$sock_file" 5 && [ -f "$active" ] && cmp -s "$conf" "$active"; then
				return 0
			fi
		fi

		if [ -S "$sock_file" ] && [ -f "$active" ]; then
			if [ "$(wpa_cli -i "$ifname" reconfigure 2>/dev/null)" = "OK" ]; then
				cp -f "$conf" "$active" 2>/dev/null || true
				logger -t mac80211 "Successfully reconfigured wpa_supplicant for $ifname"
				return 0
			fi
		fi

		kill -15 $pids 2>/dev/null || true
		sleep 1
		kill -9 $pids 2>/dev/null || true
	fi
	local old_pid=$(cat "$pid_file" 2>/dev/null)
	[ -n "$old_pid" ] && kill -9 "$old_pid" 2>/dev/null || true

	rm -f "$pid_file" "$sock_file" "$active"
	mkdir -p /var/run/wpa_supplicant

	# If WDS 4-address mode, bridge association is permitted
	if [ -n "$bridge" ] && [ -d "/sys/class/net/${bridge}" ]; then
		brctl addif "$bridge" "$ifname" 2>/dev/null || true
	fi
	ip link set "$ifname" up 2>/dev/null || true

	local br_opt=""
	[ -n "$bridge" ] && br_opt="-b $bridge"

	# Start fresh wpa_supplicant daemon
	/usr/sbin/wpa_supplicant -B -s -P "$pid_file" -D nl80211 -i "$ifname" -c "$conf" $br_opt 2>/dev/null || true
	cp -f "$conf" "$active" 2>/dev/null || true

	# Wait for control socket to be created
	if ! wait_hostapd_sock "$sock_file" 15; then
		logger -t mac80211 "WARNING: $sock_file not ready within 15s"
	fi
}

mac80211_setup_vif() {
	local vif="$1"
	local ifname mode network disabled ssid encryption key wds isolate hidden bssid wps_pushbutton
	local network_bridge

	json_get_var network_bridge bridge
	json_select config
	json_get_vars ifname mode network disabled ssid encryption key wds isolate hidden bssid wps_pushbutton
	json_select ..

	[ -z "$mode" ] && mode="ap"

	if [ -z "$ifname" ]; then
		if [ "$mode" = "sta" ] || [ "$mode" = "sta-wds" ]; then
			if [ "$__netifd_device" = "radio0" ]; then
				ifname="ath01"
			else
				ifname="ath11"
			fi
		else
			# AP mode
			if [ "$__netifd_device" = "radio0" ]; then
				if [ "${primary_ap_used_r0:-0}" -ne 1 ]; then
					ifname="ath0"
					primary_ap_used_r0=1
				else
					vap_count_r0=$(( ${vap_count_r0:-1} + 1 ))
					ifname="ath0${vap_count_r0}"
				fi
			else
				if [ "${primary_ap_used_r1:-0}" -ne 1 ]; then
					ifname="ath1"
					primary_ap_used_r1=1
				else
					vap_count_r1=$(( ${vap_count_r1:-1} + 1 ))
					ifname="ath1${vap_count_r1}"
				fi
			fi
		fi
	fi

	if [ "${disabled:-0}" -eq 1 ]; then
		if [ -n "$ifname" ]; then
			local hpid=$(cat "/var/run/hostapd-${ifname}.pid" 2>/dev/null)
			[ -n "$hpid" ] && kill -9 $hpid 2>/dev/null || true
			local spid=$(cat "/var/run/wpa_supplicant-${ifname}.pid" 2>/dev/null)
			[ -n "$spid" ] && kill -9 $spid 2>/dev/null || true
			rm -f "/var/run/hostapd-${ifname}.pid" "/var/run/hostapd-${ifname}.conf.active" "/var/run/hostapd/${ifname}"
			rm -f "/var/run/wpa_supplicant-${ifname}.pid" "/var/run/wpa_supplicant-${ifname}.conf.active" "/var/run/wpa_supplicant/${ifname}"
			if [ "$ifname" != "ath0" ] && [ "$ifname" != "ath1" ]; then
				ip link set "$ifname" down 2>/dev/null || true
			fi
		fi
		return 0
	fi

	# Ensure kernel VAP exists
	ensure_vap_netdev "$__netifd_device" "$ifname" "$mode"

	if [ "$mode" = "sta" ] || [ "$mode" = "sta-wds" ]; then
		local br=""
		[ "$mode" = "sta-wds" -o "${wds:-0}" -eq 1 ] && br="$network_bridge"
		restart_supplicant_instance "$ifname" "$br"
	else
		local br="$network_bridge"
		if [ -z "$br" ]; then
			if [ "$network" = "lan" ] || [ -z "$network" ]; then
				br="br-lan"
			elif [ -d "/sys/class/net/br-${network}" ]; then
				br="br-${network}"
			elif [ -d "/sys/class/net/${network}" ]; then
				br="${network}"
			fi
		fi
		restart_hostapd_instance "$ifname" "$br"
	fi

	wireless_add_vif "$vif" "$ifname"
}

drv_mac80211_setup() {
	local dev="$1"

	# Regenerate hostapd and wpa_supplicant configurations from UCI
	[ -x /lib/wifi/hostapd_config.sh ] && /lib/wifi/hostapd_config.sh all
	[ -x /lib/wifi/wpa_supplicant_config.sh ] && /lib/wifi/wpa_supplicant_config.sh all

	primary_ap_used_r0=0
	primary_ap_used_r1=0
	vap_count_r0=0
	vap_count_r1=0

	local prefix="ath0"
	[ "$dev" = "radio1" ] && prefix="ath1"

	# Terminate any leftover daemons whose configs no longer exist (e.g. interface disabled)
	for ifname in "${prefix}" "${prefix}1" "${prefix}2" "${prefix}3"; do
		if [ ! -f "/var/run/hostapd-${ifname}.conf" ]; then
			local hpid=$(cat "/var/run/hostapd-${ifname}.pid" 2>/dev/null)
			[ -n "$hpid" ] && kill -9 $hpid 2>/dev/null || true
			rm -f "/var/run/hostapd-${ifname}.pid" "/var/run/hostapd-${ifname}.conf.active" "/var/run/hostapd/${ifname}"
			if [ "$ifname" != "ath0" ] && [ "$ifname" != "ath1" ]; then
				if [ -d "/sys/class/net/${ifname}" ]; then
					ip link set "$ifname" down 2>/dev/null || true
					iw dev "$ifname" del 2>/dev/null || true
					wlanconfig "$ifname" destroy 2>/dev/null || true
				fi
			fi
		fi
		if [ ! -f "/var/run/wpa_supplicant-${ifname}.conf" ]; then
			local spid=$(cat "/var/run/wpa_supplicant-${ifname}.pid" 2>/dev/null)
			[ -n "$spid" ] && kill -9 $spid 2>/dev/null || true
			rm -f "/var/run/wpa_supplicant-${ifname}.pid" "/var/run/wpa_supplicant-${ifname}.conf.active" "/var/run/wpa_supplicant/${ifname}"
			if [ "$ifname" != "ath0" ] && [ "$ifname" != "ath1" ]; then
				if [ -d "/sys/class/net/${ifname}" ]; then
					ip link set "$ifname" down 2>/dev/null || true
					iw dev "$ifname" del 2>/dev/null || true
					wlanconfig "$ifname" destroy 2>/dev/null || true
				fi
			fi
		fi
	done

	# Clean up orphaned wireless client network interfaces if their wifi-iface was deleted
	local sys_nets="loopback lan wan wan6 guest eth0 eth1 eth0_1 eth0_2 eth0_3"
	local wireless_nets=$(uci -q show wireless | grep -E "\.network=" | cut -d"=" -f2 | tr -d "'" | sort -u)
	local net_changed=0

	for net in $(uci -q show network | grep "=interface" | cut -d. -f2 | cut -d= -f1); do
		local is_sys=0
		for s in $sys_nets; do [ "$net" = "$s" ] && is_sys=1; done
		[ $is_sys -eq 1 ] && continue

		# Never delete virtual, relay, tunnel, or VPN interfaces
		local proto=$(uci -q get "network.${net}.proto")
		case "$proto" in
			relay|wireguard|amneziawg|gre*|vxlan|ipip|6*|dslite|map|ppp*|qmi|mbim)
				continue
				;;
		esac

		local is_used=0
		for w in $wireless_nets; do [ "$net" = "$w" ] && is_used=1; done
		if [ $is_used -eq 0 ]; then
			local dev=$(uci -q get "network.${net}.device")
			if [ -z "$dev" ] || [ "$dev" = "ath01" ] || [ "$dev" = "ath11" ]; then
				logger -t mac80211 "Cleaning up orphaned network interface: $net"
				uci -q delete "network.${net}"
				net_changed=1
			fi
		fi
	done

	# For any active STA interface, ensure it has a distinct route metric to prevent clashing with WAN
	local sta_nets=$(uci -q show wireless | grep -E "\.mode='sta'|\.mode='sta-wds'" | while read -r line; do
		local sec=$(echo "$line" | cut -d. -f2)
		local dis=$(uci -q get "wireless.${sec}.disabled")
		if [ "${dis:-0}" -eq 0 ]; then
			uci -q get "wireless.${sec}.network"
		fi
	done | sort -u)

	for snet in $sta_nets; do
		if [ -n "$snet" ] && uci -q get "network.${snet}" >/dev/null; then
			local cur_metric=$(uci -q get "network.${snet}.metric")
			if [ -z "$cur_metric" ]; then
				logger -t mac80211 "Setting default fallback metric 20 on STA network: $snet"
				uci -q set "network.${snet}.metric=20"
				net_changed=1
			fi
		fi
	done

	if [ "$net_changed" -eq 1 ]; then
		uci commit network
		ubus call network reload 2>/dev/null || true
	fi

	# Process configured VAPs for this device
	for_each_interface "ap sta adhoc mesh monitor" mac80211_setup_vif

	# Mark radio as up in netifd / ubus
	wireless_set_up
}

drv_mac80211_teardown() {
	local dev="$1"
	local prefix="ath0"
	[ "$dev" = "radio1" ] && prefix="ath1"

	# Stop daemons and clean up VAPs for this radio
	for ifname in "${prefix}" "${prefix}1" "${prefix}2" "${prefix}3"; do
		local hpid=$(cat "/var/run/hostapd-${ifname}.pid" 2>/dev/null)
		[ -n "$hpid" ] && kill -9 $hpid 2>/dev/null || true
		local spid=$(cat "/var/run/wpa_supplicant-${ifname}.pid" 2>/dev/null)
		[ -n "$spid" ] && kill -9 $spid 2>/dev/null || true

		rm -f "/var/run/hostapd-${ifname}.pid" "/var/run/hostapd-${ifname}.conf.active" "/var/run/hostapd/${ifname}"
		rm -f "/var/run/wpa_supplicant-${ifname}.pid" "/var/run/wpa_supplicant-${ifname}.conf.active" "/var/run/wpa_supplicant/${ifname}"

		# Secondary VAPs (ath01, ath11, etc.) can be cleaned up cleanly
		if [ "$ifname" != "ath0" ] && [ "$ifname" != "ath1" ]; then
			if [ -d "/sys/class/net/${ifname}" ]; then
				ip link set "$ifname" down 2>/dev/null || true
				iw dev "$ifname" del 2>/dev/null || true
				wlanconfig "$ifname" destroy 2>/dev/null || true
			fi
		fi
	done
}

add_driver mac80211
