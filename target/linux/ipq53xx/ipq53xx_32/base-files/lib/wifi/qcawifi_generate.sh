#!/bin/sh
# Xiaomi Router BE3600 (RD15/RD16) Wi-Fi Configuration Generator

generate_wireless_config() {
	local target_file="${1:-/etc/config/wireless}"
	local forced_model="$2"

	local model="$forced_model"
	if [ -z "$model" ]; then
		[ -f /proc/xiaoqiang/model ] && model=$(cat /proc/xiaoqiang/model 2>/dev/null)
		[ -z "$model" ] && command -v bdata >/dev/null 2>&1 && model=$(bdata get model 2>/dev/null)
		[ -z "$model" ] && command -v nvram >/dev/null 2>&1 && model=$(nvram get model 2>/dev/null)
	fi

	case "$model" in
	RD16|rd16)
		model="RD16"
		;;
	*)
		local board=$(cat /tmp/sysinfo/board_name 2>/dev/null)
		case "$board" in
		*rd16*)
			model="RD16"
			;;
		*)
			model="RD15"
			;;
		esac
		;;
	esac

	local ssid_2g="OpenWrt_${model}_2.4G"
	local ssid_5g="OpenWrt_${model}_5G"
	local guest_2g="OpenWrt_${model}_Guest_2.4G"
	local guest_5g="OpenWrt_${model}_Guest_5G"

	_output() {
		cat << EOF

config wifi-device 'radio0'
	option type 'mac80211'
	option phy 'phy1'
	option channel '1'
	option band '2g'
	option htmode 'EHT40'
	option hwmode '11be'
	option country 'CN'
	option disabled '0'

config wifi-iface 'default_radio0'
	option device 'radio0'
	option network 'lan'
	option mode 'ap'
	option ssid '$ssid_2g'
	option encryption 'sae-mixed'
	option key '12345678'
	option ifname 'ath0'

config wifi-device 'radio1'
	option type 'mac80211'
	option phy 'phy2'
	option channel '36'
	option band '5g'
	option htmode 'EHT160'
	option hwmode '11be'
	option country 'CN'
	option disabled '0'

config wifi-iface 'default_radio1'
	option device 'radio1'
	option network 'lan'
	option mode 'ap'
	option ssid '$ssid_5g'
	option encryption 'sae-mixed'
	option key '12345678'
	option ifname 'ath1'

config wifi-iface 'guest_radio0'
	option device 'radio0'
	option network 'guest'
	option mode 'ap'
	option ssid '$guest_2g'
	option encryption 'psk2'
	option key '12345678'
	option ifname 'ath02'
	option isolate '1'
	option disabled '1'

config wifi-iface 'guest_radio1'
	option device 'radio1'
	option network 'guest'
	option mode 'ap'
	option ssid '$guest_5g'
	option encryption 'psk2'
	option key '12345678'
	option ifname 'ath12'
	option isolate '1'
	option disabled '1'
EOF
	}

	if [ "$target_file" = "-" ]; then
		_output
	else
		mkdir -p "$(dirname "$target_file")"
		_output > "$target_file"
	fi
}

case "$0" in
	*qcawifi_generate.sh*)
		generate_wireless_config "$@"
		;;
esac
