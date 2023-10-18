#!/bin/sh

RAM_ROOT=/tmp/root

ldd() { LD_TRACE_LOADED_OBJECTS=1 $*; }
libs() { ldd $* | awk '{print $3}'; }

install_file() { # <file> [ <file> ... ]
	for file in "$@"; do
		dest="$RAM_ROOT/$file"
		[ -f $file -a ! -f $dest ] && {
			dir="$(dirname $dest)"
			mkdir -p "$dir"
			cp $file $dest
		}
	done
}

install_bin() { # <file> [ <symlink> ... ]
	src=$1
	files=$1
	[ -x "$src" ] && files="$src $(libs $src)"
	install_file $files
	[ -e /lib/ld-linux.so.3 ] && {
		install_file /lib/ld-linux.so.3
	}
	shift
	for link in "$@"; do {
		dest="$RAM_ROOT/$link"
		dir="$(dirname $dest)"
		mkdir -p "$dir"
		[ -f "$dest" ] || ln -s $src $dest
	}; done
}

pivot() { # <new_root> <old_root>
	mount | grep "on $1 type" 2>&- 1>&- || mount -o bind $1 $1
	mkdir -p $1$2 $1/proc $1/dev $1/tmp $1/overlay && \
	mount -o move /proc $1/proc && \
	pivot_root $1 $1$2 || {
        umount $1 $1
		return 1
	}
	mount -o move $2/dev /dev
	mount -o move $2/tmp /tmp
	mount -o move $2/overlay /overlay 2>&-
	return 0
}

run_ramfs() { # <command> [...]
	install_bin /bin/busybox /bin/ash /bin/sh /bin/mount /bin/umount /sbin/pivot_root /usr/bin/wget /sbin/reboot /bin/sync /bin/dd /bin/grep /bin/cp /bin/mv /bin/tar /usr/bin/md5sum "/usr/bin/[" /bin/vi /bin/ls /bin/cat /usr/bin/awk /usr/bin/hexdump /bin/sleep /bin/zcat /usr/bin/bzcat
	install_bin /sbin/mtd
	install_bin /usr/sbin/fw_printenv
	install_bin /usr/sbin/fw_printenv /usr/sbin/fw_setenv
	for file in $RAMFS_COPY_BIN; do
		install_bin $file
	done
	install_file /etc/resolv.conf /lib/functions.sh /lib/upgrade/*.sh /etc/fw_env.config $RAMFS_COPY_DATA

	pivot $RAM_ROOT /mnt || {
		echo "Failed to switch over to ramfs. Please reboot."
		exit 1
	}

	mount -o remount,ro /mnt
	umount -l /mnt

	grep /overlay /proc/mounts > /dev/null && {
		mount -o remount,ro /overlay
		umount -l /overlay
	}

	# spawn a new shell from ramdisk to reduce the probability of cache issues
	exec /bin/busybox ash -c "$*"
}

run_hooks() {
	local arg="$1"; shift
	for func in "$@"; do
		eval "$func $arg"
	done
}

ask_bool() {
	local default="$1"; shift;
	local answer="$default"

	[ "$INTERACTIVE" -eq 1 ] && {
		case "$default" in
			0) echo -n "$* (y/N): ";;
			*) echo -n "$* (Y/n): ";;
		esac
		read answer
		case "$answer" in
			y*) answer=1;;
			n*) answer=0;;
			*) answer="$default";;
		esac
	}
	[ "$answer" -gt 0 ]
}

v() {
	[ "$VERBOSE" -ge 1 ] && echo "$@"
}

rootfs_type() {
	mount | awk '($3 ~ /^\/$/) && ($5 !~ /rootfs/) { print $5 }'
}

get_image() { # <source> [ <command> ]
	local from="$1"
	local conc="$2"
	local cmd

	case "$from" in
		http://*|ftp://*) cmd="wget -O- -q";;
		*) cmd="cat";;
	esac
	if [ -z "$conc" ]; then
		local magic="$(eval $cmd $from | dd bs=2 count=1 2>/dev/null | hexdump -n 2 -e '1/1 "%02x"')"
		case "$magic" in
			1f8b) conc="zcat";;
			425a) conc="bzcat";;
		esac
	fi

	eval "$cmd $from ${conc:+| $conc}"
}

get_magic_word() {
	get_image "$@" | dd bs=2 count=1 2>/dev/null | hexdump -v -n 2 -e '1/1 "%02x"'
}

get_magic_long() {
	get_image "$@" | dd bs=4 count=1 2>/dev/null | hexdump -v -n 4 -e '1/1 "%02x"'
}

get_rev_rl() {
	get_image "$@" | dd bs=4 count=1 skip=1 2>/dev/null | hexdump -v -n 4 -e '1/4 "%d"'
}

get_part_rev() {
	mtd=$(cat /proc/mtd |grep -w $1|awk -F: '{print $1}')
	cat /dev/$mtd | dd bs=4 count=1 skip=1 2>/dev/null | hexdump -v -n 4 -e '1/4 "%d"'	
}

refresh_mtd_partitions() {
	mtd refresh rootfs
}

jffs2_copy_config() {
	if grep rootfs_data /proc/mtd >/dev/null; then
		# squashfs+jffs2
		mtd -e rootfs_data jffs2write "$CONF_TAR" rootfs_data
	else
		# jffs2
		mtd jffs2write "$CONF_TAR" rootfs
	fi
}

set_zone() {
	# set zone by verID if has arg
	[ -n "$1" ] && {
		local Image1Ver=$(get_part_rev firmware)	
		local Image2Ver=$(get_part_rev firmware2)	
		if [ "$Image1Ver" = "$Image2Ver" ]; then
			v "Revisions are the same."
			return 1
		elif [ "$1" = "$Image1Ver" ]; then
			PART_NAME=firmware
		elif [ "$1" = "$Image2Ver" ]; then
			PART_NAME=firmware2
		else
			v "Revision $1 not found."
			return 1
		fi
	}

	[ -z "$PART_NAME" ] && {
		curr_zone=$(fw_printenv -n root_zone)
		case "$curr_zone" in
		0)
			PART_NAME=firmware2
			;;
		1)
			PART_NAME=firmware
			;;
		esac
	}

	case "$PART_NAME" in
		firmware)
			fw_setenv root_zone 0
			fw_setenv Image1Stable 0
			fw_setenv Image1Try 0
			;;
		firmware2)
			fw_setenv root_zone 1
			fw_setenv Image2Stable 0
			fw_setenv Image2Try 0
			;;
	esac

	return 0
}

default_do_upgrade() {
	sync
	
	curr_zone=$(fw_printenv -n root_zone)
	case "$curr_zone" in
		0)
			PART_NAME=firmware2
			;;
		1)
			PART_NAME=firmware
			;;
	esac
	get_image "$1" | mtd write - "${PART_NAME:-image}" && {
		if [ "$FLASH_ONLY" -eq 0 ]; then
			set_zone
			if [ "$SAVE_CONFIG" -eq 0 ]; then
				mtd erase rootfs_data && fw_setenv customized 0
			else
				jffs2_copy_config
			fi
		else
			bak_rev=$(get_part_rev $PART_NAME)
			sed -i 2d /tmp/.REVISION 
			echo bak_rev=$bak_rev >> /tmp/.REVISION
			rm $1
		fi
	}
}

do_upgrade() {
	v "Performing system upgrade..."
	if type 'platform_do_upgrade' >/dev/null 2>/dev/null; then
		platform_do_upgrade "$ARGV"
	else
		default_do_upgrade "$ARGV"
	fi
	
	[ "$FLASH_ONLY" -eq 1 ] && return

	v "Upgrade completed"
	[ -n "$DELAY" ] && sleep "$DELAY"

	if [ "$MANUALLY_REBOOT" -eq 0 ]; then
		ask_bool 1 "Reboot" && {
			v "Rebooting system..."
			reboot -f
			sleep 5
			echo b 2>/dev/null >/proc/sysrq-trigger
		}
	fi
}

do_assign() {
	v "Perfoming system assignment..."
	if [ "$SAVE_CONFIG" -eq 0 ]; then
		mtd erase rootfs_data && fw_setenv customized 0
	else
		jffs2_copy_config
	fi
	v "Assign completed"
	if [ "$MANUALLY_REBOOT" -eq 0 ]; then
		ask_bool 1 "Reboot" && {
			v "Rebooting system..."
			reboot -f
			sleep 5
			echo b 2>/dev/null >/proc/sysrq-trigger
		}
	fi
}
