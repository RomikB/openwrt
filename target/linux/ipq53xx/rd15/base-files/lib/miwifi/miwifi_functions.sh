#!/bin/sh

DEBUG_ENV=1

util_log() {
    [ -n "$DEBUG_ENV" ] && echo "[$0 miwifi-libs] $*" > /dev/console
}

util_set_mac() {
    #$1: ifname
    #$2: "lan" or "wan"
    local ifname="$1"
    local mac current_mac

    mac=$(getmac "$2")
    [ -z "$ifname" ] || [ -z "$mac" ] && return 1

    current_mac=$(cat /sys/class/net/"$ifname"/address)
    [ "$current_mac" = "$mac" ] && return 1

    ifconfig "$ifname" down
    ifconfig "$ifname" hw ether "$mac"
    ifconfig "$ifname" up
    return 0
}

util_set_lanitf_mac() {
    local lan_ifnames

    lan_ifnames="$(uci -q get network.lan.ifname)"
    for ifname in $lan_ifnames; do
        util_log "set $ifname mac as lan"
        util_set_mac "$ifname" "lan"
    done
}

util_config_clean() {
    config_load network

    # remove interface
    remove_if() {
        local section_name="$1"
        local type=""

        type=$(uci -q get network."$section_name".type)
        if [ -z "$type" ]; then
            # common interface
            [ "${section_name:0:3}" = "eth" ] || [ "$section_name" = "bond0" ] && {
                uci -q delete network."$section_name"
            }
        elif [ "$type" = "bridge" ]; then
            # bridge interface
            [ "$section_name" = "internet" ] || [ "$section_name" = "iptv" ] || [ "$section_name" = "voip" ] && {
                uci -q delete network."$section_name"
            }
        fi
        return
    }
    config_foreach remove_if interface

    # remove switch_vlan
    remove_switch_vlan() {
        local section_name="$1"
        uci -q delete network."$section_name"
        return
    }
    config_foreach remove_switch_vlan switch_vlan

    uci -q commit network
}

util_plugin_restart() {
    /etc/init.d/pluginmanager start
    return
}

_get_single_proc_port_map() {
    local phy_id="$1"
    local ifname=""

    [ -n "$phy_id" ] && {
        [ -f "/proc/portmap/$phy_id" ] && {
            ifname=$(cat /proc/portmap/"$phy_id")
            echo "$ifname"
        }
    }
    return
}

_set_single_proc_port_map() {
    local phy_id="$1"
    local ifname="$2"

    [ -n "$ifname" ] && [ -n "$phy_id" ] && {
        [ -f "/proc/portmap/$phy_id" ] && {
            echo "$ifname" > /proc/portmap/"$phy_id"
        }
    }
    return
}

util_portmap_set() {
    _set_single_proc_port_map "$@"
    return
}

util_portmap_clear() {
    _set_single_proc_port_map "$1" "0"
    return
}

util_portmap_init() {
    _set_proc_port_map() {
        local port="$1"
        local ifname phy_id

        config_get phy_id "$port" phy_id
        config_get ifname "$port" ifname
        [ -z "$phy_id" ] && [ -z "$ifname" ] && return
        _set_single_proc_port_map "$phy_id" "$ifname"
    }

    config_load "port_map"
    config_foreach _set_proc_port_map port
}

util_portmap_clean() {
    _clear_proc_port_map() {
        local port="$1"
        local ifname phy_id

        config_get phy_id "$port" phy_id
        config_get ifname "$port" ifname
        [ -z "$ifname" ] || [ -z "$phy_id" ] && return
        _set_single_proc_port_map "$phy_id" "0"
    }

    config_load "port_map"
    config_foreach _clear_proc_port_map port
}

util_portmap_update() {
    local ports="$1"
    local port

    _update_proc_port_map() {
        local port="$1"
        local type phy_id ifname status

        [ "$(port_map config get "$port" type)" = "cpe" ] && return

        phy_id=$(port_map config get "$port" phy_id)
        ifname=$(_get_single_proc_port_map "$phy_id")
        [ -z "$ifname" ] && return
        status=$(phyhelper link port "$port" | cut -d ' ' -f 2 | cut -d ':' -f 2)
        util_iface_status_set "$ifname" "$status"
    }

    [ -z "$ports" ] && ports=$(port_map config get settings ports)
    for port in $ports; do
        _update_proc_port_map "$port"
    done
}

util_iface_status_set() {
    #$1: ifname
    #$2: iface status, "up" or "down"
    local ifname="$1"
    local status="$2"

    case "$status" in
    up)
        [ -f "/proc/portmap/10" ] && {
            echo "$ifname" >/proc/portmap/10
        }
        ;;
    down)
        [ -f "/proc/portmap/20" ] && {
            echo "$ifname" >/proc/portmap/20
        }
        ;;
    *)
        return
        ;;
    esac
    return
}

util_network_dedicated_get() {
    local ip_ver="$1"
    local wan_sec="$2"
    local dedicated="0"

    [ ! -f "/etc/config/cwmpcfglist" -o ! -f "/etc/config/easycwmp" ] && echo $dedicated && return

    local cwmpsec=$(uci -q get easycwmp.@local[0].bind_network)
    [ -z "$cwmpsec" ] && echo $dedicated && return

    if [ "$ip_ver" = "ipv4" ]; then
        local tr069_wan=$(uci -q get cwmpcfglist.$cwmpsec.network_v4)
        if [ -z "$wan_sec" -o "$tr069_wan" = "$wan_sec" ]; then
            dedicated=$(uci -q get cwmpcfglist.$cwmpsec.dedicated)
        else
            for cwmp in `awk '/^config.cwmp.cpe*/{print$3}' /etc/config/cwmpcfglist|tr "\'\"" " " `
            do
                local wan4=$(uci -q get cwmpcfglist.$cwmp.network_v4)
                if [ "$wan_sec" = "$wan4" ]; then
                    dedicated=$(uci -q get cwmpcfglist.$cwmp.dedicated)
                    [ "$dedicated" = "1" ] && break
                fi
            done
        fi
    elif [ "$ip_ver" = "ipv6" ]; then
        local tr069_wan6=$(uci -q get cwmpcfglist.$cwmpsec.network_v6)
        if [ -z "$wan_sec" -o "$tr069_wan6" = "$wan_sec" ]; then
            dedicated=$(uci -q get cwmpcfglist.$cwmpsec.dedicated)
        else
            for cwmp in `awk '/^config.cwmp.cpe*/{print$3}' /etc/config/cwmpcfglist|tr "\'\"" " " `
            do
                local wan6=$(uci -q get cwmpcfglist.$cwmp.network_v6)
                if [ "$wan_sec" = "$wan6" ]; then
                    dedicated=$(uci -q get cwmpcfglist.$cwmp.dedicated)
                    [ "$dedicated" = "1" ] && break
                fi
            done
        fi
    fi
    [ -z "$dedicated" ] && dedicated="0"

    echo $dedicated
}

util_network_dedicated_set() {
    [ ! -f "/etc/config/easycwmp" ] && return

    #set dns
    local dns_list="$1"
    local old_dns_list=$(uci -q get easycwmp.@acs[0].dns)
    [ "$old_dns_list" != "$dns_list" ] && {
        uci -q set easycwmp.@acs[0].dns="$dns_list"
        uci commit easycwmp
        ubus -t 3 call tr069 command '{"name": "reload"}' &
    }
}
