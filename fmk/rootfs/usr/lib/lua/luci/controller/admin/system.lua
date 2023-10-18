--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008-2009 Jo-Philipp Wich <xm@subsignal.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: system.lua 7026 2011-05-04 21:37:41Z jow $
]]--
--acb
module("luci.controller.admin.system", package.seeall)

function index()
	luci.i18n.loadc("base")
	local i18n = luci.i18n.translate
	local page

	entry({"admin", "system"}, alias("admin", "system", "admin"), i18n("System"), 5).index = true
	entry({"admin", "system", "admin"}, cbi("admin_system/admin"), i18n("Administration"), 2)	
	entry({"admin", "system", "reboot"}, call("action_reboot"), i18n("Reboot"), 6)
	--entry({"admin", "system", "syslog"}, cbi("admin_system/syslog"), i18n("System Log"), 7)
	entry({"admin", "system", "diagnostics"}, template("admin_system/diagnostics"), i18n("Diagnostics"), 8)
	entry({"admin", "system", "flashops"}, call("action_flashops"), i18n("Backup / Flash Firmware"), 4)
	
	
	page = entry({"admin", "system", "diag_ping"}, call("diag_ping"), nil)
	page.leaf = true

--	page = entry({"admin", "system", "diag_nslookup"}, call("diag_nslookup"), nil)
--	page.leaf = true

	page = entry({"admin", "system", "diag_traceroute"}, call("diag_traceroute"), nil)
	page.leaf = true

	local pagelang = entry({"admin", "system", "language"}, cbi("admin_system/lang"), i18n("Language"), 9)	
	pagelang.leaf = true
--	entry({"admin", "system", "maintain"}, call("action_maintain"), i18n("Maintain"), 10)	
--	entry({"admin", "system", "logout"}, call("action_logout"), i18n("Logout"), 11)
end

function action_flashops()
	local sys = require "luci.sys"
	local fs  = require "luci.fs"

	local upgrade_avail = nixio.fs.access("/lib/upgrade/platform.sh")
	local reset_avail   = os.execute([[grep '"rootfs_data"' /proc/mtd >/dev/null 2>&1]]) == 0

	--local restore_cmd = "tar -xzC/ >/dev/null 2>&1"
	local backup_cmd  = "tar -czT %s 2>/dev/null"
	local image_tmp   = "/tmp/firmware.img"
	local conf_tmp   = "/tmp/conf.tar.gz"

	local function image_supported()
		-- XXX: yay...
		return ( 0 == os.execute(
			". /lib/functions.sh; " ..
			"include /lib/upgrade; " ..
			"platform_check_image %q >/dev/null"
				% image_tmp
		) )
	end

	local function conf_supported()
		return ( "1f8b" == luci.sys.exec(
			". /lib/functions.sh; " ..
			"include /lib/upgrade; " ..
			"get_magic_word %q cat"
				% conf_tmp
		))
	end

	local function image_checksum()
		return (luci.sys.exec("md5sum %q" % image_tmp):match("^([^%s]+)"))
	end

	local function storage_size()
		local size = 0
		if nixio.fs.access("/proc/mtd") then
			for l in io.lines("/proc/mtd") do
				local d, s, e, n = l:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+"([^%s]+)"')
				if n == "linux" or n == "firmware" then
					size = tonumber(s, 16)
					break
				end
			end
		elseif nixio.fs.access("/proc/partitions") then
			for l in io.lines("/proc/partitions") do
				local x, y, b, n = l:match('^%s*(%d+)%s+(%d+)%s+([^%s]+)%s+([^%s]+)')
				if b and n and not n:match('[0-9]') then
					size = tonumber(b) * 1024
					break
				end
			end
		end
		return size
	end


	local fp
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not fp then
				if meta and meta.name == "image" then
					fp = io.open(image_tmp, "w")
				else
					fp = io.open(conf_tmp, "w")
				end
			end
			if chunk then
				fp:write(chunk)
			end
			if eof then
				fp:close()
			end
		end
	)

	if luci.http.formvalue("backup") then
		--
		-- Assemble file list, generate backup
		--
		local filelist = "/tmp/luci-backup-list.%d" % os.time()
		sys.call(
			"( find $(sed -ne '/^[[:space:]]*$/d; /^#/d; p' /etc/sysupgrade.conf " ..
			"/lib/upgrade/keep.d/* 2>/dev/null) -type f 2>/dev/null; " ..
			"opkg list-changed-conffiles ) | sort -u > %s" % filelist
		)
		if fs.access(filelist) then
			local reader = ltn12_popen(backup_cmd:format(filelist))
			luci.http.header('Content-Disposition', 'attachment; filename="backup-%s-%s.tar.gz"' % {
				luci.sys.hostname(), os.date("%Y-%m-%d")})
			luci.http.prepare_content("application/x-targz")
			luci.ltn12.pump.all(reader, luci.http.write)
			fs.unlink(filelist)
		end
	elseif luci.http.formvalue("restore") then
		--
		-- Unpack received .tar.gz
		--
		local upload = luci.http.formvalue("archive")
		if upload and #upload > 0 then
			if conf_supported() then
				luci.template.render("admin_system/applyreboot2")
				--luci.sys.reboot()
				fork_exec("/sbin/sysupgrade -r %q" % conf_tmp)
			else
				--nixio.fs.unlink(conf_tmp)
				luci.template.render("admin_system/flashops", {
					reset_avail   = reset_avail,
					upgrade_avail = upgrade_avail,
					conf_invalid = true
				})
			end
		end
	elseif luci.http.formvalue("image") or luci.http.formvalue("step") then
		--
		-- Initiate firmware flash
		--
		local step = tonumber(luci.http.formvalue("step") or 1)
		if step == 1 then
			if image_supported() then
				luci.template.render("admin_system/upgrade", {
					checksum = image_checksum(),
					storage  = storage_size(),
					size     = nixio.fs.stat(image_tmp).size,
					keep     = (not not luci.http.formvalue("keep"))
				})
			else
				nixio.fs.unlink(image_tmp)
				luci.template.render("admin_system/flashops", {
					reset_avail   = reset_avail,
					upgrade_avail = upgrade_avail,
					image_invalid = true
				})
			end
		--
		-- Start sysupgrade flash
		--
		elseif step == 2 then
			local keep = (luci.http.formvalue("keep") == "1") and "" or "-n"
			luci.template.render("admin_system/applyreboot2", {
				title = luci.i18n.translate("Flashing..."),
				msg   = luci.i18n.translate("The system is flashing now.<br /> DO NOT POWER OFF THE DEVICE!<br /> Wait a few minutes until you try to reconnect. It might be necessary to renew the address of your computer to reach the device again, depending on your settings."),
				addr  = (#keep > 0) and "192.168.1.1" or nil
			})
			fork_exec("sleep 1; killall dropbear uhttpd; sleep 1; /sbin/sysupgrade %s %q" %{ keep, image_tmp })
		end
	elseif reset_avail and luci.http.formvalue("reset") then
		--
		-- Reset system
		--
		luci.template.render("admin_system/applyreboot2", {
			title = luci.i18n.translate("Erasing..."),
			msg   = luci.i18n.translate("The system is erasing the configuration partition now and will reboot itself when finished."),
			addr  = "192.168.1.1"
		})
		fork_exec("sleep 1; killall dropbear uhttpd; sleep 1; fw_setenv customized 0 && mtd -r erase rootfs_data")
	else
		--
		-- Overview
		--
		luci.template.render("admin_system/flashops", {
			reset_avail   = reset_avail,
			upgrade_avail = upgrade_avail
		})
	end
end

function fork_command(cmd,renderpath)
	if nixio.fork() == 0 then
			local i = nixio.open("/dev/null", "r")
			local o = nixio.open("/dev/null", "w")

			nixio.dup(i, nixio.stdin)
			nixio.dup(o, nixio.stdout)

			i:close()
			o:close()

			nixio.exec("/bin/sh" ,"-c",cmd)
--		else
--			luci.template.render(renderpath)
--			os.exit(0)
		end
end

function action_passwd()
	local p1 = luci.http.formvalue("pwd1")
	local p2 = luci.http.formvalue("pwd2")
	local stat = nil

	local uci = require("luci.model.uci").cursor()
	local n1 = uci:get("usercfg","usercfg_0","user")
	local n2 = uci:get("usercfg","usercfg_0","admin")
	if n1 == nil or n2 == nil then
		n1 = "useradmin"
		n2 = "R3000admin"
	end
	if p1 or p2 then
		if p1 == p2 then
--			stat = luci.sys.user.setpasswd("root", p1)
			stat = luci.sys.user.setpasswd(n2, p1)
		else
			stat = 10
		end
	end

	luci.template.render("admin_system/passwd", {stat=stat})
end

function action_reboot()
	local reboot = luci.http.formvalue("reboot")
	luci.template.render("admin_system/reboot", {reboot=reboot})
	if reboot then
		luci.sys.reboot()
	end
end

function action_maintain()
	local maintain = luci.http.formvalue("maintain")
	luci.template.render("admin_system/maintain", {maintain=maintain})
	if maintain then
		os.execute("tr_send -m")
	--	os.execute("echo 123 >> /tmp/test456")
	end
end

function action_upgrade()
	require("luci.model.uci")

	local tmpfile = "/tmp/firmware.img"

	local function image_supported()
		-- XXX: yay...
		return ( 0 == os.execute(
			". /etc/functions.sh; " ..
			"include /lib/upgrade; " ..
			"platform_check_image %q >/dev/null"
				% tmpfile
		) )
	end

	local function image_checksum()
		return (luci.sys.exec("md5sum %q" % tmpfile):match("^([^%s]+)"))
	end

	local function storage_size()
		local size = 0
		if nixio.fs.access("/proc/mtd") then
			for l in io.lines("/proc/mtd") do
				local d, s, e, n = l:match('^([^%s]+)%s+([^%s]+)%s+([^%s]+)%s+"([^%s]+)"')
				if n == "image" then
					size = tonumber(s, 16)
					break
				end
			end
		elseif nixio.fs.access("/proc/partitions") then
			for l in io.lines("/proc/partitions") do
				local x, y, b, n = l:match('^%s*(%d+)%s+(%d+)%s+([^%s]+)%s+([^%s]+)')
				if b and n and not n:match('[0-9]') then
					size = tonumber(b) * 1024
					break
				end
			end
		end
		return size
	end


	-- Install upload handler
	local file
	luci.http.setfilehandler(
		function(meta, chunk, eof)
			if not nixio.fs.access(tmpfile) and not file and chunk and #chunk > 0 then
				file = io.open(tmpfile, "w")
			end
			if file and chunk then
				file:write(chunk)
			end
			if file and eof then
				file:close()
			end
		end
	)


	-- Determine state
	local keep_avail   = true
	local step         = tonumber(luci.http.formvalue("step") or 1)
	local has_image    = nixio.fs.access(tmpfile)
	local has_support  = image_supported()
	local has_platform = nixio.fs.access("/lib/upgrade/platform.sh")
	local has_upload   = luci.http.formvalue("image")

	-- This does the actual flashing which is invoked inside an iframe
	-- so don't produce meaningful errors here because the the
	-- previous pages should arrange the stuff as required.
	if step == 4 then
		if has_platform and has_image and has_support then
			-- Mimetype text/plain
			luci.http.prepare_content("text/plain")
			luci.http.write("Starting sysupgrade...\n")

			io.flush()

			-- Now invoke sysupgrade
			local keepcfg = keep_avail and luci.http.formvalue("keepcfg") == "1"
			local flash = ltn12_popen("/sbin/sysupgrade -r %s %q" %{
				keepcfg and "" or "-n", tmpfile
			})

			luci.ltn12.pump.all(flash, luci.http.write)
		end


	--
	-- This is step 1-3, which does the user interaction and
	-- image upload.
	--

	-- Step 1: file upload, error on unsupported image format
	elseif not has_image or not has_support or step == 1 then
		-- If there is an image but user has requested step 1
		-- or type is not supported, then remove it.
		if has_image then
			nixio.fs.unlink(tmpfile)
		end

		luci.template.render("admin_system/upgrade", {
			step=1,
			bad_image=(has_image and not has_support or false),
			keepavail=keep_avail,
			supported=has_platform
		} )

	-- Step 2: present uploaded file, show checksum, confirmation
	elseif step == 2 then
		luci.template.render("admin_system/upgrade", {
			step=2,
			checksum=image_checksum(),
			filesize=nixio.fs.stat(tmpfile).size,
			flashsize=storage_size(),
			keepconfig=(keep_avail and luci.http.formvalue("keepcfg") == "1")
		} )

	-- Step 3: load iframe which calls the actual flash procedure
	elseif step == 3 then
		luci.template.render("admin_system/upgrade", {
			step=3,
			keepconfig=(keep_avail and luci.http.formvalue("keepcfg") == "1")
		} )
	end
end

function fork_exec(command)
	local pid = nixio.fork()
	if pid > 0 then
		return
	elseif pid == 0 then
		-- change to root dir
		nixio.chdir("/")

		-- patch stdin, out, err to /dev/null
		local null = nixio.open("/dev/null", "w+")
		if null then
			nixio.dup(null, nixio.stderr)
			nixio.dup(null, nixio.stdout)
			nixio.dup(null, nixio.stdin)
			if null:fileno() > 2 then
				null:close()
			end
		end

		-- replace with target command
		nixio.exec("/bin/sh", "-c", command)
	end
end

function ltn12_popen(command)

	local fdi, fdo = nixio.pipe()
	local pid = nixio.fork()

	if pid > 0 then
		fdo:close()
		local close
		return function()
			local buffer = fdi:read(2048)
			local wpid, stat = nixio.waitpid(pid, "nohang")
			if not close and wpid and stat == "exited" then
				close = true
			end

			if buffer and #buffer > 0 then
				return buffer
			elseif close then
				fdi:close()
				return nil
			end
		end
	elseif pid == 0 then
		nixio.dup(fdo, nixio.stdout)
		fdi:close()
		fdo:close()
		nixio.exec("/bin/sh", "-c", command)
	end
end

function diag_command(cmd)
	local path = luci.dispatcher.context.requestpath
--	local addr = path[#path]  wxb
	local netm = require "luci.model.wanlink".init()	
	local index = #path
	local addr = path[index-1]
	local net = netm.waninfo_get(path[index])
	local netrun = netm.waninfo_get_extern(net.ConnName)
	local interface= netrun.Interface
	local ipaddress = nil

	if not addr or not net then
	   luci.http.status(500, "Bad Parament")
	   return 0
	end
	-- get ipaddress of ether
	local data = {
				ifname = interface
			}
	for _, info in ipairs(nixio.getifaddrs()) do
		local name = info.name:match("[^:]+")
		if name == interface then
			if info.family == "packet" then
				data.flags   = info.flags
				data.stats   = info.data
				data.macaddr = info.addr
		--		data.ifname  = name
			elseif info.family == "inet" then
				data.ipaddrs = data.ipaddrs or { }
				data.ipaddrs[#data.ipaddrs+1] = {
					addr      = info.addr,
					broadaddr = info.broadaddr,
					dstaddr   = info.dstaddr,
					netmask   = info.netmask,
					prefix    = info.prefix
				}
			elseif info.family == "inet6" then
				data.ip6addrs = data.ip6addrs or { }
				data.ip6addrs[#data.ip6addrs+1] = {
					addr    = info.addr,
					netmask = info.netmask,
					prefix  = info.prefix
				}
			end
		end
	end

	os.execute(string.format("echo debug %s  %s >/tmp/diad ",addr,net.ConnName))
	if data.ipaddrs and  data.ipaddrs[1] and data.ipaddrs[1].addr then
			ipaddress = data.ipaddrs[1].addr
	end
	
	if addr and addr:match("^[a-zA-Z0-9%-%.:_]+$") then
		luci.http.prepare_content("text/plain")
		
		if not ipaddress then
			local ln = string.format("the interface %q doesn't get ipaddress",net.ConnName)
		  	luci.http.write(ln)
			luci.http.write("\n\n")
			
		else
			local ln = string.format("Diagnostic %q from interface %q",addr,net.ConnName)
		  	luci.http.write(ln)
			luci.http.write("\n\n")
			local util = io.popen(cmd % {addr,interface}) --wxb
			if util then
				while true do
					local ln = util:read("*l")
					if not ln then break end
					luci.http.write(ln)
					luci.http.write("\n")
				end

				util:close()
			end
		end
		return
	end

	luci.http.status(500, "Bad address")
end

function diag_ping()
	diag_command("ping -c 5 -W 1 %q -I %q 2>&1")
end

function diag_traceroute()
	diag_command("traceroute -q 1 -w 1 -n %q  -i %q 2>&1")
end
--[[
function diag_nslookup()
	diag_command("nslookup %q 2>&1")
end
]]--
