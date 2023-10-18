#!/bin/sh

#shell will run when wan interface delete
local cmd="$1"
local vlan_id="$2"
local wan_mode="$3"
local service_mode="$4"
local tr069_protocol=`echo $service_mode | grep TR069`
local voip_protocol=`echo $service_mode | grep VOIP`

if [ -f /var/run/firewall.start ]; then
	/etc/init.d/firewall reload
fi

if [ -f /var/run/igmp.start ]; then
	/etc/init.d/igmp restart
fi

if [ -f /var/run/tr069.pid ]; then
	kill -s USR1 "$(cat /var/run/tr069.pid)"
fi

if [ -n "$voip_protocol" ]; then
	if [ -f /var/run/rhwg ]; then
		voipcfg set 6.1 1
	fi
fi
