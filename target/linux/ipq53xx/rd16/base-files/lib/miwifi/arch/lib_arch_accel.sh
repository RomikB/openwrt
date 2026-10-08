#!/bin/sh

_ecm_flush() {
    echo 1 > /sys/kernel/debug/ecm/ecm_db/defunct_all
}

_ecm_auto_mode() {
    [ "auto" != "$(uci -q get ecm.global.acceleration_engine)" ] && {
        uci set ecm.global.acceleration_engine="auto"
        uci commit ecm
        /etc/init.d/qca-nss-ecm reload
    }
}

_ecm_sfe_mode() {
    [ "sfe" != "$(uci -q get ecm.global.acceleration_engine)" ] && {
        uci set ecm.global.acceleration_engine="sfe"
        uci commit ecm
        /etc/init.d/qca-nss-ecm reload
    }
}

_is_qos_enable() {
    [ "1" = "$(uci -q get miqos.settings.force_disabled)" ] && return 1
    [ "1" = "$(uci -q get miqos.settings.enabled)" ] && return 0
    return 1
}

_enable_sfe() {
    local service="$1"
    local services

    services=$(uci -q get ecm.global.service)
    list_contains services "$service" || {
        uci -q add_list ecm.global.service="$service"
        uci commit ecm
    }

    _ecm_sfe_mode
}

_disable_sfe() {
    local service="$1"
    local services

    services=$(uci -q get ecm.global.service)
    list_contains services "$service" && {
        uci -q del_list ecm.global.service="$service"
        uci commit ecm
    }

    [ "$services" = "$service" ] && _ecm_auto_mode
}

_enter_ap_mode() {
    uci -q del ecm.global.service
    uci commit ecm
    _ecm_auto_mode
}

_quit_ap_mode() {
    _is_qos_enable && _enable_sfe "qos"
}

_update_qos_ifname() {
    local action="$1"
    echo "del all" > /proc/sys/net/ecm/sfe_qos_interface

    [ "$action" = "update" ] && {
        local wan_ifname=$(port_map iface service wan)
        local wan2_ifname=$(port_map iface service wan_2)
        [ "$(uci -q get port_service.iptv.enable)" = "1" ] && {
            brctl showmacs "br-internet" 2>&- >&- && wan_ifname="br-internet"
        }

        [ -n "$wan_ifname" ] && echo "add $wan_ifname" > /proc/sys/net/ecm/sfe_qos_interface
        [ -n "$wan2_ifname" ] && echo "add $wan2_ifname" > /proc/sys/net/ecm/sfe_qos_interface
        echo "add br-lan" > /proc/sys/net/ecm/sfe_qos_interface
        echo "add br-guest" > /proc/sys/net/ecm/sfe_qos_interface
    }
}



# $1 action : start | stop | restart | flush
arch_accel_control() {
    local action="$1"
    case $action in
    "start" | "stop")
        /etc/init.d/qca-nss-ecm "$action"
    ;;
    "restart")
        /etc/init.d/qca-nss-ecm reload
    ;;
    "flush")
        _ecm_flush
    ;;
    esac
}

arch_accel_event_ipv6_nat_start() {
    _ecm_flush
}

arch_accel_event_ipv6_nat_stop() {
    _ecm_flush
}

arch_accel_event_ipv6_passthrough_load() {
    if _is_qos_enable; then
        /usr/bin/pconfig set_fast_fdb 0
    else
        /usr/bin/pconfig set_fast_fdb 1
    fi
}

arch_accel_event_ipv6_passthrough_start() {
    _ecm_flush
}

arch_accel_event_ipv6_passthrough_stop() {
    _ecm_flush
}

arch_accel_event_vpn_start() {
    if [ "$(uci -q get network.wan.proto)" = "pppoe" ]; then
        _enable_sfe "vpn"
    else
        [ "$(uci -q get network.vpn.proto)" = "pptp" ] && [ -f "/etc/ppp/options.pptp" ] && {
            [ "$(grep -c nomppe /etc/ppp/options.pptp)" = "0" ] && _enable_sfe "vpn"
        }
    fi
}

arch_accel_event_vpn_stop() {
   _disable_sfe "vpn"
}

arch_accel_event_qos_start() {
    _update_qos_ifname "update"
    _enable_sfe "qos"
    _ecm_flush
}

arch_accel_event_qos_stop() {
    _disable_sfe "qos"
    _update_qos_ifname "clean"
}

arch_accel_event_qos_update() {
    _update_qos_ifname "update"
}

arch_accel_event_lanap_open() {
    _enter_ap_mode
}

arch_accel_event_lanap_close() {
    _quit_ap_mode
}

arch_accel_event_wifiap_open() {
    _enter_ap_mode
}

arch_accel_event_wifiap_close() {
    _quit_ap_mode
}

arch_accel_event_whc_re_open() {
    _enter_ap_mode
}

arch_accel_event_whc_re_close() {
    _quit_ap_mode
}
