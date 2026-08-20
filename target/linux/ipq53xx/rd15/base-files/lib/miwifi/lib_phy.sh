#!/bin/sh

# port type: eth
arch_phy_eth_port_restart()     { return 0; }
arch_phy_eth_port_mode_get()    { return 0; }
arch_phy_eth_port_mode_set()    { return 0; }
arch_phy_eth_port_power_on()    { return 0; }
arch_phy_eth_port_power_off()   { return 0; }
arch_phy_eth_port_link_speed()  { return 0; }
arch_phy_eth_port_link_status() { return 0; }
arch_phy_eth_port_link_duplex() { return 0; }
arch_phy_eth_port_mib_info()    { return 0; }
arch_phy_eth_port_fdb_dump()    { return 0; }
arch_phy_eth_port_fdb_port()    { return 0; }
arch_phy_eth_port_fdb_mac()     { return 0; }

[ -e "/lib/miwifi/arch/lib_arch_phy_eth.sh" ] && . /lib/miwifi/arch/lib_arch_phy_eth.sh


# port type: sfp
arch_phy_sfp_port_restart()     { return 0; }
arch_phy_sfp_port_mode_get()    { return 0; }
arch_phy_sfp_port_mode_set()    { return 0; }
arch_phy_sfp_port_power_on()    { return 0; }
arch_phy_sfp_port_power_off()   { return 0; }
arch_phy_sfp_port_link_speed()  { return 0; }
arch_phy_sfp_port_link_status() { return 0; }
arch_phy_sfp_port_link_duplex() { return 0; }
arch_phy_sfp_port_mib_info()    { return 0; }

[ -e "/lib/miwifi/arch/lib_arch_phy_sfp.sh" ] && . /lib/miwifi/arch/lib_arch_phy_sfp.sh


# port type: cpe
arch_phy_cpe_port_restart()     { return 0; }
arch_phy_cpe_port_mode_get()    { return 0; }
arch_phy_cpe_port_mode_set()    { return 0; }
arch_phy_cpe_port_power_on()    { return 0; }
arch_phy_cpe_port_power_off()   { return 0; }
arch_phy_cpe_port_link_speed()  { return 0; }
arch_phy_cpe_port_link_status() { return 0; }
arch_phy_cpe_port_link_duplex() { return 0; }
arch_phy_cpe_port_mib_info()    { return 0; }

[ -e "/lib/miwifi/arch/lib_arch_phy_cpe.sh" ] && . /lib/miwifi/arch/lib_arch_phy_cpe.sh

phy_port_stop() {
    eval arch_phy_"$1"_port_power_off "$2"
    return
}

phy_port_start() {
    eval arch_phy_"$1"_port_power_on "$2"
    return
}

phy_port_restart() {
    eval arch_phy_"$1"_port_restart "$2"
    return
}

phy_port_mode_get() {
    eval arch_phy_"$1"_port_mode_get "$2"
    return
}

phy_port_mode_set() {
    eval arch_phy_"$1"_port_mode_set "$2" "$3"
    return
}

phy_port_link_speed() {
    eval arch_phy_"$1"_port_link_speed "$2"
    return
}

phy_port_link_duplex() {
    eval arch_phy_"$1"_port_link_duplex "$2"
    return
}

phy_port_link_status() {
    eval arch_phy_"$1"_port_link_status "$2"
    return
}

phy_port_mib_info() {
    eval arch_phy_"$1"_port_mib_info "$2" "$3"
    return
}

phy_port_fdb_dump() {
    eval arch_phy_"$1"_port_fdb_dump
    return
}

phy_port_fdb_port() {
    eval arch_phy_"$1"_port_fdb_port "$2"
    return
}

phy_port_fdb_mac() {
    eval arch_phy_"$1"_port_fdb_mac "$2"
    return
}