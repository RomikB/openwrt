#!/bin/sh

arch_pm_forward_set_off()
{
    [ -e /usr/sbin/switch_ctl ] && {
        switch_ctl forward 0
        echo -e "[port_map] stop port forward" > /dev/console
    }
}

arch_pm_forward_set_on()
{
    [ -e /usr/sbin/switch_ctl ] && {
        switch_ctl forward 1
        echo -e "[port_map] start port forward" > /dev/console
    }
}