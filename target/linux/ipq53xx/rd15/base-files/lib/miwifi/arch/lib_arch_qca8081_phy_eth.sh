#!/bin/sh

qca8081_phy_port_restart() {
    ssdk_sh port autoNeg restart 1 >/dev/null 2>&1
}

qca8081_phy_port_mode_set() {
    local speed="$1"
    local write=""

    case "$speed" in
    0) write=0x123F ;;
    10) write=0x033 ;;
    100) write=0x03C ;;
    1000) write=0x230 ;;
    2500) write=0x1030 ;;
    *)
        return 1
        ;;
    esac

    ssdk_sh port autoAdv set 1 "$write" >/dev/null 2>&1
    ssdk_sh port autoNeg restart 1 >/dev/null 2>&1
    return 0
}

qca8081_phy_port_mode_get() {
    local autoAdv=""
    autoAdv=$(ssdk_sh port autoAdv get 1 | grep "autoneg" | cut -d ":" -f 2)
    echo "$autoAdv" | grep -Eq '1000T.*100T' && echo "0" && return 0
    echo "$autoAdv" | cut -d '|' -f 1 | tr -cd "0-9"
}

qca8081_phy_port_link_status() {
    swconfig dev switch0 port 1 get link | cut -d ' ' -f 2 | cut -d ':' -f 2
}

qca8081_phy_port_link_speed() {
    swconfig dev switch0 port 1 get link | cut -d " " -f 3 | tr -cd "\[0-9\]"
}

qca8081_phy_port_link_duplex() {
    swconfig dev switch0 port 1 get link | grep duplex | cut -d " " -f 4 | cut -d '-' -f 1
}

qca8081_phy_port_power_on() {
    ssdk_sh port poweron set 1 >/dev/null 2>&1
}

qca8081_phy_port_power_off() {
    ssdk_sh port poweroff set 1 >/dev/null 2>&1
}

