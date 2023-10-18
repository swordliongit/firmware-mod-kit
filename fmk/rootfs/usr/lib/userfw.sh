#!/bin/sh

[ -e /etc/functions.sh ] && . /etc/functions.sh || . ./functions.sh

PROTOBANNEDLIST=
iptrules=

config_cb() {
	option_cb() {
		return 0
	}

	# Section start
	case "$1" in
		protoBanned)
			option_cb() {
				[ "$2" = "1" ] && append PROTOBANNEDLIST "$1"
			}
		;;
	esac

    # Section end
	config_get TYPE "$CONFIG_SECTION" TYPE
	case "$TYPE" in
		protoBanned)
			parse_banned_rules
		;;
	esac
}

parse_banned_rules() {
#local ports=
	for proto in $PROTOBANNEDLIST; do
		case $proto in
			ftp)
				append iptrules "iptables -A user_Default -p tcp --dport 21 -j REJECT --reject-with port-unreach" "$N"
				;;
			ssh)
				append iptrules "iptables -A user_Default -p tcp --dport 22 -j REJECT --reject-with port-unreach" "$N"
				;;
			telnet)
				append iptrules "iptables -A user_Default -p tcp --dport 23 -j REJECT --reject-with port-unreach"  "$N"
				;;
			icmp_wan)
				append iptrules "iptables -A user_Default ! -i br-lan -p icmp --icmp-type echo-request  -j REJECT --reject-with port-unreach"  "$N"
				;;
			http_wan) 
				append iptrules "iptables -A user_Default ! -i br-lan -p tcp --dport 80 -j REJECT --reject-with port-unreach" "$N"
				;;
			ssh_wan) 
				append iptrules "iptables -A user_Default ! -i br-lan -p tcp --dport 22 -j REJECT --reject-with port-unreach" "$N"
				;;
			telnet_wan) 
				append iptrules "iptables -A user_Default ! -i br-lan -p tcp --dport 23 -j REJECT --reject-with port-unreach" "$N"
				;;
			http_wifi) # awifi
				append iptrules "iptables -A user_Default -m physdev --physdev-in ra0 \
				-p tcp --dport 80 -j REJECT --reject-with port-unreach" "$N"
				;;
			wan_access) 
				append iptrules "iptables -A user_Default ! -i br-lan -p tcp -m multiport --dports 22,23,80 -j REJECT --reject-with port-unreach" "$N"
				append iptrules "iptables -A user_Default ! -i br-lan -p icmp --icmp-type echo-request -j REJECT --reject-with port-unreach" "$N"
				;;
		esac
	done
}

start_userfw() {
cat << EOF	
iptables -N user_Default
iptables -I INPUT 3 -j user_Default
${iptrules}
EOF
}

### from generate.sh
stop_userfw() {
	# Builds up a list of iptables commands to flush the user_* chains,
	# remove rules referring to them, then delete them

	# Print rules in the mangle table, like iptables-save
#	iptables -t filter -S |
		# Find rules for the user_* chains
#		grep '^-N user_\|-j user_' |
		# Exclude rules in user_* chains (inter-user_* refs)
#		grep -v '^-A user_' |
		# Replace -N with -X and hold, with -F and print
		# Replace -A with -D
		# Print held lines at the end (note leading newline)
#		sed -e '/^-N/{s/^-N/-X/;H;s/^-X/-F/}' \
#			-e 's/^-A/-D/' \
#			-e '${p;g}' |
		# Make into proper iptables calls
		# Note:  awkward in previous call due to hold space usage
#		sed -n -e 's/^./iptables &/p'
cat << EOF
iptables -F user_Default
iptables -D INPUT -j user_Default
iptables -X user_Default
EOF
}

config_load userfw

case "$1" in
	start)
	start_userfw
	;;
	stop)
	stop_userfw
	;;
esac
