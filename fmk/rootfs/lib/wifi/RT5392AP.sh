#
append DRIVERS "RT5392AP"

scan_RT5392AP() {
    for vif in $VIFS; do
        config_get ifname "$vif" ifname
        config_set "$vif" ifname "${ifname:-$vif}"
    done
}

# Disable the device
disable_RT5392AP() {
    include /lib/network

    bssnum=$(ls /sys/class/net/ra* | wc -l)

    local idx=0
    while [ $idx -lt $bssnum ]
    do
        #echo "idx=$idx"
        ifconfig "ra$idx" down 2>/dev/null >/dev/null
        let idx++
    done

    true
}


# Enable the device (ifconfig $dev up), then
# configure the device, then set up the
# network (including adding the device to the bridge).
enable_RT5392AP() {
	local device=$DEVICES
    
	config_get ifname $DEVICES ifname
     
    local HT_GI=
    local HT_BW=
    config_get HT_BW "$device" HtBw	# 0:20MHz, 1:20/40MHz
    config_get HT_GI "$device" HtGi	# 1:400ns, 0:800ns
    
    local first=1
	local SSID1=
	local SSID2=
	local SSID3=
	local SSID4=
	local AuthMode=
	local EncrypType=
	local DefaultKeyID=
    local Key1Type= 
    local Key2Type= 
    local Key3Type= 
    local Key4Type=
	local WPAPSK1=
	local WPAPSK2=
	local WPAPSK3=
	local WPAPSK4=
    local HideSSID=
	local Channel=
	local NoForwarding=
	local WmmCapable=
	local AutoChannelSelect=
	local CountryCode=CN
	local CountryRegion=1
	local CountryRegionABand=4

    for vif in $VIFS; do

		config_get ssid "$vif" ssid
		case "$vif" in
			"ra0")
				SSID1="$ssid";;
			"ra1")
				SSID2="$ssid";;
			"ra2")
				SSID3="$ssid";;
			"ra3")
				SSID4="$ssid";;
		esac
	
		config_get securityMode "$vif" securityMode 	## NONE,WEP,WPAPSK,WPA2PSK,WPAPSKWPA2PSK
			case "$securityMode" in  
				"WEP")
					config_get wepMode "$vif" wepMode
					config_get keyLevel "$vif" keyLevel
					config_get key1 "$vif" key1
					config_get key2 "$vif" key2
					config_get key3 "$vif" key3
					config_get key4 "$vif" key4
					config_get keyIdx "$vif" keyIdx
					case "$vif" in
			    		"ra0")
							getValue DefaultKeyID "$keyIdx" "$DefaultKeyID" 1
							getValue AuthMode "$wepMode" "$AuthMode"  1
							getValue EncrypType "WEP" "$EncrypType" 1
							getValue Key1Type `find_keyType $keyLevel $key1` "$Key1Type" 1 
							getValue Key2Type `find_keyType $keyLevel $key2` "$Key2Type" 1 
							getValue Key3Type `find_keyType $keyLevel $key3` "$Key3Type" 1 	
							getValue Key4Type `find_keyType $keyLevel $key4` "$Key4Type" 1 
							;;
		    			"ra1"|"ra2"|"ra3")
							getValue AuthMode "$wepMode" "$AuthMode"
							getValue EncrypType "WEP" "$EncrypType"
							getValue DefaultKeyID "$keyIdx" "$DefaultKeyID"
							getValue Key1Type `find_keyType $keyLevel $key1` "$Key1Type" 
							getValue Key2Type `find_keyType $keyLevel $key2` "$Key2Type" 
							getValue Key3Type `find_keyType $keyLevel $key3` "$Key3Type" 	
							getValue Key4Type `find_keyType $keyLevel $key4` "$Key4Type" 	
							;;
					esac
					;;

				"NONE")
					case "$vif" in
						"ra0")
							getValue AuthMode "OPEN" "$AuthMode" 1 
							getValue EncrypType "NONE" "$EncrypType" 1 
							;;
						"ra1"|"ra2"|"ra3")
							getValue AuthMode "OPEN" "$AuthMode" 	
							getValue EncrypType "NONE" "$EncrypType"
							getValue DefaultKeyID " " "$DefaultKeyID" 
							;;
					esac					
					;;	
	
				"WPAPSK" | "WPA2PSK" | "WPAPSKWPA2PSK")
	 				config_get wpapsk "$vif" wpapsk
					case "$vif" in
						"ra0")
							WPAPSK1="$wpapsk";;
						"ra1")
							WPAPSK2="$wpapsk";;
						"ra2")
							WPAPSK3="$wpapsk";;	
						"ra3")
							WPAPSK4="$wpapsk";;	
					esac

					config_get wpaAlg "$vif" wpaAlg
			     	case "$vif" in
						"ra0")
							getValue AuthMode "$securityMode" "$AuthMode" 1 
							getValue EncrypType "$wpaAlg" "$EncrypType" 1 
							[ "$securityMode" = "WPAPSK" ] && getValue DefaultKeyID "2" "$DefaultKeyID" 1 
							;;
						"ra1"|"ra2"|"ra3")
							getValue AuthMode "$securityMode" "$AuthMode"
							getValue EncrypType "$wpaAlg" "$EncrypType"
							[ "$securityMode" = "WPAPSK" ] && getValue DefaultKeyID "2" "$DefaultKeyID" || getValue DefaultKeyID " " "$DefaultKeyID" 
							;;
					esac
					;;
			esac
	            
	  	config_get hidden "$vif" hidden
        case "$vif" in
            "ra0")
                getValue HideSSID "$hidden" "$HideSSID" 1 
                ;;
			"ra1"|"ra2"|"ra3")
                getValue HideSSID "$hidden" "$HideSSID" 
                ;;
        esac

	  	config_get wmm "$vif" wmm 
        case "$vif" in
            "ra0")
                getValue WmmCapable "$wmm" "$WmmCapable" 1 
                ;;
			"ra1"|"ra2"|"ra3")
                getValue WmmCapable "$wmm" "$WmmCapable" 
                ;;
        esac

	  	config_get isolate "$vif" apisolate
        case "$vif" in
            "ra0")
                getValue NoForwarding "$isolate" "$NoForwarding" 1 
                ;;
			"ra1"|"ra2"|"ra3")
                getValue NoForwarding "$isolate" "$NoForwarding"
                ;;
        esac

    done
    local DAT=/etc/Wireless/RT2860AP/RT2860AP.dat
    eval sed -i 's/^Key1Type=.*$/Key1Type="$Key1Type"/g' $DAT 	
    eval sed -i 's/^Key2Type=.*$/Key2Type="$Key2Type"/g' $DAT 	
    eval sed -i 's/^Key3Type=.*$/Key3Type="$Key3Type"/g' $DAT 	
    eval sed -i 's/^Key4Type=.*$/Key4Type="$Key4Type"/g' $DAT 	
    sed -i '/^SSID1=/d' $DAT && echo SSID1=${SSID1} >> $DAT
    sed -i '/^SSID2=/d' $DAT && echo SSID2=${SSID2} >> $DAT
    sed -i '/^SSID3=/d' $DAT && echo SSID3=${SSID3} >> $DAT
    sed -i '/^SSID4=/d' $DAT && echo SSID4=${SSID4} >> $DAT
    #eval sed -i 's/^SSID1=.*$/SSID1="$SSID1"/g' $DAT
	#eval sed -i 's/^SSID2=.*$/SSID2="$SSID2"/g' $DAT
    #eval sed -i 's/^SSID3=.*$/SSID3="$SSID3"/g' $DAT
    #eval sed -i 's/^SSID4=.*$/SSID4="$SSID4"/g' $DAT
    eval sed -i 's/^AuthMode=.*$/AuthMode="$AuthMode"/g' $DAT
    eval sed -i 's/^EncrypType=.*$/EncrypType="$EncrypType"/g' $DAT
 	eval sed -i 's/^DefaultKeyID=.*$/DefaultKeyID="$DefaultKeyID"/g' $DAT
    sed -i '/^WPAPSK1=/d' $DAT && echo WPAPSK1=${WPAPSK1} >> $DAT
    sed -i '/^WPAPSK2=/d' $DAT && echo WPAPSK2=${WPAPSK2} >> $DAT
    sed -i '/^WPAPSK3=/d' $DAT && echo WPAPSK3=${WPAPSK3} >> $DAT
    sed -i '/^WPAPSK4=/d' $DAT && echo WPAPSK4=${WPAPSK4} >> $DAT
    #eval sed -i 's/^WPAPSK1=.*$/WPAPSK1="$WPAPSK1"/g' $DAT
	#eval sed -i 's/^WPAPSK2=.*$/WPAPSK2="$WPAPSK2"/g' $DAT
    #eval sed -i 's/^WPAPSK3=.*$/WPAPSK3="$WPAPSK3"/g' $DAT
    #eval sed -i 's/^WPAPSK4=.*$/WPAPSK4="$WPAPSK4"/g' $DAT
    eval sed -i 's/^HT_BW=.*$/HT_BW="$HT_BW"/g' $DAT
	eval sed -i 's/^HT_GI=.*$/HT_GI="$HT_GI"/g' $DAT
	eval sed -i 's/^HideSSID=.*$/HideSSID="$HideSSID"/g' $DAT
	eval sed -i 's/^WmmCapable=.*$/WmmCapable="$WmmCapable"/g' $DAT
	eval sed -i 's/^NoForwarding=.*$/NoForwarding="$NoForwarding"/g' $DAT

	disable_RT5392AP
    ## igmp enable
    #iwpriv ra0 set IgmpSnEnable=1
    for	vif in $VIFS; do
		ifconfig $vif up
    done
    for vif in $VIFS; do
		
		# Apply any global radio config 
		[ "$first" = 1 ] && {
	    	config_get countryid "$device" countryid
			countryid2Code $countryid CountryCode CountryRegion CountryRegionABand
			echo "$countryid: $CountryCode,$CountryRegion,$CountryRegionABand"
			#iwpriv "$ifname" set CountryCode=$CountryCode
		    #iwpriv "$ifname" set CountryRegion=$CountryRegion 		
			#iwpriv "$ifname" set CountryRegionABand=$CountryRegionABand
			eval sed -i 's/^CountryCode=.*$/CountryCode=$CountryCode/g' $DAT
			eval sed -i 's/^CountryRegion=.*$/CountryRegion=$CountryRegion/g' $DAT
			eval sed -i 's/^CountryRegionABand=.*$/CountryRegionABand=$CountryRegionABand/g' $DAT
            iwpriv "$ifname" set HtDisallowTKIP=0	# n rate	
            config_get hwmode "$device" hwmode
            iwpriv "$ifname" set WirelessMode=$(find_hwmode $hwmode)
	    
	    	config_get channel "$device" channel
			eval sed -i 's/^Channel=.*$/Channel=$channel/g' $DAT
		    if [ "$channel" != 0  ]; then
	    		iwpriv "$ifname" set Channel=$channel
				eval sed -i 's/^AutoChannelSelect=.*$/AutoChannelSelect=0/g' $DAT
			else
				eval sed -i 's/^AutoChannelSelect=.*$/AutoChannelSelect=2/g' $DAT
	    	fi
	    
	    	#config_get abgn_rate "$device" abgn_rate

	    	#0,1,4,6,9
	  	case "$(find_hwmode $hwmode)" in
	    	4|7) iwpriv "$ifname" set BasicRate=351 ;;
	   		1) iwpriv "$ifname" set BasicRate=3 ;;
	   		*) iwpriv "$ifname" set BasicRate=15 ;;
	   	esac
	    
		config_get abgn_rate "$device" abgn_rate

	    	case "$(find_hwmode $hwmode)" in
	    		0|2|4)
		    		case "$abgn_rate" in
		    			1|2|5|11) iwpriv "$ifname" set FixedTxMode=1 		##CCK
		    				;;
		    			*) iwpriv "$ifname" set FixedTxMode=2		##OFDM
		    				;; 
		    		esac
		    					
		    		case "$abgn_rate" in
		    			1)	iwpriv "$ifname" set HtMcs=0 ;;	
		    			2)	iwpriv "$ifname" set HtMcs=1 ;;	
		    			5)	iwpriv "$ifname" set HtMcs=2 ;;	
		    			6)	iwpriv "$ifname" set HtMcs=0 ;;	
		    			9)	iwpriv "$ifname" set HtMcs=1 ;;	
		    			11)	iwpriv "$ifname" set HtMcs=3 ;;	
		    			12)	iwpriv "$ifname" set HtMcs=2 ;;	
		    			18)	iwpriv "$ifname" set HtMcs=3 ;;	
		    			24)	iwpriv "$ifname" set HtMcs=4 ;;	
		    			36)	iwpriv "$ifname" set HtMcs=5 ;;	
		    			48)	iwpriv "$ifname" set HtMcs=6 ;;	
		    			54)	iwpriv "$ifname" set HtMcs=7 ;;	
		    			0)	iwpriv "$ifname" set HtMcs=33 ;;		
		    		esac
	    			;;
	    		1)	
	    			iwpriv "$ifname" set FixedTxMode=1		##CCK
	    			case "$abgn_rate" in
	    				1)	iwpriv "$ifname" set HtMcs=0 ;;
	    				2)	iwpriv "$ifname" set HtMcs=1 ;;
	    				5)	iwpriv "$ifname" set HtMcs=2 ;;
	    				11)	iwpriv "$ifname" set HtMcs=3 ;;
	    				0) iwpriv "$ifname" set HtMcs=33 ;;	## need to be checked
	    			esac	    		
	    			;;
	    		6|9)
					iwpriv "$ifname" set FixedTxMode=0		##HT
					if [ "$HT_GI" = 0 ]; then
						case "$abgn_rate" in
		    				13|27)	iwpriv "$ifname" set HtMcs=8 ;;
			    			26|54)	iwpriv "$ifname" set HtMcs=9 ;;
		    				39|81)	iwpriv "$ifname" set HtMcs=10 ;;
		    				52|108)	iwpriv "$ifname" set HtMcs=11 ;;
		    				78|162)	iwpriv "$ifname" set HtMcs=12 ;;
		    				104|216)iwpriv "$ifname" set HtMcs=13 ;;
		    				117|243)iwpriv "$ifname" set HtMcs=14 ;;
		    				130|270)iwpriv "$ifname" set HtMcs=15 ;;
		    				0)iwpriv "$ifname" set HtMcs=33 ;;
		    			    esac
					else
					    case "$abgn_rate" in
		    				14|30)	iwpriv "$ifname" set HtMcs=8 ;;
			    			29|60)	iwpriv "$ifname" set HtMcs=9 ;;
		    				43|90)	iwpriv "$ifname" set HtMcs=10 ;;
		    				58|120)	iwpriv "$ifname" set HtMcs=11 ;;
		    				87|180)	iwpriv "$ifname" set HtMcs=12 ;;
		    				116|240)iwpriv "$ifname" set HtMcs=13 ;;
		    				130|270)iwpriv "$ifname" set HtMcs=14 ;;
		    				144|300)iwpriv "$ifname" set HtMcs=15 ;;
		    				0)iwpriv "$ifname" set HtMcs=33 ;;
		    			    esac
					fi
	    			;;	
	    	esac
	    	
			config_get radio "$device" radio # 0,1 #ҳ�治��ʾ
			[ -n "$radio" ] && {
				iwpriv "$ifname" set RadioOn=$radio
			}
			
			config_get txpower "$device" txpower
	  		iwpriv "$ifname" set TxPower=$(find_txpower $txpower)
	    }
		
		config_get ifname "$vif" ifname
		# Apply the configuration
		config_get MaxStaNum "$vif" MaxStaNum 32
		iwpriv "$vif" set MaxStaNum=$MaxStaNum 
		config_get ssid "$vif" ssid
		config_get securityMode "$vif" securityMode 	## NONE,WEP,WPAPSK,WPA2PSK,WPAPSKWPA2PSK
  
  		case "$securityMode" in
	    	"WEP")
		    	config_get wepMode "$vif" wepMode					## OPEN,SHARED,WEPAUTO(means open+shared)
		    	config_get keyIdx "$vif" keyIdx
		    	config_get key1 "$vif" key1
		    	config_get key2 "$vif" key2
		    	config_get key3 "$vif" key3
		    	config_get key4 "$vif" key4
		    	iwpriv "$ifname" set AuthMode=$wepMode
		    	iwpriv "$ifname" set EncrypType=WEP
		        iwpriv "$ifname" set IEEE8021X=0
				iwpriv "$ifname" set DefaultKeyID=$keyIdx
				[ -n "$key1" ] && iwpriv "$ifname" set Key1=$key1
		    	[ -n "$key2" ] && iwpriv "$ifname" set Key2=$key2
		    	[ -n "$key3" ] && iwpriv "$ifname" set Key3=$key3
		    	[ -n "$key4" ] && iwpriv "$ifname" set Key4=$key4
		        iwpriv "$ifname" set IEEE8021X=0
	 	        iwpriv "$ifname" set SSID=$ssid
	      		;;
	    esac
        	
	  	#config_get hidden "$vif" hidden
	  	#iwpriv "$ifname" set HideSSID=$hidden
	  	config_get enabled "$vif" enabled
	  	if [ "$enabled" = 0 ]; then
	  		ifconfig "$vif" down
	  		#unbridge "$vif"
	  	else
	  		ifconfig "$vif" up
	  		#brctl addif br-lan "$vif"
			config_get WPSEnable "$vif" WPSEnable
			[ "$WPSEnable" = 1 ] && {
				iwpriv ra0 set WscConfMode=4
				iwpriv ra0 set WscConfStatus=2
			}
			if false; then
			config_get WPSEnable "$vif" WPSEnable
			case "$securityMode" in
				WPAPSK|WPA2PSK|WPAPSKWPA2PSK) ### WPS only work in ra0
					[ "$WPSEnable" = 1 ] && [ "$first" = 1 ] && {
						#echo "wps enable"
						config_get wscMode "$vif" wscMode
						config_get pinCode "$vif" pinCode
						#/lib/wifi/dowps $vif $wscMode $pinCode 1>/tmp/wps_status &
						iwpriv ra0 set WscConfMode=7
						iwpriv ra0 set WscConfStatus=2
						if [ "$wscMode" = "PBC" ]; then
							iwpriv ra0 set WscMode=2
						else
							iwpriv ra0 set WscMode=1
							iwpriv ra0 set WscPinCode=$pinCode
						fi
						iwpriv ra0 set WscGetConf=1
					}
				;;
			esac
			fi	

	  	fi
		first=0
    done
}

# Helper functions
#
find_hwmode() {
    local str="$1"
    local i=0
    # default to 11bgn
    local num=9
    for mode in 11bg 11b 11a x 11g x 11n 11gn 11an 11bgn 11agn 11n5g; do
	if [ "$mode" = "$str" ]; then
	    num=$i
	fi
	i=$((${i:-0} + 1))
    done
    echo $num
}
find_txpower() {
    local str="$1"
    local txpower
    case "$str" in
    	"1") txpower=100;;
    	"2") txpower=75;;
    	"3") txpower=50;;
    	"4") txpower=25;;
    	"5") txpower=15;;
    	"6") txpower=10;;
    	"7") txpower=5;;
    	*) txpower=100;;
    esac
    echo $txpower	
}
find_keyType() {
	local lvl="$1"
	local keystr="$2"
	local type=0
	local len=`expr length $keystr`
	case "$keyLevel" in
	    "40")
		if [ "$len" = 10 ]; then
			type=0
		else
			type=1
		fi
		;;
	    "104")
		if [ "$len" = 26 ]; then
			type=0
		else
			type=1
		fi
		;;
	esac
	echo $type
}
getValue() {
    local _var="$1"
    local _val="$2"
    local _orig="$3"
    local _flag="$4"

    if [ -z "$_orig" ]; then
        export -n -- "$_var=$_val"
    else 
        if [ "$_flag" == 1 ]; then 
            export -n -- "$_var=$_val;$_orig"
        else
            export -n -- "$_var=$_orig;$_val"
        fi
    fi
}

countryid2Code() {
	local _id="$1"
	local _code="$2"
	local _region="$3"
	local _aRegion="$4"

	case "$_id" in
		32)
			export -n -- "$_code=AR"
			export -n -- "$_region=1"
			export -n -- "$_aRegion=3"
			;;
		156)
			export -n -- "$_code=CN"
			export -n -- "$_region=1"
			export -n -- "$_aRegion=4"
			;;
		344)
			export -n -- "$_code=HK"
			export -n -- "$_region=1"
			export -n -- "$_aRegion=0"
			;;
		360)
			export -n -- "$_code=ID"
			export -n -- "$_region=1"
			export -n -- "$_aRegion=4"
			;;
		356)
			export -n -- "$_code=IN"
			export -n -- "$_region=0" 
			export -n -- "$_aRegion=0"
			;;
		158)
			export -n -- "$_code=TW"
			export -n -- "$_region=0"
			export -n -- "$_aRegion=3"
			;;
		764)
			export -n -- "$_code=TH"
			export -n -- "$_region=1"
			export -n -- "$_aRegion=0"
			;;
		458)
			export -n -- "$_code=MY"
			export -n -- "$_region=1"
			export -n -- "$_aRegion=0"
			;;
		586)
			export -n -- "$_code=PK"
			export -n -- "$_region=1"
			export -n -- "$_aRegion=0"
			;;
		608)
			export -n -- "$_code=PH"
			export -n -- "$_region=1"
			export -n -- "$_aRegion=4"
			;;
		702)
			export -n -- "$_code=SG"
			export -n -- "$_region=1"
			export -n -- "$_aRegion=0"
			;;
		724)
			export -n -- "$_code=sp"
			export -n -- "$_region=1"
			export -n -- "$_aRegion=1"
			;;
		841|840)
			export -n -- "$_code=US"
			export -n -- "$_region=0"
			export -n -- "$_aRegion=0"
			;;
		704)
			export -n -- "$_code=VN"
			#export -n -- "$_region=1"
			export -n -- "$_region=0" # VN G Region had changed from 1 to 0
			export -n -- "$_aRegion=0"
			;;
	esac
}
