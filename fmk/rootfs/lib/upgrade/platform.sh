#
# Copyright (C) 2011 OpenWrt.org
#

. /lib/ramips.sh

PART_NAME=firmware
RAMFS_COPY_DATA=/lib/ramips.sh

CI_BLKSZ=65536
CI_LDADR=0x88000000

platform_find_partitions() {
	local first dev size erasesize name
	while read dev size erasesize name; do
		name=${name#'"'}; name=${name%'"'}
		case "$name" in
			vmlinux.bin.l7|vmlinux|kernel|linux|linux.bin|rootfs|filesystem)
				if [ -z "$first" ]; then
					first="$name"
				else
					echo "$erasesize:$first:$name"
					break
				fi
			;;
		esac
	done < /proc/mtd
}

platform_find_kernelpart() {
	local part
	for part in "${1%:*}" "${1#*:}"; do
		case "$part" in
			vmlinux.bin.l7|vmlinux|kernel|linux|linux.bin)
				echo "$part"
				break
			;;
		esac
	done
}

platform_do_upgrade_combined() {
	local partitions=$(platform_find_partitions)
	local kernelpart=$(platform_find_kernelpart "${partitions#*:}")
	local erase_size=$((0x${partitions%%:*})); partitions="${partitions#*:}"
	local kern_length=0x$(dd if="$1" bs=2 skip=1 count=4 2>/dev/null)
	local kern_blocks=$(($kern_length / $CI_BLKSZ))
	local root_blocks=$((0x$(dd if="$1" bs=2 skip=5 count=4 2>/dev/null) / $CI_BLKSZ))

	if [ -n "$partitions" ] && [ -n "$kernelpart" ] && \
	   [ ${kern_blocks:-0} -gt 0 ] && \
	   [ ${root_blocks:-0} -gt ${kern_blocks:-0} ] && \
	   [ ${erase_size:-0} -gt 0 ];
	then
		local append=""
		[ -f "$CONF_TAR" -a "$SAVE_CONFIG" -eq 1 ] && append="-j $CONF_TAR"

		( dd if="$1" bs=$CI_BLKSZ skip=1 count=$kern_blocks 2>/dev/null; \
		  dd if="$1" bs=$CI_BLKSZ skip=$((1+$kern_blocks)) count=$root_blocks 2>/dev/null ) | \
			mtd -r $append -F$kernelpart:$kern_length:$CI_LDADR,rootfs write - $partitions
	fi
}

tplink_get_image_hwid() {
	get_image "$@" | dd bs=4 count=1 skip=16 2>/dev/null | hexdump -v -n 4 -e '1/1 "%02x"'
}

tplink_get_image_boot_size() {
	get_image "$@" | dd bs=4 count=1 skip=37 2>/dev/null | hexdump -v -n 4 -e '1/1 "%02x"'
}

#目前除了平台的检查，还加了版本的检查，调用的时候需要注意
platform_check_image() {
	local board=$(ramips_board_name)
	local magic="$(get_magic_word "$1")"
	local magic_long="$(get_magic_long "$1")"
	# should check hw version first from cpuinfo
	#local hv=$(awk 'BEGIN{FS=":"} /machine/ {print $3}' /proc/cpuinfo)
	local fv=$(get_rev_rl $1)
	local spiFlash=$(awk 'BEGIN{FS=":"} /spi/ {print $2}' /sys/bus/spi/devices/spi0.0/modalias)
	
	[ "$ARGC" -gt 1 ] && return 1

	case "$board" in
	rl-ans5004)
		[ "$magic_long" != "68737173" -a "$magic_long" != "19852003" ] && {
			echo "Invalid image type."
			return 1
		}
		return 0
		;;
	rl-s4005ef)
		[ "$magic_long" != "524c6677"  ] && {
			echo "Invalid image type."
			return 1
		}
		if [ "$spiFlash" = "gd25q127" ]; then
			#echo "fw ver=$fv"	
			[ $fv -lt 12871 ] && {
				echo "Not support to degrade to the Revision that older than 12871"
				return 1
			}
		fi
		return 0
		;;
	esac

	echo "Sysupgrade is not yet supported on $board."
	return 1
}

platform_do_upgrade() {
	local board=$(ramips_board_name)

	case "$board" in
	rl-s4005ef)
		default_do_upgrade "$ARGV"
		;;
	*)
		default_do_upgrade "$ARGV"
		;;
	esac
}

disable_watchdog() {
	killall watchdog
	( ps | grep -v 'grep' | grep '/dev/watchdog' ) && {
		echo 'Could not disable watchdog'
		return 1
	}
}

append sysupgrade_pre_upgrade disable_watchdog
