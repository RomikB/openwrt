#!/bin/sh

# $1 action : start | stop | restart | flush
arch_accel_control() { return; }

arch_accel_event_ipv6_nat_start()         { return; }
arch_accel_event_ipv6_nat_stop()          { return; }
arch_accel_event_ipv6_passthrough_start() { return; }
arch_accel_event_ipv6_passthrough_stop()  { return; }
arch_accel_event_ipv6_passthrough_load()  { return; }
arch_accel_event_vpn_pre_start()          { return; }
arch_accel_event_vpn_post_stop()          { return; }
arch_accel_event_vpn_start()              { return; }
arch_accel_event_vpn_stop()               { return; }
arch_accel_event_qos_start()              { return; }
arch_accel_event_qos_stop()               { return; }
arch_accel_event_qos_update()             { return; }
arch_accel_event_qos_stop()               { return; }
arch_accel_event_mipctl_start()           { return; }
arch_accel_event_mipctl_stop()            { return; }
arch_accel_event_lanap_open()             { return; }
arch_accel_event_lanap_close()            { return; }
arch_accel_event_wifiap_open()            { return; }
arch_accel_event_wifiap_close()           { return; }
arch_accel_event_whc_re_setup()           { return; }
arch_accel_event_whc_re_open()            { return; }
arch_accel_event_whc_re_close()           { return; }

. /lib/miwifi/arch/lib_arch_accel.sh
. /lib/miwifi/miwifi_functions.sh
. /lib/functions.sh

# register modules
MODULES=""

# Add
append MODULES "mipctl"
append MODULES "qos"
append MODULES "vpn"
append MODULES "ipv6_nat"
append MODULES "ipv6_passthrough"
append MODULES "conntrack"
append MODULES "lanap"
append MODULES "wifiap"
append MODULES "whc_re"

# $1 action : "start" | "stop" | "restart" | "flush")
_accel_control() {
	local action="$1"

	util_log "Accel ACTION $action"
	arch_accel_control "$action"
}

# $1 module : vpn|ipv6|qos ...
# $2 event : start|stop|open|close ...
_accel_event() {
	local module="$1"
	local event="$2"

	list_contains MODULES "$module" || return
	if type "arch_accel_event_${module}_${event}" | grep -qsw "function"; then
		shift 2
		util_log "Accel EVENT $module $event $*"
		arch_accel_event_"${module}"_"${event}" "$@"
	fi

}

################################## export ##################################

network_accel_hook() {

	case "$1" in
	"start" | "stop" | "restart" | "flush")
		_accel_control "$1"
		;;

	*)
		[ $# -ge 2 ] || return
		_accel_event "$@"
		;;
	esac
}
