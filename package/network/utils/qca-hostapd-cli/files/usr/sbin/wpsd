#!/bin/sh
#
# Copyright (c) 2019,2023 Qualcomm Technologies, Inc.
#
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#

. /lib/wifi/wifi-utils.sh

WPAD_VARRUN="$(get_wpad_var_run)"

wpa_supplicant_enable() {
	wpa_cli -p $WPAD_VARRUN/wpa_supplicant-$1/ reconnect
}

wpa_supplicant_disable() {
	wpa_cli -p $WPAD_VARRUN/wpa_supplicant-$1/ disconnect
}

wpa_supplicant_reconfig() {
	wpa_cli -p $WPAD_VARRUN/wpa_supplicant-$1/ reconfigure
}

IFNAME=$1

case "$2" in
	enable) wpa_supplicant_enable $IFNAME;;
	disable) wpa_supplicant_disable $IFNAME;;
	reconfig) wpa_supplicant_reconfig $IFNAME;;
	*)  echo "Invalid arguments. USAGE: wpsd <ifname> <enable/disable/reconfig>";;
esac
