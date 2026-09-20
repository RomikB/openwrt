#!/bin/sh
#
# Copyright (c) 2019,2023 Qualcomm Technologies, Inc.
#
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

. /lib/wifi/wifi-utils.sh

WPAD_VARRUN="$(get_wpad_var_run)"

hostap_enable() {
	hostapd_cli -i $1 -p $WPAD_VARRUN/hostapd-$2 enable
}

hostap_disable() {
	hostapd_cli -i $1 -p $WPAD_VARRUN/hostapd-$2 disable
}

hostap_reconfig() {
	wpa_cli -g $WPAD_VARRUN/hostapd/global raw REMOVE $1
	wpa_cli -g $WPAD_VARRUN/hostapd/global raw ADD bss_config=$1:/var/run/hostapd-$1.conf
}

hostap_add_sta()
{
	hostapd_cli -i $1 -p $WPAD_VARRUN/hostapd-$2 new_sta $3
}

hostap_del_sta() {
	hostapd_cli -i $1 -p $WPAD_VARRUN/hostapd-$2 deauthenticate $3
}

IFNAME=$1
PARENT=$(cat /sys/class/net/${IFNAME}/parent)
CALLER=$(cat /proc/$PPID/cmdline)
echo "----> CALLER: $CALLER, PID: $PPID arg: $@ <-----" > /dev/console

case "$2" in
	enable) hostap_enable $IFNAME $PARENT;;
	disable) hostap_disable $IFNAME $PARENT;;
	reconfig) hostap_reconfig $IFNAME;;
	new_sta) hostap_add_sta $IFNAME $PARENT $3;;
	deauthenticate) hostap_del_sta $IFNAME $PARENT $3;;
	*)  echo "Invalid arguments. USAGE: hapd <ifname> <enable/disable/reconfig/new_sta/deauthenticate>";;
esac
