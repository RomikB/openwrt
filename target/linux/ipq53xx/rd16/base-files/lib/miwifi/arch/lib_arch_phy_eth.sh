#!/bin/sh


arch_phy_eth_port_restart() {
    local port="$1"
    local speed=""

    local phy_id=$(port_map config get $port phy_id)
    speed=$(switch_ctl phy "$phy_id" autoNeg get| cut -d ':' -f 3 | xargs)
    switch_ctl phy "$phy_id" autoNeg set "$speed"

    return 0
}

arch_phy_eth_port_mode_set() {
    local port="$1"
    local speed="$2"

    local phy_id=$(port_map config get $port phy_id)
    switch_ctl phy "$phy_id" autoNeg set "$speed"

    return 0
}

arch_phy_eth_port_mode_get() {
    local port="$1"
    local speed=""

    local phy_id=$(port_map config get $port phy_id)
    speed=$(switch_ctl phy "$phy_id" autoNeg get| cut -d ':' -f 3 | xargs)
    echo "$speed"
    return 0
}

arch_phy_eth_port_link_status() {
    local port="$1"
    local status=""

    local phy_id=$(port_map config get $port phy_id)
    status=$(swconfig dev switch1 port "$phy_id" get link | cut -d ' ' -f 2 | cut -d ':' -f 2)

    [ -n "$status" ] && echo "$status"
}

arch_phy_eth_port_link_speed() {
    local port="$1"
    local speed=""

    local phy_id=$(port_map config get $port phy_id)
    speed=$(swconfig dev switch1 port "$phy_id" get link | cut -d " " -f 3 | tr -cd "\[0-9\]")

    [ -z "$speed" ] && echo "0" || echo "$speed"
}

arch_phy_eth_port_link_duplex() {
    local port="$1"
    local duplex=""

    local phy_id=$(port_map config get $port phy_id)
    duplex=$(swconfig dev switch1 port "$phy_id" get link | grep duplex | cut -d " " -f 4 | cut -d '-' -f 1)

    [ -n "$duplex" ] && echo "$duplex"
}

arch_phy_eth_port_mib_info() {
    local port="$1"
    local que="$2"
    local res=""

    local phy_id=$(port_map config get $port phy_id)
    que=$(echo "$que" | awk '{print toupper($0)}')

    res=$(swconfig dev switch1 port "$phy_id" get mib | grep "$que" | awk -F ':' '{print $2}' | xargs)
    echo "$res"
}

arch_phy_eth_port_power_on() {
    local port="$1"

    local phy_id=$(port_map config get $port phy_id)
    switch_ctl phy "$phy_id" power 1

    return 0
}

arch_phy_eth_port_power_off() {
    local port="$1"

    local phy_id=$(port_map config get $port phy_id)
    switch_ctl phy "$phy_id" power 0

    return 0
}
