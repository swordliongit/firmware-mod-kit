# /usr/lib/dynamic_dns/dynamic_dns_functions.sh
#
# Written by Eric Paul Bishop, Janary 2008
# Distributed under the terms of the GNU General Public License (GPL) version 2.0
#
# This script is (loosely) based on the one posted by exobyte in the forums here:
# http://forum.openwrt.org/viewtopic.php?id=14040



. /etc/functions.sh
include /lib/network


#loads all options for a given package and section
#also, sets all_option_variables to a list of the variable names
load_all_config_options()
{
	pkg_name="$1"
	section_id="$2"

	ALL_OPTION_VARIABLES=""
	# this callback loads all the variables
	# in the section_id section when we do
	# config_load. We need to redefine
	# the option_cb for different sections
	# so that the active one isn't still active
	# after we're done with it.  For reference
	# the $1 variable is the name of the option
	# and $2 is the name of the section
	config_cb()
	{
		if [ ."$2" = ."$section_id" ]; then
			option_cb()
			{
				ALL_OPTION_VARIABLES="$ALL_OPTION_VARIABLES $1"
			}
		else
			option_cb() { return 0; }
		fi
	}


	config_load "$pkg_name"
	for var in $ALL_OPTION_VARIABLES
	do
		config_get "$var" "$section_id" "$var"
	done
}

wanctl_get_iface_ddns() {
        local _var="$1"
        local _iface="$2"
        [ -d /tmp/run/netconfig/$_iface -a -f /tmp/run/netconfig/$_iface/netcfg.conf ] && \
                export -n -- "$_var=$(cat /tmp/run/netconfig/$_iface/netcfg.conf|grep ip|awk -F '=' '{ print $2}')" || \
                export -n -- "$_var="
}

#

get_current_ip()
{

	#if ip source is not defined, assume we want to get ip from wan 
#	if [ "$ip_source" != "interface" ] && [ "$ip_source" != "web" ] && [ "$ip_source" != "script" ]
#	then
#		ip_source="network"
#	fi
#
#	if [ "$ip_source" = "network" ]
#	then
#		if [ -z "$ip_network" ]
#		then
#			ip_network="wan"
#		fi
#		scan_interfaces
#		config_load /var/state/network
#		config_get ip_interface $ip_network ifname
#	fi
#
#	current_ip='';
#	if [ "$ip_source" = "network" ] || [ "$ip_source" = "interface" ]
#	then
#		current_ip=$(ifconfig $ip_interface | grep -o 'inet addr:[0-9.]*' | grep -o "$ip_regex")
#	elif [ "$ip_source" = "script" ]
#	then
#		# get ip from script
#		current_ip=$($ip_script)
#	else
#		# get ip from web
#		# we check each url in order in ip_url variable, and if no ips are found we use dyndns ip checker
#		# ip is set to FIRST expression in page that matches the ip_regex regular expression
#		for addr in $ip_url
#		do
#			if [ -z "$current_ip" ]
#			then
#				current_ip=$(echo $( wget -O - $addr 2>/dev/null) | grep -o "$ip_regex")
#			fi
#		done
#
#		#here we hard-code the dyndns checkip url in case no url was specified
#		if [ -z "$current_ip" ]
#		then
#			current_ip=$(echo $( wget -O - http://checkip.dyndns.org 2>/dev/null) | grep -o "$ip_regex")
#		fi
#	fi
#
#	echo "$current_ip"
	current_ip=''
	if [ "$ip_source" = "interface" ]
	then
		local ddns_iface="default"
		[ -n $iface ] && ddns_iface="$iface"
		wanctl_get_iface_ddns  current_ip  "$ddns_iface"		
	fi
	echo "$current_ip"
}


verbose_echo()
{
	if [ "$verbose_mode" = 1 ]
	then
		echo $1
	fi
}

start_daemon_for_all_ddns_sections()
{
	SECTIONS=""
	config_cb() 
	{
		SECTIONS="$SECTIONS $2"
	}
	config_load "ddns"

	for section in $SECTIONS
	do
		/usr/lib/ddns/dynamic_dns_updater.sh $section 0 > /dev/null 2>&1 &
	done
}

monotonic_time()
{
	local uptime
	read uptime < /proc/uptime
	echo "${uptime%%.*}"
}
