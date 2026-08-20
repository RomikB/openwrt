#!/bin/sh

arch_network_router_mode_init() { return; }
arch_network_re_mode_init()     { return; }
arch_network_ap_mode_init()     { return; }
arch_network_extra_init()       { return; }

. /lib/miwifi/arch/lib_arch_network.sh
. /lib/miwifi/miwifi_functions.sh

_set_ipaccount() {
	local enable="$1"
	local ipaccount_disabled=$(uci -q get traffic.@ipaccount[0].disabled)
	local file_enable_ipaccount="/proc/sys/net/ipv4/ipaccount/enable_ipaccount"

	[ -w "$file_enable_ipaccount" ] || return

	if [ "0" = "$enable" -o "$ipaccount_disabled" = "1" ]; then
		enable=0
	else
		enable=1
	fi

	util_log "set ipaccount $enable"
	echo $enable > "$file_enable_ipaccount"
}

_mac_init() {
	local mac_in_mtd mac_in_cfg wantype

	config_mac() {
		local interface="$1"

		# only config the "lan", "wan", "wan_2" and so on
		echo "$interface"|grep -qsE '^(lan|wan(_[0-9]+)?)$' || return

		wantype=$(uci -q get network."$interface".wantype)
		[ "$wantype" = "cpe" ] && return

		mac_in_mtd=$(getmac "${interface//_/}") # convert "wan_2" to "wan2"
		mac_in_cfg=$(uci -q get network."$interface".macaddr)

		[ -z "$mac_in_cfg" ] && [ -n "$mac_in_mtd" ] && {
			uci set network."$interface".macaddr="$mac_in_mtd"
			uci commit network
		}
	}

	config_load network
	config_foreach config_mac interface
	return
}

_extra_init() {
	_mac_init
	arch_network_extra_init
}

_re_mode_init() {
	_set_ipaccount 0
	arch_network_re_mode_init
}

_ap_mode_init() {
	_set_ipaccount 0
	arch_network_ap_mode_init
}

_router_mode_init() {
	_set_ipaccount 1
	arch_network_router_mode_init
	return
}

_cpe_bridgemode_init() {
	_set_ipaccount 0

	arch_network_cpe_bridgemode_init
}

################################## export ##################################

network_extra_init() {
	local mode=""

	mode=$(uci -q get xiaoqiang.common.NETMODE)
	case "$mode" in
	"whc_re")
		util_log "=== re mode init ==="
		_re_mode_init
		;;

	"" | "whc_cap")
		util_log "=== router mode init ==="
		_router_mode_init
		;;

	"wifiapmode" | "lanapmode")
		util_log "=== ap mode init ==="
		_ap_mode_init
		;;

	"cpe_bridgemode")
		_cpe_bridgemode_init
		;;

	*) ;;

	esac

	_extra_init
	return
}
