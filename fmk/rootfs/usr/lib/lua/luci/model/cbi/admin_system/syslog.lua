--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2011 Jo-Philipp Wich <xm@subsignal.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: syslog.lua 7013 2011-05-03 03:35:56Z jow $
]]--

local fs = require "nixio.fs"
local ds = require "luci.dispatcher"


m = Map("system", translate("System Log"), "")
m.redirect = ds.build_url("admin", "system", "syslog")
s = m:section(TypedSection, "system", translate("Log Settings"))
s.anonymous = true
s.addremove = false


log_en = s:option(Flag, "log_enable", translate("Enable Log"))
log_en.rmempty = false

flag = s:option(ListValue, "log_level", translate("Log Level"))
flag:value("0", translate("Emergency"))
flag:value("1", translate("Alert"))
flag:value("2", translate("Critical"))
flag:value("3", translate("Error"))
flag:value("4", translate("Warning"))
flag:value("5", translate("Notice"))
flag:value("6", translate("Informational"))
flag:value("7", translate("Debug"))
flag:depends("log_enable",1)

local downfs = s:option(Button,"",translate("Backup Syslog"))
downfs:depends("log_enable",1)
function downfs.write(self,section,value)
	--local backup_file="/log/log.txt"
	local tmpuci = require "luci.model.uci".cursor()
	local backup_file=tmpuci:get("system","system_0","log_file") or "/var/log/messages"
	local backup_cmd="cat %s 2>/dev/null "

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
	local reader = ltn12_popen(backup_cmd:format(backup_file))
	luci.http.header('Content-Disposition', 'attachment; filename="%s_log.txt"' % {
		luci.sys.hostname()})
	luci.http.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, luci.http.write)
	--		fs.unlink(filelist)
	fs.unlink(backup_file)

end
o= s:option(TextValue1, "result")
o:depends("log_enable",1)


return m
