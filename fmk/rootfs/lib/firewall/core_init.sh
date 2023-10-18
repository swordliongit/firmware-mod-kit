# Copyright (C) 2009-2010 OpenWrt.org
# Copyright (C) 2008 John Crispin <blogic@openwrt.org>

FW_INITIALIZED=

FW_ZONES=
FW_ZONES4=
FW_ZONES6=
FW_CONNTRACK_ZONES=
FW_NOTRACK_DISABLED=						

FW_DEFAULTS_APPLIED=
FW_ADD_CUSTOM_CHAINS=
FW_ACCEPT_REDIRECTS=
FW_ACCEPT_SRC_ROUTE=
FW_WEB=

FW_DEFAULT_INPUT_POLICY=REJECT
FW_DEFAULT_OUTPUT_POLICY=REJECT
FW_DEFAULT_FORWARD_POLICY=REJECT

FW_DISABLE_IPV4=0
FW_DISABLE_IPV6=1

fw_load_init() {
	
	fw add i f INPUT   DROP { -m state --state INVALID }		
	fw add i f OUTPUT  DROP { -m state --state INVALID }
	fw add i f FORWARD DROP { -m state --state INVALID }
	

	fw add i f INPUT  ACCEPT { -i lo }
	fw add i f OUTPUT ACCEPT { -o lo }

	echo "DDOS init"
	fw_ddos_init
	
	echo "Packet filter init"	
	fw add i f MAC_FILTER
	fw add i f IP_PORT_FILTER
	fw add i f WEB_FILTER
	fw add i f SYS_FILTER

#	fw add i f INPUT MAC_FILTER
#	fw add i f INPUT IP_PORT_FILTER
	fw add i f INPUT SYS_FILTER
	fw add i f FORWARD MAC_FILTER
	#fw add i f FORWARD ACCEPT { -m state --state RELATED,ESTABLISHED }
	fw add i f FORWARD IP_PORT_FILTER
	#fw add i f FORWARD SYS_FILTER
	fw add i f FORWARD WEB_FILTER { -p tcp --dport 80 }
	
	echo "Port forward init"
	fw add i n DMZ
	fw add i n PORT_MAP
	#fw add i n SNAT_MASQ
	fw add i n PREROUTING DMZ
	fw add i n PREROUTING PORT_MAP
	fw add i n POSTROUTING SNAT_MASQ

	echo "ALGS init"
	fw_algs_init
	
	fw add i f INPUT   ACCEPT { -m state --state RELATED,ESTABLISHED }
	fw add i f OUTPUT  ACCEPT { -m state --state RELATED,ESTABLISHED }
	fw add i f FORWARD ACCEPT { -m state --state RELATED,ESTABLISHED }

	fw add i m MSS_FIX
	fw add i m MSS_FIX TCPMSS { -p tcp --tcp-flags SYN,RST SYN --clamp-mss-to-pmtu }
	fw add i m POSTROUTING MSS_FIX
	
	#fw add i f reject													
	#fw add i f reject REJECT { --reject-with tcp-reset -p tcp }
	#fw add i f reject REJECT { --reject-with port-unreach }
}

fw_load_defaults() {
	fw_config_get_section "$1" defaults { \
		string input $FW_DEFAULT_INPUT_POLICY \
		string output $FW_DEFAULT_OUTPUT_POLICY \
		string forward $FW_DEFAULT_FORWARD_POLICY \
		boolean tcp_syncookies 1 \
		boolean tcp_ecn 1 \
		boolean tcp_westwood 1 \
		boolean tcp_window_scaling 1 \
		boolean accept_redirects 0 \
		boolean accept_source_route 0 \
		boolean disable_ipv6 1 \
	} || return
	[ -n "$FW_DEFAULTS_APPLIED" ] && {
		fw_log error "duplicate defaults section detected, skipping"
		return 1
	}
	
	FW_DEFAULTS_APPLIED=1
	FW_DEFAULT_INPUT_POLICY=$defaults_input					
	FW_DEFAULT_OUTPUT_POLICY=$defaults_output				
	FW_DEFAULT_FORWARD_POLICY=$defaults_forward				

	FW_ACCEPT_REDIRECTS=$defaults_accept_redirects
	FW_ACCEPT_SRC_ROUTE=$defaults_accept_source_route

	FW_DISABLE_IPV6=$defaults_disable_ipv6						

	# Seems like there are only one sysctl for both IP versions.		
	for s in syncookies ecn westwood window_scaling; do
		eval "sysctl -e -w net.ipv4.tcp_${s}=\$defaults_tcp_${s}" >/dev/null
	done
	fw_sysctl_interface all

	fw_set_filter_policy													
}


fw_load_include() {
	local name="$1"

	local path; config_get path ${name} path
	[ -e $path ] && . $path
}


fw_clear() {
	local policy=$1

	fw_set_filter_policy $policy

	local tab
	for tab in f r; do 
		fw del i $tab
	done
	fw flush i n PREROUTTING
	fw flush i n POSTROUTING
	fw flush i n PORT_MAP
	fw flush i n DMZ
	fw flush i n NAT_ALGS
}

fw_set_filter_policy() {
	local policy=$1

	local chn tgt
	for chn in INPUT OUTPUT FORWARD; do
		eval "tgt=\${policy:-\${FW_DEFAULT_${chn}_POLICY}}"   	
		[ $tgt == "REJECT" ] && tgt=reject
		[ $tgt == "ACCEPT" -o $tgt == "DROP" ] || {				
			fw add i f $chn $tgt $								
			tgt=DROP
		}
		fw policy i f $chn $tgt									### 'i' means set dual IP STACK policy	
	done
}

