#!/bin/sh

arch_lanap_pre_connect()  { return; }
arch_lanap_post_connect() { return; }
arch_lanap_open()         { return; }
arch_lanap_close()        { return; }

arch_wifiap_open()  { return; }
arch_wifiap_close() { return; }

arch_whc_re_open()     { return; }
arch_whc_re_close()    { return; }

arch_cpe_bridgemode_open()  { return; }
arch_cpe_bridgemode_close() { return; }

. /lib/miwifi/arch/lib_arch_ap_re.sh
. /lib/miwifi/miwifi_functions.sh
################################## static ##################################

_check_wan_proto() {
    [ "pppoe" = "$(uci -q get network.wan.proto)" ] || return
    [ -z "$(uci -q get network.wan.username)" ] && [ -z "$(uci -q get network.wan.password)" ] && {
        uci set network.wan.proto="dhcp"
        uci commit network
    }
}

_unload_passthrough() {
    [ -d /sys/module/passthrough ] && rmmod passthrough
}

################################## export ##################################

wifiap_open() {
    util_log "=== wifiap open ==="
    _unload_passthrough
    _check_wan_proto
    port_service reconfig ap
    arch_wifiap_open
    return
}

wifiap_close() {
    util_log "=== wifiap close ==="
    port_service reconfig router
    arch_wifiap_close
    return
}

lanap_pre_connect() {
    util_log "=== lanap pre connect ==="
    arch_lanap_pre_connect
    return
}

lanap_post_connect() {
    util_log "=== lanap post connect ==="
    arch_lanap_post_connect
    return
}

lanap_open() {
    util_log "=== lanap open ==="
    _unload_passthrough
    _check_wan_proto
    port_service reconfig ap
    arch_lanap_open
    return
}

lanap_close() {
    util_log "=== lanap close ==="
    port_service reconfig router
    arch_lanap_close
    return
}

whc_re_open() {
    util_log "=== whc_re open ==="
    _check_wan_proto
    port_service reconfig ap
    arch_whc_re_open
    return
}

whc_re_close() {
    util_log "=== whc_re close ==="
    return
}

cpe_bridgemode_open() {
    util_log "=== cpe bridge mode open ==="
    cp /etc/config/port_service /etc/config/.port_service.router.config
    port_service reconfig ap default
    arch_cpe_bridgemode_open
    return
}

cpe_bridgemode_close() {
    util_log "=== cpe bridge mode close ==="
    if [ -f "/etc/config/.port_service.router.config" ]; then
        mv /etc/config/.port_service.router.config /etc/config/port_service
    else
        port_service reconfig router default
    fi

    arch_cpe_bridgemode_close
    return
}
