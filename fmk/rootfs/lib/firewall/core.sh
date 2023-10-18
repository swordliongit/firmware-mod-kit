# Copyright (C) 2009-2010 OpenWrt.org

FW_LIBDIR=${FW_LIBDIR:-/lib/firewall}  		

. $FW_LIBDIR/fw.sh
include /lib/network

fw_start() {
	fw_init
	
	FW_DEFAULTS_APPLIED=
	FW_ALGS_APPLIED=
	FW_DDOS_APPLIED=

	fw_is_loaded && {
		echo "firewall already loaded" >&2
		exit 1
	}

	uci_set_state firewall core "" firewall_state

	fw_clear DROP						
	
	echo "Init ..."
	fw_load_init
	echo "Loading config ..."
	reload_fw
	
	uci_set_state firewall core loaded 1
}

fw_stop() {
	fw_init
	
	fw_clear ACCEPT				### 
	
	uci_revert_state firewall
	config_clear					### what ?

	unset FW_INITIALIZED
}

fw_restart() {
	fw_stop
	fw_start
}

reload_fw() {
	echo "Loading defaults"
	FW_DEFAULTS_APPLIED=
	fw_load_defaults
	fw_config_once fw_load_defaults defaults
	
	echo "Loading DDOS"
	fw_ddos_fini
	FW_DDOS_APPLIED=
	fw_config_once fw_load_ddos ddos
	
	echo "Loading Packet Filters"
	fw flush i f MAC_FILTER
	fw_config_once fw_load_policy MAC MAC
	if [ "$MAC_policy" == "deny" ] && [ "$MAC_state" == "1" ]; then
		config_foreach fw_load_macfilter mac_deny deny
	elif [ "$MAC_policy" == "permit" ] && [ "$MAC_state" == "1" ]; then
		config_foreach fw_load_macfilter mac_permit permit
		#local gw_mac=$(ifconfig br-lan|grep HWaddr|awk '{print $5}')
		#fw add i filter MAC_FILTER ACCEPT { -m mac --mac-source $gw_mac }
		fw add i filter MAC_FILTER DROP { -i br-lan }
	fi
	
	fw flush i f IP_PORT_FILTER
	fw_config_once fw_load_policy IPPORT IPPORT 
	if [ "$IPPORT_policy" == "deny" ] && [ "$IPPORT_state" == "1" ]; then
		config_foreach fw_load_ipport ipport_deny deny
	elif [ "$IPPORT_policy" == "permit" ] && [ "$IPPORT_state" == "1" ]; then
		config_foreach fw_load_ipport ipport_permit permit
		fw add i filter IP_PORT_FILTER DROP
	fi
	
	fw flush i f WEB_FILTER
	fw_config_once fw_load_policy URL URL
	if [ "$URL_policy" == "deny" ] && [ "$URL_state" == "1" ]; then
		config_foreach fw_load_url url_deny deny
	elif [ "$URL_policy" == "permit" ] && [ "$URL_state" == "1" ]; then
		config_foreach fw_load_url url_permit permit
		fw add i filter WEB_FILTER DROP { -i br-lan -m webstr --all all }
	fi
	
	fw flush i f SYS_FILTER
	config_foreach fw_load_sysfilter sysfilter
	iptables -A SYS_FILTER ! -i br-lan -p udp --dport 53 -j DROP
	iptables -A SYS_FILTER ! -i br-lan -p tcp --dport 53 -j DROP

	echo "Loading Portmaping & DMZ"
	fw flush i n DMZ
	config_foreach fw_load_dmz dmz
	fw flush i n PORT_MAP
	config_foreach fw_load_redirect redirect


	echo "Loading ALGS"
	fw_algs_fini
	FW_ALGS_APPLIED=
	fw_config_once fw_load_algs algs

}

fw_reload() {
	
	fw_init
	
	[ "$#" == 0 ] && {
		#fw_restart
		reload_fw
		return 
	}
		
	case "$1" in
	    DMZ) 
	    	fw flush i n DMZ
	    	config_foreach fw_load_dmz dmz
	    	;;
	    PortMapping)
		fw flush i n PORT_MAP
		config_foreach fw_load_redirect redirect
		;;
	    IpportFilter)
	    	fw flush i f IP_PORT_FILTER
		fw_config_once fw_load_policy IPPORT IPPORT 
		if [ "$IPPORT_policy" == "deny" ] && [ "$IPPORT_state" == "1" ]; then
			config_foreach fw_load_ipport ipport_deny deny
		elif [ "$IPPORT_policy" == "permit" ] && [ "$IPPORT_state" == "1" ]; then
			config_foreach fw_load_ipport ipport_permit permit
			fw add i filter IP_PORT_FILTER DROP { ! -i br-lan }
		fi
	    	;;
	    MacFilter)
	    	fw flush i f MAC_FILTER
		fw_config_once fw_load_policy MAC MAC
		if [ "$MAC_policy" == "deny" ] && [ "$MAC_state" == "1" ]; then
			config_foreach fw_load_macfilter mac_deny deny
		elif [ "$MAC_policy" == "permit" ] && [ "$MAC_state" == "1" ]; then
			config_foreach fw_load_macfilter mac_permit permit
			fw add i filter MAC_FILTER DROP { -i br-lan }
		fi
		;;
	    WebFilter)
	    	fw flush i f WEB_FILTER
		fw_config_once fw_load_policy URL URL
			if [ "$URL_policy" == "deny" ] && [ "$URL_state" == "1" ]; then
				config_foreach fw_load_url url_deny deny
			elif [ "$URL_policy" == "permit" ] && [ "$URL_state" == "1" ]; then
				config_foreach fw_load_url url_permit permit
				fw add i filter WEB_FILTER DROP { -i br-lan -m webstr --all all }
			fi
		;;
	    SysFilter)
	    	fw flush i f SYS_FILTER
		config_foreach fw_load_sysfilter sysfilter
		iptables -A SYS_FILTER ! -i br-lan -p udp --dport 53 -j DROP
		iptables -A SYS_FILTER ! -i br-lan -p tcp --dport 53 -j DROP
		;;
	    ALGS)
	    	fw_algs_fini
		FW_ALGS_APPLIED=
		fw_config_once fw_load_algs algs
		;;
	    DDOS)
	    	fw_ddos_fini
		FW_DDOS_APPLIED=
		fw_config_once fw_load_ddos ddos
	    	;;
	    *) fw_log error "reload";;
	esac
}

fw_is_loaded() {
	local bool=$(uci_get_state firewall.core.loaded)
	return $((! ${bool:-0}))
}


fw_die() {
	echo "Error:" "$@" >&2
	fw_log error "$@"
	fw_stop
	exit 1
}

fw_log() {
	local level="$1"
	[ -n "$2" ] && shift || level=notice
	[ "$level" != error ] || echo "Error: $@" >&2
	logger -t firewall -p user.$level "$@"
}


fw_init() {
	[ -z "$FW_INITIALIZED" ] || return 0  				
	. $FW_LIBDIR/config.sh
	
	#scan_interfaces
	#fw_config_append firewall
	config_load firewall
	
	for file in $FW_LIBDIR/core_*.sh; do
		. $file
	done
	for file in $FW_LIBDIR/*.sh; do
		lib=$(basename $file .sh)	
		lib=${lib##[0-9][0-9]_}						
		case $lib in
			core*|fw|config|uci_firewall) continue ;;
		esac
		. $file
	done

	FW_INITIALIZED=1
	return 0
}
