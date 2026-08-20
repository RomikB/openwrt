#!/bin/sh

# AP mode functions
#
#. /lib/miwifi/lib_ap_re.sh
#
# bridgeap_open()
# bridgeap_close()
#
# wifiap_open()
# wifiap_close()
#
# re_open()
# re_close()
# re_check_gw()
#

# Common network functions
#
#. /lib/miwifi/lib_network.sh
#
# network_re_mode()
# network_extra_init()
#

# Phy functions. switch/lte
#
#. /lib/miwifi/lib_phy.sh
#
# phy_port_stop()
# phy_port_start()
# phy_port_restart()
# phy_port_mode_get()
# phy_port_mode_set()
# phy_port_link_speed()
# phy_port_link_status()
#

# Hardware or software acceleration functions
#
# . /lib/miwifi/accel.sh
#
# $1 action : start | stop |restart
# network_accel_hook()
#
# $1 module : vpn|ipv6|qos ...
# $2 event : start|stop|open|close
# network_accel_hook()
#

for file in "/lib/miwifi"/lib_*; do
    source "${file}"
done
