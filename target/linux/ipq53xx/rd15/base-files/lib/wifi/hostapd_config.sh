#!/bin/sh
#
# Qualcomm Wi-Fi Hostapd Configuration Generator for OpenWrt 24
# Generates /var/run/hostapd-athX.conf from UCI /etc/config/wireless
#

. /lib/functions.sh

CONF_DIR="${CONF_DIR:-/var/run}"
mkdir -p "${CONF_DIR}/hostapd"

get_ht40_capab() {
	local band="$1"
	local ch="$2"

	if [ "$band" = "5g" ]; then
		case "$ch" in
			36|44|52|60|100|108|116|124|132|140|149|157)
				echo "[HT40+]"
				;;
			40|48|56|64|104|112|120|128|136|144|153|161)
				echo "[HT40-]"
				;;
			165)
				echo ""
				;;
			*)
				echo "[HT40+]"
				;;
		esac
	else
		if [ "$ch" -le 7 ]; then
			echo "[HT40+]"
		else
			echo "[HT40-]"
		fi
	fi
}

get_80mhz_center() {
	local ch="$1"
	case "$ch" in
		36|40|44|48) echo "42" ;;
		52|56|60|64) echo "58" ;;
		100|104|108|112) echo "106" ;;
		116|120|124|128) echo "122" ;;
		132|136|140|144) echo "138" ;;
		149|153|157|161) echo "155" ;;
		*) echo "42" ;;
	esac
}

get_160mhz_center() {
	local ch="$1"
	case "$ch" in
		36|40|44|48|52|56|60|64) echo "50" ;;
		100|104|108|112|116|120|124|128) echo "114" ;;
		*) echo "50" ;;
	esac
}

generate_hostapd_conf() {
	local iface="$1"
	local dev="$2"

	local ssid channel band htmode hwmode country disabled
	local encryption key isolate hidden bridge mode network wds pmf

	# Only generate hostapd configs for AP modes
	config_get mode "$iface" mode "ap"
	[ "$mode" != "ap" ] && [ "$mode" != "ap-wds" ] && return 0

	# Read device properties
	config_get channel "$dev" channel ""
	config_get band "$dev" band ""
	config_get htmode "$dev" htmode ""
	config_get hwmode "$dev" hwmode ""
	config_get country "$dev" country "CN"
	config_get_bool disabled "$dev" disabled 0

	# Read interface properties
	config_get ssid "$iface" ssid "OpenWrt"
	config_get encryption "$iface" encryption "psk2"
	config_get key "$iface" key ""
	[ -z "$key" ] && config_get key "$iface" password ""
	[ -z "$key" ] && config_get key "$iface" sae_password ""
	[ -z "$key" ] && key="12345678"
	config_get_bool isolate "$iface" isolate 0
	config_get_bool hidden "$iface" hidden 0
	config_get ifname "$iface" ifname ""
	[ -z "$ifname" ] && {
		if [ "$dev" = "radio0" ]; then
			ifname="ath0"
		else
			ifname="ath1"
		fi
	}
	config_get_bool if_disabled "$iface" disabled 0
	config_get network "$iface" network "lan"
	config_get bridge "$iface" bridge ""
	config_get_bool wds "$iface" wds 0
	[ "$mode" = "ap-wds" ] && wds=1

	local conf_file="${CONF_DIR}/hostapd-${ifname}.conf"
	if [ "$disabled" -eq 1 ] || [ "$if_disabled" -eq 1 ]; then
		rm -f "$conf_file"
		return 0
	fi
	local br_dev="br-lan"
	if [ -n "$bridge" ]; then
		br_dev="$bridge"
	elif [ "$network" != "lan" ] && [ -n "$network" ]; then
		br_dev="br-$network"
	fi

	# Hardware map radio0 to 2.4G and radio1 to 5G
	if [ "$dev" = "radio0" ] || [ "$ifname" = "ath0" ]; then
		band="2g"
	elif [ "$dev" = "radio1" ] || [ "$ifname" = "ath1" ]; then
		band="5g"
	elif [ "$band" != "5g" ] && [ "$band" != "2g" ]; then
		if [ "$hwmode" = "11a" ] || [ "$hwmode" = "11axa" ] || [ "$hwmode" = "11ac" ]; then
			band="5g"
		else
			band="2g"
		fi
	fi

	# Auto-resolve channel
	if [ -z "$channel" ] || [ "$channel" = "auto" ] || [ "$channel" = "0" ]; then
		if [ "$band" = "5g" ]; then
			channel=36
		else
			channel=1
		fi
	fi

	# Auto-resolve htmode
	if [ -z "$htmode" ]; then
		if [ "$band" = "5g" ]; then
			htmode="HE160"
		else
			htmode="HE40"
		fi
	fi

	{
		echo "driver=nl80211"
		echo "interface=${ifname}"
		echo "bridge=${br_dev}"
		echo "ssid=${ssid}"
		echo "ctrl_interface=/var/run/hostapd"

		# Country / Regulatory
		if [ -n "$country" ]; then
			echo "country_code=${country}"
			echo "ieee80211d=0"
		fi

		# Band and mode configuration
		if [ "$band" = "5g" ]; then
			echo "hw_mode=a"
			echo "channel=${channel}"
			echo "ieee80211n=1"
			echo "ieee80211ac=1"
			echo "ieee80211ax=1"

			local ht_cap=$(get_ht40_capab "$band" "$channel")

			case "$htmode" in
				*160*|*EHT160*|*HE160*)
					local seg0=$(get_160mhz_center "$channel")
					[ -n "$ht_cap" ] && echo "ht_capab=${ht_cap}"
					echo "he_oper_chwidth=2"
					echo "he_oper_centr_freq_seg0_idx=${seg0}"
					echo "vht_oper_chwidth=2"
					echo "vht_oper_centr_freq_seg0_idx=${seg0}"
					;;
				*80*|*VHT80*|*HE80*)
					local seg0=$(get_80mhz_center "$channel")
					[ -n "$ht_cap" ] && echo "ht_capab=${ht_cap}"
					echo "he_oper_chwidth=1"
					echo "he_oper_centr_freq_seg0_idx=${seg0}"
					echo "vht_oper_chwidth=1"
					echo "vht_oper_centr_freq_seg0_idx=${seg0}"
					;;
				*40*|*VHT40*|*HE40*)
					[ -n "$ht_cap" ] && echo "ht_capab=${ht_cap}"
					echo "he_oper_chwidth=0"
					echo "vht_oper_chwidth=0"
					;;
				*)
					echo "he_oper_chwidth=0"
					echo "vht_oper_chwidth=0"
					;;
			esac

			case "$htmode" in
				*EHT160*|*eht160*)
					local seg0=$(get_160mhz_center "$channel")
					echo "ieee80211be=1"
					echo "eht_oper_chwidth=2"
					echo "eht_oper_centr_freq_seg0_idx=${seg0}"
					;;
				*EHT80*|*eht80*)
					local seg0=$(get_80mhz_center "$channel")
					echo "ieee80211be=1"
					echo "eht_oper_chwidth=1"
					echo "eht_oper_centr_freq_seg0_idx=${seg0}"
					;;
				*EHT*|*eht*)
					echo "ieee80211be=1"
					echo "eht_oper_chwidth=0"
					;;
			esac
		else
			echo "hw_mode=g"
			echo "channel=${channel}"
			echo "ieee80211n=1"
			echo "ieee80211ax=1"

			case "$htmode" in
				*EHT*|*eht*)
					echo "ieee80211be=1"
					;;
			esac

			case "$htmode" in
				*40*|*EHT40*|*HE40*|*HT40*)
					local ht_cap=$(get_ht40_capab "$band" "$channel")
					[ -n "$ht_cap" ] && echo "ht_capab=${ht_cap}"
					;;
			esac
		fi

		# Security & Encryption
		case "$encryption" in
			none|open|"")
				echo "wpa=0"
				;;
			sae|wpa3)
				echo "wpa=2"
				echo "wpa_key_mgmt=SAE"
				echo "wpa_pairwise=CCMP"
				echo "rsn_pairwise=CCMP"
				echo "ieee80211w=2"
				echo "sae_password=${key}"
				;;
			sae-mixed|*sae*|*wpa3*)
				echo "wpa=2"
				echo "wpa_key_mgmt=WPA-PSK SAE"
				echo "wpa_pairwise=CCMP"
				echo "rsn_pairwise=CCMP"
				echo "ieee80211w=1"
				echo "wpa_passphrase=${key}"
				echo "sae_password=${key}"
				;;
			psk|wpa)
				echo "wpa=1"
				echo "wpa_key_mgmt=WPA-PSK"
				echo "wpa_pairwise=TKIP CCMP"
				echo "wpa_passphrase=${key}"
				;;
			owe)
				echo "wpa=2"
				echo "wpa_key_mgmt=OWE"
				echo "wpa_pairwise=CCMP"
				echo "rsn_pairwise=CCMP"
				echo "ieee80211w=2"
				;;
			*)
				echo "wpa=2"
				echo "wpa_key_mgmt=WPA-PSK"
				echo "wpa_pairwise=CCMP"
				echo "rsn_pairwise=CCMP"
				echo "ieee80211w=1"
				echo "wpa_passphrase=${key}"
				;;
		esac

		# Optional PMF override from LuCI
		config_get pmf "$iface" ieee80211w ""
		[ -n "$pmf" ] && echo "ieee80211w=${pmf}"

		# WDS 4-address station support
		[ "$wds" -eq 1 ] && echo "wds_sta=1"

		# Additional options
		[ "$isolate" -eq 1 ] && echo "ap_isolate=1"
		[ "$hidden" -eq 1 ] && echo "ignore_broadcast_ssid=1"

		# WPS (Wi-Fi Protected Setup - Push Button Configuration)
		local default_wps=1
		[ "$network" = "guest" -o "$isolate" -eq 1 ] && default_wps=0
		case "$encryption" in
			none|open|owe|sae|wpa3) default_wps=0 ;;
		esac
		local wps_pbc
		config_get_bool wps_pbc "$iface" wps_pushbutton "$default_wps"

		if [ "$wps_pbc" -eq 1 ]; then
			echo "wps_state=2"
			echo "eap_server=1"
			echo "wps_independent=1"
			echo "config_methods=push_button virtual_push_button physical_push_button"
			echo "device_name=Xiaomi Router BE3600"
			echo "manufacturer=Xiaomi"
			echo "model_name=RD15"
			echo "model_number=BE3600"
			echo "device_type=6-0050F204-1"
			echo "os_version=01020300"
		fi

	} > "$conf_file"

	# Create symlinks for iwinfo nl80211 phy lookup
	local phy=$(cat "/sys/class/net/${ifname}/phy80211/name" 2>/dev/null)
	[ -n "$phy" ] && ln -sf "hostapd-${ifname}.conf" "${CONF_DIR}/hostapd-${phy}.conf" 2>/dev/null || true
	if [ "$ifname" = "ath0" ]; then
		ln -sf "hostapd-ath0.conf" "${CONF_DIR}/hostapd-phy1.conf" 2>/dev/null || true
	elif [ "$ifname" = "ath1" ]; then
		ln -sf "hostapd-ath1.conf" "${CONF_DIR}/hostapd-phy2.conf" 2>/dev/null || true
	fi

	echo "Generated hostapd configuration: $conf_file"
}

generate_all() {
	rm -f "${CONF_DIR}"/hostapd-ath*.conf
	config_load wireless
	config_foreach_iface() {
		local iface="$1"
		local dev
		config_get dev "$iface" device
		generate_hostapd_conf "$iface" "$dev"
	}
	config_foreach config_foreach_iface wifi-iface
}

if [ "$1" = "all" ] || [ -z "$1" ]; then
	generate_all
else
	config_load wireless
	generate_hostapd_conf "$1" "$2"
fi
