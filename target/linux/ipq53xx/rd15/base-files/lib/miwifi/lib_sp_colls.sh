#!/bin/ash

hotplug_check_down() {
	local iface=$1
	local wan_port
	local zone_name

	# Filter original network interface
	if ! echo "$iface" | grep -qsE "^eth"; then
		return
	fi

	wan_port=$(uci -q get network.wan.ifname)
	wan2_port=$(uci -q get network.wan_2.ifname)
	zone_name=lan

	if [ "${iface/_/.}" = "$wan_port" ]; then
		zone_name=wan
	elif [ "${iface/_/.}" = "$wan2_port" ]; then
		zone_name=wan2
	fi

	sp_log_info.sh -k net.phy.down -m "$zone_name:1"
}

net_phy_link() {
	local status=

	status=$(
		phyhelper dump |
			sed 's/speed://i' |
			sed 's/type://i' |
			awk '{printf "%s-%s:%s\n",$7,$5,$4}' |
			tr -d _ |
			sed 's/-eth//i' |
			awk '{print toupper($0)}'
	)

	echo "$status" | grep -E '^WAN'
	echo "$status" | grep -E '^LAN' | cut -c 4- | awk '{printf "LAN%d%s\n", NR, $1}'
}

wlan_ch_usage() {
	local band=
	local device=
	local chan_util=
	local chan_util_2G=
	local chan_util_5G=

	if [ -d /etc/wireless/mediatek ]; then
		chan_util_2G=$(iwpriv wl1 get chanutil 2>/dev/null | awk -F: '{print $2/1000000}')
		chan_util_5G=$(iwpriv wl0 get chanutil 2>/dev/null | awk -F: '{print $2/1000000}')

		echo "2G:${chan_util_2G}"
		echo "5G:${chan_util_5G}"
	else
		for band in 2G 5G 5GH; do
			device=$(uci -q get misc.wireless.if_${band})
			if [ -z "$device" ]; then
				continue
			fi

			chan_util=$(iwpriv "${device}" g_chanutil 2>/dev/null | awk -F: '{print $2/100}')
			echo "${band}:${chan_util}"
		done
	fi
}

mesh_bh_rssi() {
	local bh_type=
	local ifname_bh=

	bh_type=$(topomon_action.sh current_status bh_type)
	if [ "${bh_type}" = "wireless" ]; then
		ifname_bh=$(uci -q get wireless.bh_sta.ifname)

		# Compatible with legacy versions
		if [ -z "$ifname_bh" ]; then
			ifname_bh=$(uci -q get wireless.bh_5G_sta.ifname)
		fi

		iwinfo "${ifname_bh}" info 2>/dev/null |
			grep "Signal" |
			sed 's|dBm||g' |
			awk '{print $2}'
	fi
}

# Add new common functions before this line!
readonly ARCH_LIB="/lib/miwifi/arch/lib_arch_sp_colls.sh"
if [ -f "$ARCH_LIB" ]; then
	. "$ARCH_LIB"
fi
