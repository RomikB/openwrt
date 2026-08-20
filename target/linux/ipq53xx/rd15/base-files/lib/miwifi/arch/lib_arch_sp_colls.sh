#!/bin/ash

mesh_bh_rssi() {
	local bh_type=
	local ifname_bh=
	local band=

	bh_type=$(topomon_action.sh current_status bh_type)
	if [ "${bh_type}" = "wireless" ]; then
		band=$(mesh_cmd backhaul get real_band)
		ifname_bh=$(uci -q get "misc.backhauls.backhaul_${band}_sta_iface")

		iwinfo "${ifname_bh}" info 2>/dev/null |
			grep "Signal" |
			sed 's|dBm||g' |
			awk '{print $2}'
	fi
}
