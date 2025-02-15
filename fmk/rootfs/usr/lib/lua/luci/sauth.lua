--[[

Session authentication
(c) 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

$Id: sauth.lua 5185 2009-07-31 17:08:59Z Cyrus $
-- modify history
    add check session exist
]]--

--- LuCI session library.
module("luci.sauth", package.seeall)
local util = require("luci.util")
require("luci.sys")
require("luci.config")
local nixio = require "nixio", require "nixio.util"
local fs = require "nixio.fs"


luci.config.sauth = luci.config.sauth or {}
sessionpath = luci.config.sauth.sessionpath
sessiontime = tonumber(luci.config.sauth.sessiontime) or 15 * 60


sauthlimitpath = luci.config.sauth.sauthlimitpath  
-- sauthlimitpath =  "/tmp/luci-sauth-limit"
sauthlimittime = tonumber(luci.config.sauth.sauthlimittime)  or 60

--- Manually clean up expired sessions.
function clean()
	local now   = os.time()
	local files = fs.dir(sessionpath)
	
	if not files then
		return nil
	end
	
	for file in files do
		local fname = sessionpath .. "/" .. file
		local stat = fs.stat(fname)
		if stat and stat.type == "reg" and stat.mtime + sessiontime < now then
			fs.unlink(fname)
		end 
	end
end

--- Prepare session storage by creating the session directory.
function prepare()
	fs.mkdir(sessionpath, 700)
	 
	if not sane() then
		error("Security Exception: Session path is not sane!")
	end
end

--- Read a session and return its content.
-- @param id	Session identifier
-- @return		Session data
function read(id)
	if not id or #id == 0 then
		return
	end
	if not id:match("^%w+$") then
		error("Session ID is not sane!")
	end
	clean()
	if not sane(sessionpath .. "/" .. id) then
		return
	end
--	fs.utimes(sessionpath .. "/" .. id)  匹配用户限制，不要在此做文件更新
	return fs.readfile(sessionpath .. "/" .. id)
end


--- Check whether Session environment is sane.
-- @return Boolean status
function sane(file)
	return luci.sys.process.info("uid")
			== fs.stat(file or sessionpath, "uid")
		and fs.stat(file or sessionpath, "modestr")
			== (file and "rw-------" or "rwx------")
end


--- Write session data to a session file.
-- @param id	Session identifier
-- @param data	Session data
function write(id, data)
	if not sane() then
		prepare()
	end
	if not id:match("^%w+$") then
		error("Session ID is not sane!")
	end
	
	local f = nixio.open(sessionpath .. "/" .. id, "w", 600)
	f:writeall(data)
	f:close()
end


--- Kills a session
-- @param id	Session identifier
function kill(id)
	if not id:match("^%w+$") then
		error("Session ID is not sane!")
	end
	fs.unlink(sessionpath .. "/" .. id)
end
-- function accesstimeupdate
function accesstimeupdate(id)
	if not id or #id == 0 then
		return
	end
	if not id:match("^%w+$") then
		error("Session ID is not sane!")
	end
	
	if not sane(sessionpath .. "/" .. id) then
		return
	end
	fs.utimes(sessionpath .. "/" .. id) 
end
--用于更新所有的session 认证时间
function updateall()
	local files = fs.dir(sessionpath)
	
	if not files then
		return nil
	end
	
	for file in files do
		local fname = sessionpath .. "/" .. file
		fs.utimes(fname) 
	end
end
--- check and return now session
function get()
	local files = fs.dir(sessionpath)
	local havefile = 0
	local sess_id
	
	if not files then
		return nil
	end
	for file in files do
		havefile = havefile + 1
		sess_id=file
	end

	if havefile == 0 then
	   return nil
	end
	return sess_id
end

-- cleanlimit file
function cleanlmt()     
   local fname = sauthlimitpath 
   fs.unlink(fname)
end

-- readlmt 
function readlmt()
   local sdat

--   fs.utimes(sauthlimitpath .. "/" .. id)
   sdat =  fs.readfile(sauthlimitpath )
   if not sdat then
   	return nil
   end
   
   return loadstring(sdat)()
end
-- writelimt
-- data :        
--	     count 
function writelmt(data)

  local f = nixio.open(sauthlimitpath , "w", 600)
  f:writeall(data)
  f:close()
end
--- login err : can't try >=3
function checklmtlogin(trycount)
   local sauthdata = readlmt()
   local count = 0

   if sauthdata then
   	if tonumber(sauthdata.count)  >= trycount then   		
   		return nil
   	end
   	count  =  tonumber(sauthdata.count)  or 0
   end
   
   return 1,count
end

function updatelimtcnt()
	local rdata = readlmt()
	local count = rdata and rdata.count  or 0
	
	count = count + 1 
	writelmt(util.get_bytecode({count = count}))
    return count
end
function updatelimttime()
	local now   = os.time()
	
	local stat = fs.stat(sauthlimitpath)
		
	if stat and stat.type == "reg" and stat.mtime + sauthlimittime < now then
		cleanlmt()
	end 
end


