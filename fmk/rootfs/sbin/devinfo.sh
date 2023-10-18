#!/bin/sh

. /etc/functions.sh

telecom(){
	local cfg="$1"

	config_get en "$cfg" enable
	config_get pwd "$cfg" password
	config_get tele_user "$cfg" username
	config_get tele_olduser "$cfg" oldusername

   [ $tele_olduser != $tele_user ] && {
        rm -rf /tmp/luci*
        deluser $tele_olduser
    }
	
	[ $en -eq "1" ] && {
		[ "$pwd" != nil ] && {
			adduser -DH $tele_user
			shpasswd $tele_user $pwd
		}
	}
	
	[ $en -eq "0" ] && {
	   rm -rf /tmp/luci*
		deluser $tele_user
	}
}

config_load devinfo
config_foreach telecom telecomaccount
