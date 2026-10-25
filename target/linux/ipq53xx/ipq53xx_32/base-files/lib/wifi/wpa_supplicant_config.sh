#!/bin/sh
#
# Qualcomm Wi-Fi WPA Supplicant Configuration Generator for OpenWrt 24
# Generates /var/run/wpa_supplicant-athX.conf from UCI /etc/config/wireless
#

. /lib/functions.sh

CONF_DIR="${CONF_DIR:-/var/run}"
mkdir -p "${CONF_DIR}/wpa_supplicant"

generate_supplicant_conf() {
	local iface="$1"
	local dev="$2"

	local ssid encryption key bssid disabled if_disabled ifname mode wds
	config_get_bool disabled "$dev" disabled 0
	config_get_bool if_disabled "$iface" disabled 0
	config_get mode "$iface" mode "sta"
	[ "$mode" != "sta" ] && [ "$mode" != "sta-wds" ] && return 0

	config_get ifname "$iface" ifname ""
	[ -z "$ifname" ] && {
		if [ "$dev" = "radio0" ]; then
			ifname="ath01"
		else
			ifname="ath11"
		fi
	}

	local conf_file="${CONF_DIR}/wpa_supplicant-${ifname}.conf"
	if [ "$disabled" -eq 1 ] || [ "$if_disabled" -eq 1 ]; then
		rm -f "$conf_file"
		return 0
	fi

	config_get ssid "$iface" ssid ""
	config_get encryption "$iface" encryption "none"
	config_get key "$iface" key ""
	[ -z "$key" ] && config_get key "$iface" password ""
	[ -z "$key" ] && config_get key "$iface" sae_password ""
	config_get bssid "$iface" bssid ""
	local channel scan_freq
	config_get channel "$dev" channel ""
	[ -z "$channel" ] && config_get channel "$iface" channel ""
	if [ -n "$channel" ] && [ "$channel" != "auto" ] && [ "$channel" -gt 0 ] 2>/dev/null; then
		if [ "$channel" -le 14 ]; then
			scan_freq=$(( 2407 + channel * 5 ))
			[ "$channel" -eq 14 ] && scan_freq=2484
		elif [ "$channel" -ge 36 ] && [ "$channel" -le 177 ]; then
			scan_freq=$(( 5000 + channel * 5 ))
		fi
	fi

	local ctrl_dir="/var/run/wpa_supplicant"

	{
		echo "ctrl_interface=${ctrl_dir}"
		echo "update_config=1"
		echo ""
		echo "network={"
		echo "	scan_ssid=1"
		[ -n "$ssid" ] && echo "	ssid=\"${ssid}\""
		[ -n "$bssid" ] && echo "	bssid=${bssid}"
		[ -n "$scan_freq" ] && echo "	scan_freq=${scan_freq}"

		case "$encryption" in
			none|open|"")
				echo "	key_mgmt=NONE"
				;;
			sae|wpa3)
				echo "	key_mgmt=SAE"
				echo "	ieee80211w=2"
				echo "	sae_password=\"${key}\""
				;;
			sae-mixed|*sae*|*wpa3*)
				echo "	key_mgmt=WPA-PSK SAE"
				echo "	proto=RSN"
				echo "	pairwise=CCMP"
				echo "	ieee80211w=1"
				if [ ${#key} -eq 64 ]; then
					echo "	psk=${key}"
				else
					echo "	psk=\"${key}\""
				fi
				echo "	sae_password=\"${key}\""
				;;
			psk|wpa)
				echo "	key_mgmt=WPA-PSK"
				echo "	proto=WPA"
				echo "	pairwise=TKIP CCMP"
				if [ ${#key} -eq 64 ]; then
					echo "	psk=${key}"
				else
					echo "	psk=\"${key}\""
				fi
				;;
			*)
				# default: WPA2-PSK
				echo "	key_mgmt=WPA-PSK"
				echo "	proto=RSN"
				echo "	pairwise=CCMP"
				if [ ${#key} -eq 64 ]; then
					echo "	psk=${key}"
				else
					echo "	psk=\"${key}\""
				fi
				;;
		esac
		echo "}"
	} > "$conf_file"

	echo "Generated wpa_supplicant configuration: $conf_file"
}

generate_all_supplicant() {
	rm -f "${CONF_DIR}"/wpa_supplicant-ath*.conf
	config_load wireless
	config_foreach_iface() {
		local iface="$1"
		local dev
		config_get dev "$iface" device
		generate_supplicant_conf "$iface" "$dev"
	}
	config_foreach config_foreach_iface wifi-iface
}

if [ "$1" = "all" ] || [ -z "$1" ]; then
	generate_all_supplicant
else
	config_load wireless
	generate_supplicant_conf "$1" "$2"
fi
