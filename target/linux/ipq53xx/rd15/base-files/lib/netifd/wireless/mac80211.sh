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
	config_add_string ssid encryption key ifname mode network isolate hidden disabled bssid wds wmm ieee80211w sae_password sae_pwe macaddr wps_pushbutton \
		ieee80211r mobility_domain nasid reassociation_deadline ft_over_ds ft_psk_generate_local r0_key_lifetime r1_key_holder pmk_r1_push \
		ieee80211k rrm_neighbor_report rrm_beacon_report \
		ieee80211v time_advertisement time_zone wnm_sleep_mode wnm_sleep_mode_no_keys bss_transition proxy_arp extap
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
	local macaddr="$4"

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
	if [ "$mode" = "sta" ] || [ "$mode" = "sta-wds" ] || [ "$mode" = "sta-extap" ]; then
		pmode="sta"
		wlanmode="managed"
		if [ -z "$macaddr" ] && [ -f "/sys/class/net/${wlandev}/address" ]; then
			local bmac=$(cat "/sys/class/net/${wlandev}/address" 2>/dev/null)
			if [ -n "$bmac" ]; then
				local b0=$(echo "$bmac" | cut -d: -f1)
				local b1=$(echo "$bmac" | cut -d: -f2)
				local b2=$(echo "$bmac" | cut -d: -f3)
				local b3=$(echo "$bmac" | cut -d: -f4)
				local b4=$(echo "$bmac" | cut -d: -f5)
				local b5=$(echo "$bmac" | cut -d: -f6)
				local b0_hex=$(printf "%02x" $(( 0x$b0 ^ 0x06 )))
				macaddr="${b0_hex}:${b1}:${b2}:${b3}:${b4}:${b5}"
			fi
		fi
	fi

	local bssid_opt=""
	[ -n "$macaddr" ] && bssid_opt="-bssid $macaddr"

	if ! iw phy "$phy" interface add "$ifname" type "$wlanmode" 2>/dev/null; then
		wlanconfig "$ifname" create wlandev "$wlandev" wlanmode "$pmode" $bssid_opt -cfg80211 2>/dev/null || \
		wlanconfig "$ifname" create wlandev "$wlandev" wlanmode "$pmode" $bssid_opt 2>/dev/null || true
	fi
	[ -n "$macaddr" ] && ip link set "$ifname" address "$macaddr" 2>/dev/null || true
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
	# Ensure interface is down before hostapd initializes driver mode
	ip link set "$ifname" down 2>/dev/null || true

	# Start fresh hostapd daemon
	/usr/sbin/hostapd -B -P "$pid_file" -e /var/run/entropy.bin "$conf" 2>/dev/null || true
	cp -f "$conf" "$active" 2>/dev/null || true

	# Wait for control socket to be created before returning to netifd
	if ! wait_hostapd_sock "$sock_file" 15; then
		logger -t mac80211 "WARNING: $sock_file not ready within 15s"
	fi
}

ensure_supplicant_bridge() {
	local ifname="$1"
	local bridge="$2"
	local extap="${3:-0}"

	[ -n "$bridge" ] && [ -d "/sys/class/net/${bridge}" ] || return 0

	# If already enslaved, affirm extap if needed
	if [ -d "/sys/class/net/${bridge}/brif/${ifname}" ]; then
		[ "${extap:-0}" -eq 1 ] && [ -x /usr/sbin/cfg80211tool ] && /usr/sbin/cfg80211tool "$ifname" extap 1 2>/dev/null || true
		return 0
	fi

	ip link set "$ifname" down 2>/dev/null || true
	if [ "${extap:-0}" -eq 1 ]; then
		[ -x /usr/sbin/cfg80211tool ] && /usr/sbin/cfg80211tool "$ifname" extap 1 2>/dev/null || true
		iw dev "$ifname" set 4addr on 2>/dev/null || iw "$ifname" set 4addr on 2>/dev/null || true
		[ -e /proc/sys/net/ecm/src_interface_check ] && echo 0 > /proc/sys/net/ecm/src_interface_check
		logger -t mac80211 "Configured Qualcomm ExtAP hardware L2 bridge on $ifname -> $bridge"
	fi
	brctl addif "$bridge" "$ifname" 2>/dev/null || ip link set "$ifname" master "$bridge" 2>/dev/null || true
	ip link set "$ifname" up 2>/dev/null || true

	if [ "${extap:-0}" -eq 1 ]; then
		[ -x /usr/sbin/cfg80211tool ] && /usr/sbin/cfg80211tool "$ifname" extap 1 2>/dev/null || true
	fi
}

restart_supplicant_instance() {
	local ifname="$1"
	local bridge="$2"
	local extap="${3:-0}"
	local conf="/var/run/wpa_supplicant-${ifname}.conf"
	local active="/var/run/wpa_supplicant-${ifname}.conf.active"
	local pid_file="/var/run/wpa_supplicant-${ifname}.pid"
	local sock_file="/var/run/wpa_supplicant/${ifname}"

	[ -f "$conf" ] || return 0

	local pids=$(pgrep -f "wpa_supplicant.*${conf}")
	if [ -n "$pids" ]; then
		if [ -S "$sock_file" ] && [ -f "$active" ] && cmp -s "$conf" "$active"; then
			ensure_supplicant_bridge "$ifname" "$bridge" "$extap"
			return 0
		fi

		if [ ! -S "$sock_file" ]; then
			if wait_hostapd_sock "$sock_file" 5 && [ -f "$active" ] && cmp -s "$conf" "$active"; then
				ensure_supplicant_bridge "$ifname" "$bridge" "$extap"
				return 0
			fi
		fi

		if [ -S "$sock_file" ] && [ -f "$active" ]; then
			if [ "$(wpa_cli -i "$ifname" reconfigure 2>/dev/null)" = "OK" ]; then
				cp -f "$conf" "$active" 2>/dev/null || true
				logger -t mac80211 "Successfully reconfigured wpa_supplicant for $ifname"
				ensure_supplicant_bridge "$ifname" "$bridge" "$extap"
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

	# Attach interface to bridge with Qualcomm ExtAP and 4addr
	ensure_supplicant_bridge "$ifname" "$bridge" "$extap"

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
	local ifname mode network disabled ssid encryption key wds isolate hidden bssid wps_pushbutton macaddr extap
	local network_bridge

	json_get_var network_bridge bridge
	json_select config
	json_get_vars ifname mode network disabled ssid encryption key wds isolate hidden bssid wps_pushbutton macaddr extap
	json_select ..

	[ -z "$mode" ] && mode="ap"

	# If STA is attached to LAN or has WDS/ExtAP enabled, automatically activate Qualcomm ExtAP hardware L2 bridge
	if [ "$mode" = "sta" ] || [ "$mode" = "sta-wds" ] || [ "$mode" = "sta-extap" ]; then
		if [ "$network" = "lan" ] || [ "${wds:-0}" -eq 1 ] || [ "${extap:-0}" -eq 1 ]; then
			extap=1
			mode="sta"
			[ -z "$network" ] && network="lan"
		fi
	fi

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
			pkill -9 -f "wpa_supplicant.*${ifname}" 2>/dev/null || true
			pkill -9 -f "hostapd.*${ifname}" 2>/dev/null || true
			rm -f "/var/run/hostapd-${ifname}.pid" "/var/run/hostapd-${ifname}.conf.active" "/var/run/hostapd/${ifname}"
			rm -f "/var/run/wpa_supplicant-${ifname}.pid" "/var/run/wpa_supplicant-${ifname}.conf.active" "/var/run/wpa_supplicant/${ifname}"
			if [ "$ifname" != "ath0" ] && [ "$ifname" != "ath1" ]; then
				ip link set "$ifname" nomaster 2>/dev/null || true
				ip link set "$ifname" down 2>/dev/null || true
				iw dev "$ifname" del 2>/dev/null || true
				wlanconfig "$ifname" destroy 2>/dev/null || true
			fi
		fi
		return 0
	fi

	# Ensure kernel VAP exists
	ensure_vap_netdev "$__netifd_device" "$ifname" "$mode" "$macaddr"

	if [ "$mode" = "sta" ] || [ "$mode" = "sta-wds" ]; then
		local br=""
		if [ "${extap:-0}" -eq 1 ] || [ "$mode" = "sta-wds" ] || [ "${wds:-0}" -eq 1 ] || [ "$network" = "lan" ]; then
			br="$network_bridge"
			if [ -z "$br" ]; then
				if [ "$network" = "lan" ] || [ -z "$network" ]; then
					br="br-lan"
				elif [ -d "/sys/class/net/br-${network}" ]; then
					br="br-${network}"
				elif [ -d "/sys/class/net/${network}" ]; then
					br="${network}"
				fi
			fi
		fi
		restart_supplicant_instance "$ifname" "$br" "$extap"
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
			pkill -9 -f "hostapd.*${ifname}" 2>/dev/null || true
			rm -f "/var/run/hostapd-${ifname}.pid" "/var/run/hostapd-${ifname}.conf.active" "/var/run/hostapd/${ifname}"
			if [ "$ifname" != "ath0" ] && [ "$ifname" != "ath1" ]; then
				if [ -d "/sys/class/net/${ifname}" ]; then
					ip link set "$ifname" nomaster 2>/dev/null || true
					ip link set "$ifname" down 2>/dev/null || true
					iw dev "$ifname" del 2>/dev/null || true
					wlanconfig "$ifname" destroy 2>/dev/null || true
				fi
			fi
		fi
		if [ ! -f "/var/run/wpa_supplicant-${ifname}.conf" ]; then
			local spid=$(cat "/var/run/wpa_supplicant-${ifname}.pid" 2>/dev/null)
			[ -n "$spid" ] && kill -9 $spid 2>/dev/null || true
			pkill -9 -f "wpa_supplicant.*${ifname}" 2>/dev/null || true
			rm -f "/var/run/wpa_supplicant-${ifname}.pid" "/var/run/wpa_supplicant-${ifname}.conf.active" "/var/run/wpa_supplicant/${ifname}"
			if [ "$ifname" != "ath0" ] && [ "$ifname" != "ath1" ]; then
				if [ -d "/sys/class/net/${ifname}" ]; then
					ip link set "$ifname" nomaster 2>/dev/null || true
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
	local sta_nets=$(uci -q show wireless | grep -E "\.mode='sta'" | while read -r line; do
		local sec=$(echo "$line" | cut -d. -f2)
		local dis=$(uci -q get "wireless.${sec}.disabled")
		if [ "${dis:-0}" -eq 0 ]; then
			uci -q get "wireless.${sec}.network"
		fi
	done | sort -u)

	for snet in $sta_nets; do
		if [ -n "$snet" ] && [ "$snet" != "lan" ] && uci -q get "network.${snet}" >/dev/null; then
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

	# Asynchronously synchronize 802.11k neighbor reports between bands
	(
		sleep 2
		if [ -S /var/run/hostapd/ath0 ] && [ -S /var/run/hostapd/ath1 ]; then
			local nr0=$(hostapd_cli -i ath0 show_neighbor 2>/dev/null | grep -E '^[0-9a-fA-F]{2}:' | head -n 1)
			local nr1=$(hostapd_cli -i ath1 show_neighbor 2>/dev/null | grep -E '^[0-9a-fA-F]{2}:' | head -n 1)
			if [ -n "$nr0" ] && [ -n "$nr1" ]; then
				local b0=$(echo "$nr0" | awk '{print $1}')
				local s0=$(echo "$nr0" | awk '{print $2}')
				local r0=$(echo "$nr0" | awk '{print $3}')
				local b1=$(echo "$nr1" | awk '{print $1}')
				local s1=$(echo "$nr1" | awk '{print $2}')
				local r1=$(echo "$nr1" | awk '{print $3}')
				hostapd_cli -i ath0 set_neighbor "$b1" "$s1" "$r1" >/dev/null 2>&1 || true
				hostapd_cli -i ath1 set_neighbor "$b0" "$s0" "$r0" >/dev/null 2>&1 || true
			fi
		fi
	) </dev/null >/dev/null 2>&1 &
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
