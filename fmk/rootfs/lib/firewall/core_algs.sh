FW_ALGS_APPLIED=
fw_algs_init() {
	fw add i f INPUT_ALGS
	fw add i f OUTPUT_ALGS
	fw add i f FW_ALGS
	fw add i n NAT_ALGS

	fw add i f INPUT INPUT_ALGS
	fw add i f OUTPUT OUTPUT_ALGS
	fw add i f FORWARD FW_ALGS
	fw add i n POSTROUTING NAT_ALGS 
}

fw_algs_fini() {
	fw flush i f INPUT_ALGS
	fw flush i f OUTPUT_ALGS
	fw flush i f FW_ALGS
	fw flush i n NAT_ALGS
}

MODULES_DIR=/lib/modules/$(uname -r)
fw_load_algs() {
	fw_config_get_section "$1" algs { \
		boolean H323En 0 \
		boolean SIPEn 0 \
		boolean RTSPEn 0 \
		boolean L2TPEn 0 \
		boolean IPSecEn 0 \
		boolean FTPEn 0 \
	} || return
	[ -n "$FW_ALGS_APPLIED" ] && {
	        fw_log error "duplicate algs section detected, skipping"
		return 1
	}
	
	FW_ALGS_APPLIED=1

	if [ $algs_H323En == 1 ]; then 
		insmod -q $MODULES_DIR/nf_conntrack_h323.ko		
		insmod -q $MODULES_DIR/nf_nat_h323.ko		
		fw add i f FW_ALGS ACCEPT { -p tcp -m multiport --dports 1720,1731,1503,389,522 }
		fw add i f FW_ALGS ACCEPT { -p tcp -m multiport --sports 1720,1731,1503,389,522 }
		fw add i n NAT_ALGS ACCEPT { -p tcp -m multiport --sports 1720,1731,1503,389,522 }
	else
		rmmod nf_nat_h323.ko
		rmmod nf_conntrack_h323.ko
		fw add i f FW_ALGS DROP { -p tcp -m multiport --dports 1720,1731,1503,389,522 }
		fw add i f FW_ALGS DROP { -p tcp -m multiport --sports 1720,1731,1503,389,522 }
		fw add i n NAT_ALGS DROP { -p tcp -m multiport --sports 1720,1731,1503,389,522 }
	fi

	#if false; then
	if [ $algs_SIPEn == 1 ]; then
		insmod -q $MODULES_DIR/nf_conntrack_sip.ko
		insmod -q $MODULES_DIR/nf_nat_sip.ko		
		fw add i f FW_ALGS ACCEPT { -p udp -m multiport --sports 5060 }
		fw add i n NAT_ALGS ACCEPT { -p udp -m multiport --sports 5060 }
		fw add i f FW_ALGS ACCEPT { -p udp -m multiport --dports 5060 }
		fw add i n NAT_ALGS ACCEPT { -p udp -m multiport --dports 5060 }
	else
		rmmod nf_nat_sip.ko
		rmmod nf_conntrack_sip.ko
		#fw add i f FW_ALGS DROP { -p udp -m multiport --sports 5060 }
		#fw add i n NAT_ALGS DROP { -p udp -m multiport --sports 5060 }
		#fw add i f FW_ALGS DROP { -p udp -m multiport --dports 5060 }
		#fw add i n NAT_ALGS DROP { -p udp -m multiport --dports 5060 }
	fi
	#fi

	if [ $algs_RTSPEn == 1 ]; then 
		insmod -q $MODULES_DIR/nf_conntrack_rtsp.ko
		insmod -q $MODULES_DIR/nf_nat_rtsp.ko
		fw add i f FW_ALGS ACCEPT { -p tcp -m multiport --dports 554 }
		fw add i f FW_ALGS ACCEPT { -p tcp -m multiport --sports 554 }
		fw add i n NAT_ALGS ACCEPT { -p tcp -m multiport --dports 554 }
		fw add i n NAT_ALGS ACCEPT { -p udp --sport 6970:6980 }
	else
		rmmod nf_nat_rtsp.ko
		rmmod nf_conntrack_rtsp.ko
		fw add i f FW_ALGS DROP { -p tcp -m multiport --dports 554 }
		fw add i f FW_ALGS DROP { -p tcp -m multiport --sports 554 }
		fw add i n NAT_ALGS DROP { -p tcp -m multiport --dports 554 }
		fw add i n NAT_ALGS DROP { -p udp --sport 6970:6980 }
	fi

	if [ $algs_L2TPEn == 1 ]; then
		fw add i f FW_ALGS ACCEPT { -p udp -m multiport --dports 1701 }
		fw add i f FW_ALGS ACCEPT { -p udp -m multiport --sports 1701 }
		fw add i n NAT_ALGS ACCEPT { -p udp -m multiport --sports 1701 }
   		fw add i n NAT_ALGS ACCEPT { -p udp -m multiport --dports 1701 }
	else
		fw add i f FW_ALGS DROP { -p udp -m multiport --dports 1701 }
		fw add i f FW_ALGS DROP { -p udp -m multiport --sports 1701 }
		fw add i n NAT_ALGS DROP { -p udp -m multiport --sports 1701 }
   		fw add i n NAT_ALGS DROP { -p udp -m multiport --dports 1701 }
	fi

	if [ $algs_IPSecEn == 1 ]; then 
   		fw add i n NAT_ALGS ACCEPT { -p udp --dport 500 --sport 500 } 			
   		fw add i f FW_ALGS ACCEPT { -p udp --dport 500 --sport 500 }
   		fw add i n NAT_ALGS ACCEPT { -p udp --dport 4500 --sport 4500 } 		
   		fw add i f FW_ALGS ACCEPT { -p udp --dport 4500 --sport 4500 }
   		fw add i n NAT_ALGS ACCEPT { -p 50 }								
   		fw add i f FW_ALGS ACCEPT { -p 50 }
   		fw add i n NAT_ALGS ACCEPT { -p 51 }								
		fw add i f FW_ALGS ACCEPT { -p 51 }				
	else	
   		fw add i n NAT_ALGS DROP { -p udp --dport 500 --sport 500 } 			
   		fw add i f FW_ALGS DROP { -p udp --dport 500 --sport 500 }
   		fw add i n NAT_ALGS DROP { -p udp --dport 4500 --sport 4500 } 		
   		fw add i f FW_ALGS DROP { -p udp --dport 4500 --sport 4500 }
   		fw add i n NAT_ALGS DROP { -p 50 }								
   		fw add i f FW_ALGS DROP { -p 50 }
   		fw add i n NAT_ALGS DROP { -p 51 }								
		fw add i f FW_ALGS DROP { -p 51 }				
	fi

	if [ $algs_FTPEn == 1 ]; then
		insmod -q $MODULES_DIR/nf_conntrack_ftp.ko
		insmod -q $MODULES_DIR/nf_nat_ftp.ko
		fw add i f INPUT_ALGS  ACCEPT { -p tcp -m multiport --dports 21 }
		fw add i f OUTPUT_ALGS  ACCEPT { -p tcp -m multiport --sports 21 }
		fw add i f FW_ALGS  ACCEPT { -p tcp -m multiport --dports 21 }
		fw add i f FW_ALGS  ACCEPT { -p tcp -m multiport --sports 21 }
		fw add i n NAT_ALGS  ACCEPT { -p tcp -m multiport --sports 21 }
		fw add i n NAT_ALGS  ACCEPT { -p tcp -m multiport --dports 21 }
	else
		rmmod nf_nat_ftp.ko
		rmmod nf_conntrack_ftp.ko
		fw add i f INPUT_ALGS  DROP { -p tcp -m multiport --dports 21 }
		fw add i f OUTPUT_ALGS  DROP { -p tcp -m multiport --sports 21 }
		fw add i f FW_ALGS  DROP { -p tcp -m multiport --dports 21 }
		fw add i f FW_ALGS  DROP { -p tcp -m multiport --sports 21 }
		fw add i n NAT_ALGS  DROP { -p tcp -m multiport --sports 21 }
		fw add i n NAT_ALGS  DROP { -p tcp -m multiport --dports 21 }
	fi

		## pptp alg
   	#fw add i f FW_ALGS ACCEPT { -p tcp -m multiport --dports 1723  }
   	#fw add i f FW_ALGS ACCEPT { -p tcp -m multiport --sports 1723 -m state --state ESTABLISHED,RELATED  }
   	#fw add i n NAT_ALGS ACCEPT { -p tcp -m multiport --sports 1723 }
   	#fw add i n NAT_ALGS ACCEPT { -p tcp -m multiport --dports 1723 }
   	#fw add i f FW_ALGS ACCEPT { -p 47 -m state --state ESTABLISHED,RELATED } 	
}
