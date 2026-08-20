#!/bin/sh
# Copyright (C) 2009 OpenWrt.org

setup_switch_dev() {
	local name
	config_get name "$1" name
	name="${name:-$1}"
	[ -d "/sys/class/net/$name" ] && ip link set dev "$name" up
	swconfig dev "$name" load network
}

setup_switch() {
	[ -e /usr/sbin/switch_ctl ] && {
		switch_ctl forward 0
		echo -e "[setup_switch] stop port forward" > /dev/console
	}
	config_load network
	config_foreach setup_switch_dev switch
	[ -e /usr/sbin/switch_ctl ] && {
		switch_ctl forward 1
		echo -e "[setup_switch] start port forward" > /dev/console
	}
}
