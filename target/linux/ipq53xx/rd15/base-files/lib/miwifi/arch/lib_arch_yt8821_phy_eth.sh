#!/bin/sh

YT8821_PHY_ATTR_PATH="/sys/module/yt_phy_module/port_status/port0/"

yt8821_phy_port_restart() {
    echo "0" > $YT8821_PHY_ATTR_PATH/power
    echo "1" > $YT8821_PHY_ATTR_PATH/power
}

yt8821_phy_port_mode_set() {
    local speed="$1"

    if [ "$speed" = "0" ]; then
        echo 1 > $YT8821_PHY_ATTR_PATH/10_autoNeg
        echo 1 > $YT8821_PHY_ATTR_PATH/100_autoNeg
        echo 1 > $YT8821_PHY_ATTR_PATH/1000_autoNeg
        echo 1 > $YT8821_PHY_ATTR_PATH/2500_autoNeg
    else
        echo 0 > $YT8821_PHY_ATTR_PATH/10_autoNeg
        echo 0 > $YT8821_PHY_ATTR_PATH/100_autoNeg
        echo 0 > $YT8821_PHY_ATTR_PATH/1000_autoNeg
        echo 0 > $YT8821_PHY_ATTR_PATH/2500_autoNeg
        echo 1 > $YT8821_PHY_ATTR_PATH/${speed}_autoNeg
    fi
}

yt8821_phy_port_mode_get() {
    local speed=""
    local autoNeg_10=$(cat $YT8821_PHY_ATTR_PATH/10_autoNeg)
    local autoNeg_100=$(cat $YT8821_PHY_ATTR_PATH/100_autoNeg)
    local autoNeg_1000=$(cat $YT8821_PHY_ATTR_PATH/1000_autoNeg)
    local autoNeg_2500=$(cat $YT8821_PHY_ATTR_PATH/2500_autoNeg)

    if [ "$autoNeg_1000" = "1" -a "$autoNeg_2500" = "1" ]; then
        speed="0" #Auto Negotiate
    else
        if [ "$autoNeg_2500" = "1" ]; then
            speed="2500"
        elif [ "$autoNeg_1000" = "1" ]; then
            speed="1000"
        elif [ "$autoNeg_100" = "1" ]; then
            speed="100"
        elif [ "$autoNeg_10" = "1" ]; then
            speed="10"
        fi
    fi

    echo "$speed"
}

yt8821_phy_port_link_status() {
    cat $YT8821_PHY_ATTR_PATH/speed | awk '{print $1}' | cut -d ':' -f 2
}

yt8821_phy_port_link_speed() {
    cat $YT8821_PHY_ATTR_PATH/speed | awk '{print $2}' | cut -d ':' -f 2
}

yt8821_phy_port_link_duplex() {
    cat $YT8821_PHY_ATTR_PATH/speed | awk '{print $3}'
}

yt8821_phy_port_power_on() {
    echo "1" > $YT8821_PHY_ATTR_PATH/power
}

yt8821_phy_port_power_off() {
    echo "0" > $YT8821_PHY_ATTR_PATH/power
}
