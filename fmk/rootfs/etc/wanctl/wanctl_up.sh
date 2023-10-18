#!/bin/sh

#shell will run when wan interface up
cmd="$1"
vlan_id="$2"
wan_mode="$3"
service_mode="$4"
tr069_protocol=`echo $service_mode | grep TR069`
voip_protocol=`echo $service_mode | grep VOIP`
internet_protocol=`echo $service_mode | grep INTERNET`

if [ -f /var/run/firewall.start ]; then
	/etc/init.d/firewall reload
fi
if [ -f /var/run/igmp.start ]; then
	/etc/init.d/igmp restart
fi
if [ -f /var/run/tr069.pid ]; then
#	kill -s USR1 "$(cat /var/run/tr069.pid)"
	tr_send -w
fi
if [ -f /var/run/rhwg ]; then
	voipcfg set 6.1 1
fi
if [ -f /etc/config/ddns ]; then
	/sbin/ddns_scripts.sh
fi
if [ -n "$internet_protocol" ]; then
    if [ "${wan_mode}" = "R" ]; then ## skip bridge conns
        if [ -x /usr/bin/wifidog ]; then
            . /lib/functions.sh
            . /usr/lib/wifidog; getTrustedIface; updateTrusted2
            local update=$(cat /tmp/.wanOldInfo|grep update|awk -F= '{print $2}')
            [ $update -eq 1 ] && {
                . /etc/init.d/iwifi; reconf; wdctl reconf
            }
        fi
    fi
fi
