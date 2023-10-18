FW_DDOS_APPLIED=
fw_ddos_init() {
	fw add i f DDOS_INPUT
	fw add i f DDOS_FW
	fw add i f port_scan
	fw add i f synflood
	fw add i f ping_of_death
	fw add i f winnuke
	fw add i f smurf
	fw add i f icmp_redirect
	
	fw add i f DDOS_FW port_scan
	fw add i f DDOS_INPUT port_scan
	fw add i f DDOS_INPUT synflood { -p tcp --syn }
	fw add i f DDOS_INPUT ping_of_death
	fw add i f DDOS_FW ping_of_death
	fw add i f DDOS_INPUT winnuke
	fw add i f DDOS_FW winnuke
	fw add i f DDOS_FW smurf { -p icmp --icmp-type echo-request }
	fw add i f DDOS_INPUT smurf { -p icmp --icmp-type echo-request }
	fw add i f DDOS_FW icmp_redirect
	fw add i f DDOS_INPUT icmp_redirect
	
	fw add i f INPUT DDOS_INPUT
	fw add i f FORWARD DDOS_FW
}

fw_ddos_fini() {
	fw flush i f port_scan
	fw flush i f synflood
	fw flush i f ping_of_death
	fw flush i f winnuke
	fw flush i f smurf 
	fw flush i f icmp_redirect
}

fw_load_ddos() {
	fw_config_get_section "$1" ddos { \
		boolean synflood_protect 0 \
		string synflood_rate 25 \
		string synflood_burst 50 \
		boolean port_scan 0 \
		boolean ping_of_death 0 \
		boolean winnuke 0 \
		boolean smurf 0 \
		boolean icmp_redirect 0 \
		boolean ping_sweep 0 \
		boolean teardrop 0 \
	} || return
	[ -n "$FW_DDOS_APPLIED" ] && {
	        fw_log error "duplicate ddos section detected, skipping"
		return 1
	}
	
	FW_DDOS_APPLIED=1
	
	[ $ddos_port_scan == 1 ] && {
		fw add i f port_scan DROP { -p tcp --tcp-flags ALL FIN,URG,PSH }			### NMAP-XMAS
		fw add i f port_scan DROP { -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG }		### NMAP-PSH
		fw add i f port_scan DROP { -p tcp --tcp-flags ALL NONE }  				### NULL SCAN
		fw add i f port_scan DROP { -p tcp --tcp-flags SYN,RST SYN,RST } 			### SYN/RST
		fw add i f port_scan DROP { -p tcp --tcp-flags SYN,FIN SYN,FIN }			### SYN/FIN
	}
	
	[ "${ddos_synflood_rate%/*}" == "$ddos_synflood_rate" ] && \
		ddos_synflood_rate="$ddos_synflood_rate/second"
	
	[ $ddos_synflood_protect == 1 ] && { 
		fw add i f synflood RETURN { \
			-p tcp --syn \
			-m limit --limit "${ddos_synflood_rate}" --limit-burst "${ddos_synflood_burst}" \
		}
		fw add i f synflood DROP
	}
 	
	[ $ddos_ping_of_death == 1 ] && {
		#echo "Loading ping-of-death protection"
		fw add i f ping_of_death DROP { -p icmp -m length --length 65535 }
		#fw add G4 f ping_of_death DROP { -p icmp -f }							### ipv4 drop icmp fragment pkts
		iptables -A ping_of_death -j DROP -p icmp -f 
	}
	
	[ $ddos_winnuke == 1 ] && {
		#echo "Loading winnuke protection"
		fw add i f winnuke DROP { -p tcp --tcp-flags URG URG -m multiport --dports 133,135,137:139 }
	}

	[ $ddos_smurf == 1 ] && {
		fw add i f smurf RETURN { -m limit --limit 150/s --limit-burst 300 }
		fw add i f smurf DROP
	}
	
	[ $ddos_icmp_redirect == 1 ] && {
		fw add i f icmp_redirect DROP { -p icmp --icmp-type redirect }
	}
	
	#[ $ddoc_ping_sweep == 1 ] && {
	#	fw add i f DDOS_FW -j DROP { -p -icmp }
	#}
}
