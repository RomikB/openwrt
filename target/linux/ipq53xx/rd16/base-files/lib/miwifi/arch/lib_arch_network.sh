#!/bin/sh

arch_network_router_mode_init() { return; }
arch_network_re_mode_init()     { return; }
arch_network_ap_mode_init()     { return; }
arch_network_re_open()          { return; }

. /lib/miwifi/arch/lib_arch_accel.sh

_ecm_accel_mode_init() {
    _is_qos_enable && return
    [ "$(uci -q get ecm.global.acceleration_engine)" = "auto" ] && return

    uci -q batch <<EOF
        del ecm.global.service
        set ecm.global.acceleration_engine="auto"
        commit ecm
EOF

    /sbin/accelctrl restart
}

_close_eth_gro() {
    ethtool -K eth0 gro off
    ethtool -K eth1 gro off
}

arch_network_extra_init() {

    _ecm_accel_mode_init
    _close_eth_gro
}
