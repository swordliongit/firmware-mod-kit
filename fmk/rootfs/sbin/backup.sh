#!/bin/sh
# Copyright (C) 2006 OpenWrt.org
# Copyright (C) 2006 Fokus Fraunhofer <carsten.tittel@fokus.fraunhofer.de>

local backup

backup=`( find $(sed -ne '/^[[:space:]]*$/d; /^#/d; p' /etc/sysupgrade.conf \
		/lib/upgrade/keep.d/* 2>/dev/null) -type f 2>/dev/null; \
		opkg list-changed-conffiles ) | sort -u `

rm -f /tmp/backup.tar.gz
tar -czf /tmp/backup.tar.gz $backup 2>/dev/null
