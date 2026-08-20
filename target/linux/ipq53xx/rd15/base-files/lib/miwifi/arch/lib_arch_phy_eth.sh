#!/bin/sh

#LAN4 is a 2.5G phy and not a switch port
PHY_TYPE=$( [ -d /sys/bus/mdio_bus/devices/90000.mdio:0c ] && echo "qca8081" || echo "yt8821")

. /lib/miwifi/arch/lib_arch_${PHY_TYPE}_phy_eth.sh

__is_phy_port() {
    [ "$1" = "4" ] && return 0
    return 1
}

arch_phy_eth_port_restart() {
    local port="$1"
    local speed=""

    if __is_phy_port "$port"; then
        eval ${PHY_TYPE}_phy_port_restart
    else
        local phy_id=$(port_map config get $port phy_id)
        speed=$(switch_ctl phy "$phy_id" autoNeg get| cut -d ':' -f 3 | xargs)
        switch_ctl phy "$phy_id" autoNeg set "$speed"
    fi

    return 0
}

arch_phy_eth_port_mode_set() {
    local port="$1"
    local speed="$2"

    if __is_phy_port "$port"; then
        eval ${PHY_TYPE}_phy_port_mode_set "$speed"
        eval ${PHY_TYPE}_phy_port_restart
    else
        local phy_id=$(port_map config get $port phy_id)
        switch_ctl phy "$phy_id" autoNeg set "$speed"
    fi

    return 0
}

arch_phy_eth_port_mode_get() {
    local port="$1"
    local speed=""

    if __is_phy_port "$port"; then
        eval speed=$(${PHY_TYPE}_phy_port_mode_get)
    else
        local phy_id=$(port_map config get $port phy_id)
        speed=$(switch_ctl phy "$phy_id" autoNeg get| cut -d ':' -f 3 | xargs)
    fi

    echo "$speed"
    return 0
}

arch_phy_eth_port_link_status() {
    local port="$1"
    local status=""

    if __is_phy_port "$port"; then
        status=$(${PHY_TYPE}_phy_port_link_status)
    else
        local phy_id=$(port_map config get $port phy_id)
        status=$(swconfig dev switch1 port "$phy_id" get link | cut -d ' ' -f 2 | cut -d ':' -f 2)
    fi

    [ -n "$status" ] && echo "$status"
}

arch_phy_eth_port_link_speed() {
    local port="$1"
    local speed=""

    if __is_phy_port "$port"; then
        speed=$(${PHY_TYPE}_phy_port_link_speed)
    else
        local phy_id=$(port_map config get $port phy_id)
        speed=$(swconfig dev switch1 port "$phy_id" get link | cut -d " " -f 3 | tr -cd "\[0-9\]")
    fi

    [ -z "$speed" ] && echo "0" || echo "$speed"
}

arch_phy_eth_port_link_duplex() {
    local port="$1"
    local duplex=""

    if __is_phy_port "$port"; then
        duplex=$(${PHY_TYPE}_phy_port_link_duplex)
    else
        local phy_id=$(port_map config get $port phy_id)
        duplex=$(swconfig dev switch1 port "$phy_id" get link | grep duplex | cut -d " " -f 4 | cut -d '-' -f 1)
    fi

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

    if __is_phy_port "$port"; then
        eval ${PHY_TYPE}_phy_port_power_on
    else
        local phy_id=$(port_map config get $port phy_id)
        switch_ctl phy "$phy_id" power 1
    fi

    return 0
}

arch_phy_eth_port_power_off() {
    local port="$1"

    if __is_phy_port "$port"; then
        eval ${PHY_TYPE}_phy_port_power_off
    else
        local phy_id=$(port_map config get $port phy_id)
        switch_ctl phy "$phy_id" power 0
    fi
    return 0
}
