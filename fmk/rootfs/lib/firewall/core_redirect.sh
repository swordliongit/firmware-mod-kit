# Copyright (C) 2009-2010 OpenWrt.org

fw_config_get_redirect() {
	[ "${redirect_NAME}" != "$1" ] || return
	fw_config_get_section "$1" redirect { \
		string _name "$1" \
		string name "" \
		string iface "" \
		ipaddr src_ip "" \
		string src_dport "" \
		ipaddr dest_ip "" \
		string dest_port "" \
		string proto "TCPUDP" \
		string family "ipv4" \
		string target "DNAT" \
		string state "0" \
	} || return
	[ -n "$redirect_name" ] || redirect_name=$redirect__name
}

fw_load_redirect() {
	fw_config_get_redirect "$1"

	[ $redirect_state != "0" ] ||{ ### 0 means disable
		fw_log info "Skip this disabled rule"
		return 0
	}
	
	local natchain natopt nataddr natports srcdaddr srcdports iface
	[ -n "$redirect_dest_ip$redirect_dest_port" ] || {
		fw_log error "Port Mapping ${redirect_name}: needs src_ip or src_port and dest_ip or dest_port, skipping"
		return 0
	}

	natopt="--to-destination"
	natchain="PORT_MAP"
	nataddr="$redirect_dest_ip"  ## internel server
	fw_get_port_range natports "$redirect_dest_port" "-" ## internel port

	fw_get_port_range srcdports "$redirect_src_dport" ":" ## externel port

	local mode
	fw_get_family_mode mode ${redirect_family:-x} I
	
	local srcaddr ## remote host
	fw_get_negation srcaddr '-s' "${redirect_src_ip:+$redirect_src_ip/$redirect_src_ip_prefixlen}"
	
	iface=			## set to zero
	fw_get_iface iface $redirect_iface 
	[ -z "$iface" ] && {
		fw_log info "PORT_MAP interface not found, skip."
		return 0
	}        

	[ "$redirect_proto" == "TCPUDP" ] && redirect_proto="tcp udp"
	for redirect_proto in $redirect_proto; do
		fw add $mode n $natchain $redirect_target { $redirect_src_ip $redirect_dest_ip } { \
			$srcaddr $srcdaddr \
			-i $iface \
			${redirect_proto:+-p $redirect_proto} \
			${srcdports:+--dport $srcdports} \
			$natopt $nataddr${natports:+:$natports} \
		}
	done
}

		
fw_config_get_dmz() {						## $1 will be dmz
	[ "${dmz_NAME}" != "$1" ] || return		## ${dmz_Name} will be set in fw_config_get_section dmz
	fw_config_get_section "$1" dmz { \
		string _name "$1" \
		string name "" \
		string iface "" \
		ipaddr dest_ip "" \
		string proto "TCPUDP" \
		string state 0 \
	} || return
	[ -n "$dmz_name" ] || dmz_name=$dmz__name
}

fw_load_dmz() {
	fw_config_get_dmz "$1"

	[ $dmz_state != "0" ] || { ## means disable
		fw_log info "Skip this disabled rule"
		return 0
	}

	local natopt nataddr natports iface
	[ -n "$dmz_dest_ip$" ] || {
		fw_log error "DNAT dmz ${dmz_name}: needs dest_ip or dest_port, skipping"
		return 0
	}
	
	natopt="--to-destination"						## or "--to" ???
	natchain="DMZ"
	nataddr="$dmz_dest_ip"
	iface=			## set to zero
	fw_get_iface iface $dmz_iface 
	[ -z "$iface" ] && {
		fw_log info "DMZ interface not found, skip."
		return 0
	}        

    httpport=$(uci get uhttpd.main.listen_http|awk -F: '{print $2}')
	[ "$dmz_proto" == "TCPUDP" ] && dmz_proto="tcp udp"
	for dmz_proto in $dmz_proto; do
		#fw add i n $natchain DNAT { -p $dmz_proto $natopt $nataddr }
		fw add i n $natchain DNAT { \
			-i $iface \
			${dmz_proto:+-p $dmz_proto} \
            -m multiport \
			! --dport $httpport,6424 \
			$natopt $nataddr \
		}
	done

}

