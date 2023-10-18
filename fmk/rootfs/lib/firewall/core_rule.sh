# Copyright (C) 2009-2010 OpenWrt.org

fw_config_get_sysfilter() {
	[ "${sysfilter_NAME}" != "$1" ] || return
	fw_config_get_section "$1" sysfilter { \
		string _name "$1" \
		string name "" \
		ipaddr src_ip "" \
		string src_mac "" \
		string src_port "" \
		ipaddr dest_ip "" \
		string dest_port "" \
		string icmp_type "" \
		string proto "TCPUDP" \
		string target "" \
		string family ipv4 \
	} || return
	[ -n "$sysfilter_name" ] || sysfilter_name=$sysfilter__name
	[ "$sysfilter_proto" == "icmp" ] || sysfilter_icmp_type=
}

fw_load_sysfilter() {
	fw_config_get_sysfilter "$1"

	fw_get_port_range sysfilter_src_port $sysfilter_src_port
	fw_get_port_range sysfilter_dest_port $sysfilter_dest_port

	local table=f
	local chain=SYS_FILTER
	local target="${sysfilter_target:-REJECT}"				

	local mode
	fw_get_family_mode mode ${sysfilter_family:-x} I

	local src_spec dest_spec
	fw_get_negation src_spec '-s' "${sysfilter_src_ip:+$sysfilter_src_ip/$sysfilter_src_ip_prefixlen}"
	fw_get_negation dest_spec '-d' "${sysfilter_dest_ip:+$sysfilter_dest_ip/$sysfilter_dest_ip_prefixlen}"

	[ "$sysfilter_proto" == "TCPUDP" ] && sysfilter_proto="tcp udp"
	for sysfilter_proto in $sysfilter_proto; do
		fw add $mode $table $chain $target { $sysfilter_src_ip $sysfilter_dest_ip } { \
			$src_spec $dest_spec \
			${sysfilter_proto:+-p $sysfilter_proto} \
			${sysfilter_src_port:+--sport $sysfilter_src_port} \
			${sysfilter_src_mac:+-m mac --mac-source $sysfilter_src_mac} \
			${sysfilter_dest_port:+--dport $sysfilter_dest_port} \
			${sysfilter_icmp_type:+--icmp-type $sysfilter_icmp_type} \
		}
	done
}


fw_load_policy() {
	fw_config_get_section "$1" "$2" { \
		string policy deny \
		string state 0 \
	} || return
	#echo "policy=$2_policy, state=$2_state"
}

######## ip/port filter rule ##########

fw_config_get_ipport() {
	[ "${filter_NAME}" != "$1" ] || return
	fw_config_get_section "$1" filter { \
		string _name "$1" \
		string name "" \
		string iface "br-lan" \
		string dir "uplink" \
		ipaddr src_ipstart "" \
		ipaddr src_ipend "" \
		string src_port "" \
		ipaddr dest_ipstart "" \
		ipaddr dest_ipend "" \
		string dest_port "" \
		string proto "TCPUDP" \
		string family ipv4 \
	} || return
	[ -n "$filter_name" ] || filter_name=$filter__name
}

fw_load_ipport() {
	fw_config_get_ipport "$1"
	
	fw_get_port_range filter_src_port $filter_src_port
	fw_get_port_range filter_dest_port $filter_dest_port

	local table=f
	local chain="IP_PORT_FILTER"
	#local target="${filter_target:-REJECT}"				### if config no set, default is REJECT
	if [ "$2" == "deny" ]; then
		target=DROP
	else
		target=RETURN
	fi 
	
	local mode
	fw_get_family_mode mode ${filter_family:-x} I

	local src_spec dest_spec src_range dest_range iface
	#fw_get_negation src_spec '-s' "${filter_src_ip:+$filter_src_ip/$filter_src_ip_prefixlen}"
	#fw_get_negation dest_spec '-d' "${filter_dest_ip:+$filter_dest_ip/$filter_dest_ip_prefixlen}"
	
	fw_get_ip_range src_range $filter_src_ipstart $filter_src_ipend
	fw_get_ip_range dest_range $filter_dest_ipstart $filter_dest_ipend
	
	[ -n "$src_range" ] && src_spec="--src-range ${src_range}"
	[ -n "$dest_range" ] && dest_spec="--dst-range ${dest_range}"
	local has_ip=
	[ -n "$src_range" ] && has_ip=true || [ -n "$dest_spec" ] && has_ip=true

	#face=                  ## set to zero
        #fw_get_iface iface $filter_iface
        #[ -z "$iface" ] && {
        #        fw_log info "IP_PORT_FILTER interface not found, skip."
        #        return 0
        #}
		
	[ "$filter_proto" == "TCPUDP" ] && filter_proto="tcp udp"
	for filter_proto in $filter_proto; do
		if [ "$filter_dir" == "uplink" ]; then
			fw add $mode $table $chain $target { $filter_src_ip $filter_dest_ip } { \
				${has_ip:+-m iprange $src_spec $dest_spec} \
				${filter_iface:+-i $filter_iface} \
				${filter_proto:+-p $filter_proto} \
				${filter_src_port:+--sport $filter_src_port} \
				${filter_dest_port:+--dport $filter_dest_port} \
			}
		else ## downlink
			fw add $mode $table $chain $target { $filter_src_ip $filter_dest_ip } { \
				${has_ip:+-m iprange $src_spec $dest_spec} \
				${filter_iface:+-o $filter_iface} \
				${filter_proto:+-p $filter_proto} \
				${filter_src_port:+--sport $filter_src_port} \
				${filter_dest_port:+--dport $filter_dest_port} \
			}
		fi
	done

}

############## MAC filter rule ##################

fw_config_get_macfilter() {
	[ "${macfilter_NAME}" != "$1" ] || return
	fw_config_get_section "$1" macfilter { \
		string _name "$1" \
		string name "" \
		string src_mac "" \
		string family "ipv4" \
	} || return
	[ -n "$macfilter_name" ] || macfilter_name=$macfilter__name
}


fw_load_macfilter() {
	fw_config_get_macfilter "$1"
	
	local table=f
	local chain=MAC_FILTER
	local target="${macfilter_target:-REJECT}"				### if config no set, default is REJECT

	if [ "$2" == "deny" ]; then
		target=DROP
	else
		target=RETURN
	fi
	
	local mode
	fw_get_family_mode mode ${macfilter_family:-x} i			### dual ip
	#echo "--$mode"								### only all ipv4/ipv6 only now, need {empty sting}
	fw add $mode $table $chain $target { } { \
		${macfilter_src_mac:+-m mac --mac-source $macfilter_src_mac} \
	}
}

####### URL filter ##########
#FW_WEBFILTER_APPLIED=
#FW_WEBFILTER_POLICY=

fw_config_get_webfilter() {
	[ "${webfilter_NAME}" != "$1" ] || return
	fw_config_get_section "$1" webfilter { \
		string _name "$1" \
		string name "" \
		string host "" \
		string url ""\
	} || return
	[ -n "$webfilter_name" ] || webfilter_name=$webfilter__name
}

fw_load_url() {
	fw_config_get_webfilter $1
	
	local chain=WEB_FILTER
	local target

	if [ "$2" == "deny" ]; then
		target=DROP				### 
	else
		target=RETURN
	fi
		
	fw add i f $chain $target { -p tcp -m tcp -m webstr --url $webfilter_url } 	### url
	[ -n "$webfilter_host" ] && fw add i f $chain $target { -p tcp -m tcp -m webstr --host $webfilter_host }	### keyword
}

