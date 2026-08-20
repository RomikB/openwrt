#!/bin/sh


arch_pm_config_interface()        { return 1; }
arch_pm_config_switch_vlan()      { return 1; }
arch_pm_clean_network()           { return 1; }
arch_pm_extra_rebuild_map()       { return 0; }
arch_pm_extra_rebuild_network()   { return 0; }
arch_pm_extra_rebuild_proc()      { return 0; }
arch_pm_forward_set_off()         { return 0; }
arch_pm_forward_set_on()          { return 0; }
[ -f "/lib/miwifi/arch/lib_arch_port_map.sh" ] && . /lib/miwifi/arch/lib_arch_port_map.sh


pm_extra_rebuild_map() {
    arch_pm_extra_rebuild_map "$@"
}

pm_extra_rebuild_network() {
    arch_pm_extra_rebuild_network "$@"
}

pm_extra_rebuild_proc() {
    arch_pm_extra_rebuild_proc "$@"
}

pm_config_interface() {
    local ifname="$1"
    local section_name

    arch_pm_config_interface "$ifname" && return

    section_name="${ifname//./_}"
    uci -q get network."$section_name" > /dev/null 2>&1 && return
    uci batch <<-EOF
		set network."$section_name"=interface
		set network."$section_name".ifname="$ifname"
		commit network
	EOF
    return
}

pm_config_switch_vlan() {
    local switch="$1"
    local ports="$2"
    local vid="$3"
    local section_name

    arch_pm_config_switch_vlan "$switch" "$ports" "$vid" && return

    section_name="vlan${vid}"
    uci -q get network."$section_name" > /dev/null 2>&1 && return
    uci batch <<-EOF
		set network."$section_name"="switch_vlan"
		set network."$section_name".device="$switch"
		set network."$section_name".ports="$ports"
		set network."$section_name".vlan="$vid"
		set network."$section_name".vid="$vid"
		commit network
	EOF
    return
}

pm_clean_network() {
    local vlan_type="$1"
    local section sections

    arch_pm_clean_network "$vlan_type" && return

    # clean interface
    sections=$(uci show network | grep '=interface' | grep -sE "eth[0-9]_" | cut -d '=' -f 1)
    for section in $sections; do
        uci del "$section"
    done

    # clean switch vlan
    sections=$(uci show network | grep '=switch_vlan' | grep -sE "vlan" | cut -d '=' -f 1)
    for section in $sections; do
        uci del "$section"
    done

    uci commit network
    return
}

pm_build_network() {
    local vlan_type="$1"
    local vid list_vid
    local port ports
    local group groups
    local switch cpu_port phy_id list_switch

    [ -z "$vlan_type" ] && return

    get_new_vid() {
        local new_vid="1"
        while true; do
            list_contains list_vid "$new_vid" || {
                echo "$new_vid"
                break
            }
            new_vid=$((new_vid + 1))
        done
        return
    }

    arch_pm_forward_set_off

    # collect all used vid
    list_vid=$(uci -q get "$SERVICE".settings.service_vids)

    # build network config
    ports=$(pm_config_get settings ports)
    if [ "portbase" = "$vlan_type" ]; then
        for port in $ports; do
            [ "$(pm_config_get "$port" type)" = "cpe" ] && continue

            switch=$(pm_config_get "$port" switch)
            phy_id=$(pm_config_get "$port" phy_id)
            cpu_port=$(pm_config_get "$port" cpu_port)
            [ -z "$switch" ] || [ -z "$phy_id" ] || [ -z "$cpu_port" ] && continue

            if list_contains groups "${switch}_${cpu_port}"; then
                pm_config_set "$port" vid "$(eval echo \$"${switch}_${cpu_port}_vid")"
            else
                # rely on switch and cpu port to group
                append groups "${switch}_${cpu_port}"

                # generate and save this group's vid info
                vid=$(get_new_vid) && append list_vid "$vid"
                eval "${switch}_${cpu_port}_vid"="$vid"
                pm_config_set "$port" vid "$vid"
            fi
            list_contains "${switch}_${cpu_port}" "$phy_id" || append "${switch}_${cpu_port}" "$phy_id"

            pm_config_set "$port" ifname "$(pm_config_get "$port" base_iface)"
            util_portmap_clear "$phy_id"
        done

        for group in $groups; do
            switch=$(echo "$group" | cut -d '_' -f 1)
            cpu_port=$(echo "$group" | cut -d '_' -f 2)
            vid=$(eval echo \$"${group}_vid")
            switch_vlan_ports=$(eval echo \$"${group}")
            switch_vlan_ports="${switch_vlan_ports} ${cpu_port}"
            pm_config_switch_vlan "$switch" "$switch_vlan_ports" "$vid"
            list_contains list_switch "$switch" || append list_switch "$switch"
        done
    elif [ "8021q" = "$vlan_type" ]; then
        for port in $ports; do
            vid=$(pm_config_get "$port" vid)
            if list_contains list_vid "$vid"; then
                # mark the port which vid conflict
                pm_config_set "$port" vid ""
            else
                append list_vid "$vid"
            fi
        done

        for port in $ports; do
            type=$(pm_config_get "$port" type)
            [ "$type" = "cpe" ] && continue

            switch=$(pm_config_get "$port" switch)
            phy_id=$(pm_config_get "$port" phy_id)
            cpu_port=$(pm_config_get "$port" cpu_port)

            [ -z "$switch" ] || [ -z "$phy_id" ] || [ -z "$cpu_port" ] && {
                pm_config_set "$port" vid ""
                pm_config_set "$port" ifname "$(pm_config_get "$port" base_iface)"
                [ -n "$phy_id" ] && util_portmap_clear "$phy_id"
                continue
            }

            base_iface=$(pm_config_get "$port" base_iface)
            switch_vlan_ports="$phy_id ${cpu_port}t"
            vid=$(pm_config_get "$port" vid)
            [ -z "$vid" ] && vid=$(get_new_vid) && append list_vid "$vid"

            pm_config_switch_vlan "$switch" "$switch_vlan_ports" "$vid"
            list_contains list_switch "$switch" || append list_switch "$switch"
            pm_config_interface "${base_iface}.${vid}"
            pm_config_set "$port" vid "$vid"
            pm_config_set "$port" ifname "${base_iface}.${vid}"
            util_portmap_set "$phy_id" "${base_iface}.${vid}"
        done
    fi

    for switch in $list_switch; do
        swconfig dev "$switch" load network
    done

    arch_pm_forward_set_on
    return
}

pm_extra_rebuild_portmap() {
    arch_pm_extra_rebuild_portmap "$@"
    return
}