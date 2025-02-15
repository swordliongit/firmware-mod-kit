# Copyright (C) 2009-2010 OpenWrt.org
# Copyright (C) 2009 Malte S. Stretz

export FW_4_ERROR=0
export FW_6_ERROR=0
export FW_i_ERROR=0
export FW_e_ERROR=0
export FW_a_ERROR=0

#TODO: remove this
[ "${-#*x}" == "$-" ] && {
	fw() {
		fw__exec "$@"
	}
} || {
	fw() {
		local os=$-
		set +x
		fw__exec "$@"
		local rc=$?
		set -$os
		return $rc
	}
}

fw__exec() { # <action> <family> <table> <chain> <target> <position> { <rules> }
	local cmd fam tab chn tgt pos
	local i
	for i in cmd fam tab chn tgt pos; do
		if [ "$1" -a "$1" != '{' ]; then
			eval "$i='$1'"
			shift
		else
			eval "$i=-"
		fi
	done

	fw__rc() {
		export FW_${fam#G}_ERROR=$1
		return $1
	}

	fw__dualip() {
		fw $cmd 4 $tab $chn $tgt $pos "$@"
		fw $cmd 6 $tab $chn $tgt $pos "$@"
		fw__rc $((FW_4_ERROR | FW_6_ERROR))
	}

	fw__autoip() {
		local ip4 ip6
		shift
		while [ "$1" != '}' ]; do
			case "$1" in
				*:*) ip6=1 ;;
				*.*.*.*) ip4=1 ;;
			esac
			shift
		done
		shift
		if [ "${ip4:-4}" == "${ip6:-6}" ]; then
			echo "fw: can't mix ip4 and ip6" >&2
 			return 1
		fi
		local ver=${ip4:+4}${ip6:+6}
		fam=i
		fw $cmd ${ver:-i} $tab $chn $tgt $pos "$@"
		fw__rc $?
	}

	fw__has() {
		local tab=${1:-$tab}
		if [ $tab == '-' ]; then
			type $app > /dev/null 2> /dev/null
			fw__rc $(($? & 1))
			return
		fi
		local mod
		eval "mod=\$FW_${fam#G}_${tab}"
		if [ "$mod" ]; then
			fw__rc $mod
			return
		fi
		case "$fam" in
			*4) mod=iptable_${tab} ;;
			*6) mod=ip6table_${tab} ;;
			*) mod=. ;;
		esac
		grep -q "^${mod} " /proc/modules
		mod=$?
		export FW_${fam}_${tab}=$mod
		fw__rc $mod
	}

	fw__err() {
		local err
		eval "err=\$FW_${fam}_ERROR"
		fw__rc $err
	}

	local app=
	local pol=
	case "$fam" in
		*4) [ $FW_DISABLE_IPV4 == 0 ] && app=iptables  || return ;;
		*6) [ $FW_DISABLE_IPV6 == 0 ] && app=ip6tables || return ;;
		i) fw__dualip "$@"; return ;;
		I) fw__autoip "$@"; return ;;
		e) app=ebtables ;;
		a) app=arptables ;;
		-) fw $cmd i $tab $chn $tgt $pos "$@"; return ;;
		*) return 254 ;;
	esac
	case "$tab" in
		f) tab=filter ;;
		m) tab=mangle ;;
		n) tab=nat ;;
		r) tab=raw ;;
		-) tab=filter ;;
	esac
	case "$cmd:$chn:$tgt:$pos" in
		add:*:-:*) cmd=new-chain ;;
		add:*:*:-) cmd=append ;;
		add:*:*:$) cmd=append ;;
		add:*:*:*) cmd=insert ;;
		del:-:*:*) cmd=delete-chain; fw flush $fam $tab ;;
		del:*:-:*) cmd=delete-chain; fw flush $fam $tab $chn ;;
		del:*:*:*) cmd=delete ;;
		flush:*) ;;
		policy:*) pol=$tgt; tgt=- ;;
		has:*) fw__has; return ;;
		err:*) fw__err; return ;;
		list:*) cmd="numeric --verbose --$cmd" ;;
		*) return 254 ;;
	esac
	case "$chn" in
		-) chn= ;;
	esac
	case "$tgt" in
		-) tgt= ;;
	esac
	case "$pos" in
		^) pos=1 ;;
		$) pos= ;;
		-) pos= ;;
	esac
	
	# john del
	#if ! fw__has - family || ! fw__has $tab ; then
	#	export FW_${fam}_ERROR=0
	#	return 0
	#fi

	case "$fam" in
		G*) shift; while [ $# -gt 0 ] && [ "$1" != "{" ]; do shift; done ;;
	esac

	if [ $# -gt 0 ]; then
		shift
		if [ $cmd == delete ]; then
			pos=
		fi
	fi

	local cmdline="$app --table ${tab} --${cmd} ${chn} ${pol} ${pos} ${tgt:+--jump "$tgt"}"
	while [ $# -gt 1 ]; do
		case "$app:$1" in
			ip6tables:--icmp-type) cmdline="$cmdline --icmpv6-type" ;;
			ip6tables:icmp|ip6tables:ICMP) cmdline="$cmdline icmpv6" ;;
			iptables:--icmpv6-type) cmdline="$cmdline --icmp-type" ;;
			iptables:icmpv6) cmdline="$cmdline icmp" ;;
			*) cmdline="$cmdline $1" ;;
		esac
		shift
	done

	[ -n "$FW_TRACE" ] && echo $cmdline >&2

	$cmdline

	fw__rc $?
}

fw_get_port_range() {
	local _var=$1
	local _ports=$2
	local _delim=${3:-:}
	if [ "$4" ]; then
		fw_get_port_range $_var "${_ports}-${4}" $_delim
		return
	fi

	local _first=${_ports%-*}
	local _last=${_ports#*-}
	if [ "$_first" != "$_last" ]; then
		export -- "$_var=$_first$_delim$_last"
	else
		export -- "$_var=$_first"
	fi
}

fw_get_ip_range() {
	local _var=$1
	local _start=$2
	local _end=$3
	
	if [ -n "$_start" ]; then
		if [ -n "$_end" ]; then
			export -- "$_var=$_start-$_end"
		else
			export -- "$_var=$_start"
		fi
	else
		export -- "$_var="	
	fi
}

fw_get_family_mode() {
        local _var="$1"
        local _hint="$2"
        local _mode="$3"

        case "$_hint" in
                *4) export -n -- "$_var=G4" ;;          ## mode=G4, then ${mode#G}=4
                *6) export -n -- "$_var=G6" ;;
                *) export -n -- "$_var=$_mode" ;;                       ## mode=I or i
        esac
}

fw_get_negation() {
	local _var="$1"
	local _flag="$2"
	local _ipaddr="$3"

	[ "${_ipaddr#!}" != "$_ipaddr" ] && \
		export -n -- "$_var=! $_flag ${_ipaddr#!}" || \
		export -n -- "$_var=${_ipaddr:+$_flag $_ipaddr}"
}

fw_get_iface() {
	local _var="$1"
	local _iface="$2"
	[ -d /tmp/run/netconfig/$_iface ] && \
		export -n -- "$_var=$(cat /tmp/run/netconfig/$_iface/netcfg.conf|grep dev|awk -F '=' '{ print $2}')" || \
		export -n -- "$_var="
}
