#!/bin/sh
#
# Qualcomm Wi-Fi Hostapd Configuration Generator for OpenWrt 24
# Generates /var/run/hostapd-athX.conf from UCI /etc/config/wireless
#

. /lib/functions.sh
. /lib/wifi/qcawifi_modes.sh

CONF_DIR="${CONF_DIR:-/var/run}"
mkdir -p "${CONF_DIR}/hostapd"

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
		case "$hwmode" in
			*a*|*11be*|*11bea*) band="5g" ;;
			*)                  band="2g" ;;
		esac
	fi

	# Auto-resolve channel
	if [ -z "$channel" ] || [ "$channel" = "auto" ] || [ "$channel" = "0" ]; then
		if [ "$band" = "5g" ]; then
			channel=36
		else
			channel=1
		fi
	fi

	# Evaluate generation and bandwidth modes using shared helper
	local QC_HTMODE QC_IS_BE QC_IS_AX QC_IS_AC QC_IS_N QC_DRIVER_MODE
	qcawifi_eval_modes "$band" "$hwmode" "$htmode" "$dev" "$ifname" "$channel"
	htmode="$QC_HTMODE"
	local is_be=$QC_IS_BE
	local is_ax=$QC_IS_AX
	local is_ac=$QC_IS_AC
	local is_n=$QC_IS_N

	{
		echo "driver=nl80211"
		echo "interface=${ifname}"
		echo "bridge=${br_dev}"
		echo "ssid=${ssid}"
		echo "ctrl_interface=/var/run/hostapd"

		# Note: Do not pass country_code or ieee80211d to hostapd.
		# In QSDK 12.4, hostapd issuing COUNTRY_UPDATE calls wlan_cfg80211_set_country,
		# which wipes the kernel driver's Pre-CAC cleared channels and triggers a 60s CAC penalty.
		# Country is already set once at boot on the radio level via cfg80211tool/driver.

		# Read base hardware capabilities exported by Qualcomm driver via sysfs
		local base_ht_caps=""
		local base_vht_caps=""
		if [ -f "/sys/class/net/${ifname}/cfg80211_htcaps" ]; then
			base_ht_caps=$(cat "/sys/class/net/${ifname}/cfg80211_htcaps" 2>/dev/null)
		fi
		[ -z "$base_ht_caps" ] && base_ht_caps="[LDPC][TX-STBC][RX-STBC-1][MAX-AMSDU-7935][DSSS_CCK-40]"
		if [ -f "/sys/class/net/${ifname}/cfg80211_vhtcaps" ]; then
			base_vht_caps=$(cat "/sys/class/net/${ifname}/cfg80211_vhtcaps" 2>/dev/null)
		fi
		if [ -z "$base_vht_caps" ]; then
			if [ "$band" = "5g" ]; then
				base_vht_caps="[MAX-MPDU-11454][VHT160][RXLDPC][SHORT-GI-80][SHORT-GI-160][TX-STBC-2BY1][RX-STBC1][SU-BEAMFORMER][SOUNDING-DIMENSION-2][SU-BEAMFORMEE][MAX-A-MPDU-LEN-EXP7][MU-BEAMFORMER][RX-ANTENNA-PATTERN][TX-ANTENNA-PATTERN]"
			else
				base_vht_caps="[MAX-MPDU-11454][RXLDPC][TX-STBC-2BY1][RX-STBC1][SU-BEAMFORMER][SOUNDING-DIMENSION-2][SU-BEAMFORMEE][BF-ANTENNA-4][MAX-A-MPDU-LEN-EXP7][MU-BEAMFORMER][RX-ANTENNA-PATTERN][TX-ANTENNA-PATTERN]"
			fi
		fi

		# Band and mode configuration
		if [ "$band" = "5g" ]; then
			echo "hw_mode=a"
			echo "channel=${channel}"
			[ "$is_n" -eq 1 ] && echo "ieee80211n=1"
			[ "$is_ac" -eq 1 ] && echo "ieee80211ac=1"
			[ "$is_ax" -eq 1 ] && echo "ieee80211ax=1"
			[ "$is_be" -eq 1 ] && echo "ieee80211be=1"

			[ -n "$base_vht_caps" ] && [ "$is_ac" -eq 1 ] && echo "vht_capab=${base_vht_caps}"

			case "$htmode" in
				*160*)
					local seg0=$(qcawifi_get_160mhz_center "$channel")
					local ht_cap="${base_ht_caps} $(qcawifi_get_ht40_capab "$band" "$channel")"
					[ -n "$ht_cap" ] && [ "$is_n" -eq 1 ] && echo "ht_capab=${ht_cap}"
					if [ "$is_be" -eq 1 ]; then
						echo "eht_oper_chwidth=2"
						echo "eht_oper_centr_freq_seg0_idx=${seg0}"
						echo "puncture_bitmap= 0xffff"
					elif [ "$is_ax" -eq 1 ]; then
						echo "he_oper_chwidth=2"
						echo "he_oper_centr_freq_seg0_idx=${seg0}"
					elif [ "$is_ac" -eq 1 ]; then
						echo "vht_oper_chwidth=2"
						echo "vht_oper_centr_freq_seg0_idx=${seg0}"
					fi
					;;
				*80*)
					local seg0=$(qcawifi_get_80mhz_center "$channel")
					local ht_cap="${base_ht_caps} $(qcawifi_get_ht40_capab "$band" "$channel")"
					[ -n "$ht_cap" ] && [ "$is_n" -eq 1 ] && echo "ht_capab=${ht_cap}"
					if [ "$is_be" -eq 1 ]; then
						echo "eht_oper_chwidth=1"
						echo "eht_oper_centr_freq_seg0_idx=${seg0}"
						echo "puncture_bitmap= 0xffff"
					elif [ "$is_ax" -eq 1 ]; then
						echo "he_oper_chwidth=1"
						echo "he_oper_centr_freq_seg0_idx=${seg0}"
					elif [ "$is_ac" -eq 1 ]; then
						echo "vht_oper_chwidth=1"
						echo "vht_oper_centr_freq_seg0_idx=${seg0}"
					fi
					;;
				*40*)
					local seg0=$(qcawifi_get_40mhz_center "$band" "$channel")
					local ht_cap="${base_ht_caps} $(qcawifi_get_ht40_capab "$band" "$channel")"
					[ -n "$ht_cap" ] && [ "$is_n" -eq 1 ] && echo "ht_capab=${ht_cap}"
					if [ "$is_be" -eq 1 ]; then
						echo "eht_oper_chwidth=0"
						echo "eht_oper_centr_freq_seg0_idx=${seg0}"
						echo "puncture_bitmap= 0xffff"
					elif [ "$is_ax" -eq 1 ]; then
						echo "he_oper_chwidth=0"
						echo "he_oper_centr_freq_seg0_idx=${seg0}"
					elif [ "$is_ac" -eq 1 ]; then
						echo "vht_oper_chwidth=0"
						echo "vht_oper_centr_freq_seg0_idx=${seg0}"
					fi
					;;
				*)
					local ht_cap="${base_ht_caps} [HT20] [SHORT-GI-20]"
					[ "$is_n" -eq 1 ] && echo "ht_capab=${ht_cap}"
					if [ "$is_be" -eq 1 ]; then
						echo "eht_oper_chwidth=0"
						echo "eht_oper_centr_freq_seg0_idx=${channel}"
						echo "puncture_bitmap= 0xffff"
					elif [ "$is_ax" -eq 1 ]; then
						echo "he_oper_chwidth=0"
						echo "he_oper_centr_freq_seg0_idx=${channel}"
					elif [ "$is_ac" -eq 1 ]; then
						echo "vht_oper_chwidth=0"
						echo "vht_oper_centr_freq_seg0_idx=${channel}"
					fi
					;;
			esac
		else
			echo "hw_mode=g"
			echo "channel=${channel}"
			[ "$is_n" -eq 1 ] && echo "ieee80211n=1"
			[ "$is_ac" -eq 1 ] && echo "ieee80211ac=1"
			[ "$is_ax" -eq 1 ] && echo "ieee80211ax=1"
			[ "$is_be" -eq 1 ] && echo "ieee80211be=1"

			[ -n "$base_vht_caps" ] && [ "$is_ac" -eq 1 ] && echo "vht_capab=${base_vht_caps}"

			case "$htmode" in
				*40*|*EHT40*|*HE40*|*HT40*)
					if [ "$is_n" -eq 1 ]; then
						local ht_cap="${base_ht_caps} $(qcawifi_get_ht40_capab "$band" "$channel")"
						[ -n "$ht_cap" ] && echo "ht_capab=${ht_cap}"
					fi
					;;
				*)
					if [ "$is_n" -eq 1 ]; then
						local ht_cap="${base_ht_caps} [HT20][SHORT-GI-20]"
						[ -n "$ht_cap" ] && echo "ht_capab=${ht_cap}"
					fi
					;;
			esac
		fi

		echo "wmm_enabled=1"
		echo "dtim_period=1"
		echo "noauth_pasn_activated=1"
		echo "owe_ptk_workaround=1"
		# Offload probe response generation to Qualcomm firmware to ensure correct EHT/HE channel width
		echo "send_probe_response=0"

	# 802.11r Fast Transition
	local ieee80211r mobility_domain nasid reassociation_deadline ft_over_ds ft_psk_generate_local r0_key_lifetime r1_key_holder pmk_r1_push
	config_get_bool ieee80211r "$iface" ieee80211r 0
	config_get mobility_domain "$iface" mobility_domain ""
	config_get nasid "$iface" nasid ""
	config_get reassociation_deadline "$iface" reassociation_deadline "1000"
	config_get_bool ft_over_ds "$iface" ft_over_ds 0
	config_get_bool ft_psk_generate_local "$iface" ft_psk_generate_local 1
	config_get r0_key_lifetime "$iface" r0_key_lifetime "10000"
	config_get r1_key_holder "$iface" r1_key_holder ""
	config_get_bool pmk_r1_push "$iface" pmk_r1_push 0

	# 802.11k RRM
	local ieee80211k rrm_neighbor_report rrm_beacon_report
	config_get_bool ieee80211k "$iface" ieee80211k 0
	config_get_bool rrm_neighbor_report "$iface" rrm_neighbor_report "$ieee80211k"
	config_get_bool rrm_beacon_report "$iface" rrm_beacon_report "$ieee80211k"

	# 802.11v WNM/BSS-TM
	local ieee80211v time_advertisement time_zone wnm_sleep_mode wnm_sleep_mode_no_keys bss_transition proxy_arp
	config_get_bool ieee80211v "$iface" ieee80211v 0
	config_get time_advertisement "$iface" time_advertisement "0"
	config_get time_zone "$iface" time_zone ""
	config_get_bool wnm_sleep_mode "$iface" wnm_sleep_mode "$ieee80211v"
	config_get_bool wnm_sleep_mode_no_keys "$iface" wnm_sleep_mode_no_keys "$ieee80211v"
	config_get_bool bss_transition "$iface" bss_transition "$ieee80211v"
	config_get_bool proxy_arp "$iface" proxy_arp 0

	# Security & Encryption
	case "$encryption" in
		none|open|"")
			echo "wpa=0"
			;;
		sae|wpa3)
			echo "wpa=2"
			if [ "$ieee80211r" -eq 1 ]; then
				echo "wpa_key_mgmt=SAE FT-SAE"
			else
				echo "wpa_key_mgmt=SAE"
			fi
			echo "wpa_pairwise=CCMP"
			echo "rsn_pairwise=CCMP"
			echo "ieee80211w=2"
			echo "sae_password=${key}"
			;;
		sae-mixed|*sae*|*wpa3*)
			echo "wpa=2"
			if [ "$ieee80211r" -eq 1 ]; then
				echo "wpa_key_mgmt=WPA-PSK SAE FT-PSK FT-SAE"
			else
				echo "wpa_key_mgmt=WPA-PSK SAE"
			fi
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
			if [ "$ieee80211r" -eq 1 ]; then
				echo "wpa_key_mgmt=WPA-PSK FT-PSK"
			else
				echo "wpa_key_mgmt=WPA-PSK"
			fi
			echo "wpa_pairwise=CCMP"
			echo "rsn_pairwise=CCMP"
			# PMF for WPA2-PSK: default off unless specified in UCI (matches stock behavior)
			config_get pmf "$iface" ieee80211w ""
			[ -n "$pmf" ] && echo "ieee80211w=${pmf}"
			echo "wpa_passphrase=${key}"
			;;
	esac

	# 802.11r Fast Transition
	if [ "$ieee80211r" -eq 1 ]; then
		[ -z "$mobility_domain" ] && mobility_domain=$(echo -n "$ssid" | md5sum | cut -c1-4)
		local mac_clean=$(cat "/sys/class/net/${ifname}/address" 2>/dev/null | tr -d ':')
		[ -z "$nasid" ] && nasid="${mac_clean:-$ifname}"
		[ -z "$r1_key_holder" ] && r1_key_holder="${mac_clean:-00004f577274}"

		echo "mobility_domain=${mobility_domain}"
		echo "nas_identifier=${nasid}"
		echo "ft_psk_generate_local=${ft_psk_generate_local}"
		echo "ft_over_ds=${ft_over_ds}"
		echo "reassociation_deadline=${reassociation_deadline}"
		echo "r0_key_lifetime=${r0_key_lifetime}"
		echo "r1_key_holder=${r1_key_holder}"
		[ "$pmk_r1_push" -eq 1 ] && echo "pmk_r1_push=1"

		local ft_key=$(echo -n "${mobility_domain}/${key}" | md5sum | cut -d' ' -f1)
		echo "r0kh=ff:ff:ff:ff:ff:ff * ${ft_key}"
		echo "r1kh=00:00:00:00:00:00 00:00:00:00:00:00 ${ft_key}"
	fi

	# 802.11k Radio Resource Measurement (RRM)
	if [ "$ieee80211k" -eq 1 -o "$rrm_neighbor_report" -eq 1 ]; then
		echo "rrm_neighbor_report=1"
		[ "$rrm_beacon_report" -eq 1 ] && echo "rrm_beacon_report=1"
	fi

	# 802.11v Wireless Network Management (WNM / BSS-TM)
	if [ "$ieee80211v" -eq 1 -o "$bss_transition" -eq 1 ]; then
		echo "bss_transition=1"
		[ "$wnm_sleep_mode" -eq 1 ] && echo "wnm_sleep_mode=1"
		[ "$wnm_sleep_mode_no_keys" -eq 1 ] && echo "wnm_sleep_mode_no_keys=1"
		if [ "$time_advertisement" = "2" ]; then
			echo "time_advertisement=2"
			[ -n "$time_zone" ] && echo "time_zone=${time_zone}"
		fi
		[ "$proxy_arp" -eq 1 ] && echo "proxy_arp=1"
	fi


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
