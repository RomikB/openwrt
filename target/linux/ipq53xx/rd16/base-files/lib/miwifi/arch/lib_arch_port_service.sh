#!/bin/sh

. /lib/miwifi/arch/lib_arch_accel.sh


arch_ps_setup_wan() {
    local service="$1"
    local wan_port="$2"
    local wan_ifname wan6_pass wan6_ifname pass_ifname
    local list_lan_ifname

    # reconfig network wan and lan
    wan_mac=$(uci -q get network.wan.macaddr)
    wan_ifname=$(port_map iface port "$wan_port")
    wan6_ifname="$wan_ifname"
    wan6_pass=$(uci -q get network."${service/n/n6}".passthrough)
    [ "$wan6_pass" = "1" ] && {
        wan6_ifname="br-lan"
        pass_ifname="$wan_ifname"
    }
    list_lan_ifname=$(uci -q get network.lan.ifname)
    list_lan_ifname=$(echo "$list_lan_ifname" | sed "s/$wan_ifname//g" | xargs)

    uci -q batch <<-EOF
        set network."$service".ifname="$wan_ifname"
        set network."${service/n/n6}".ifname="$wan6_ifname"
        set network."${service/n/n6}".pass_ifname="$pass_ifname"
        set network."macv_${service/n/n6}".ifname="$wan_ifname"
        set network.lan.ifname="$list_lan_ifname"
        set network."${wan_ifname}_dev".macaddr="$wan_mac"
        commit network
	EOF

    # reload network
    ubus call network reload
    ubus call network.interface."$service" up
    [ "$wan6_pass" = "1" ] && ubus call network.interface."${service/n/n6}" up
}

arch_ps_reset_lan() {
    local service="$1"
    local wan_port="$2"
    local wan_ifname list_lan_ifname lan_mac

    [ -z "$wan_port" ] && return

    wan_ifname=$(port_map config get "$wan_port" ifname)
    list_lan_ifname=$(uci -q get network.lan.ifname)
    append list_lan_ifname "$wan_ifname"

    pconfig del "${wan_ifname}_6" > /dev/null 2>&1

    # reconfig network
    uci -q batch <<-EOF
        delete network."$service".ifname
        delete network."${service/n/n6}".ifname
        delete network."${service/n/n6}".pass_ifname
        delete network."macv_${service/n/n6}".ifname
	delete network".${wan_ifname}_dev".macaddr
        set network.lan.ifname="$list_lan_ifname"
        commit network
	EOF

    # reload network
    ip addr flush dev "$wan_ifname"
    lan_mac=$(uci -q get network.lan.macaddr)
    [ -z "$lan_mac" ] && lan_mac=$(getmac lan)
    [ -n "$lan_mac" ] && ip link set dev "$wan_ifname" address "$lan_mac"
    ubus call network.interface."$service" down
    ubus call network reload
    util_portmap_update "$wan_port"
    [ "$(uci -q get miqos.settings.enabled)" = "1" ] && {
        arch_accel_event_qos_update
    }

    return
}