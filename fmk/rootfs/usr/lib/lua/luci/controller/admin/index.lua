--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: index.lua 6719 2011-01-13 22:21:16Z jow $
]]--
module("luci.controller.admin.index", package.seeall)

function index()
	luci.i18n.loadc("base")
	local i18n = luci.i18n.translate

	local root = node()
	if not root.target then
		root.target = alias("admin")
		root.index = true
	end

	local uci = require("luci.model.uci").cursor()
	local n1 = uci:get("usercfg","usercfg_0","user")
	local n2 = uci:get("usercfg","usercfg_0","admin")
	if n1 == nil or n2 == nil then
		n1 = "useradmin"
		n2 = "R3000admin"
	end
	local page   = node("admin")
	page.target  = alias("admin", "status")
	page.title   = i18n("Administration")
	page.order   = 10
	page.sysauth = n2
	page.sysauth_authenticator = "htmlauth"
	page.ucidata = true
	page.index = true

	local http = require "luci.http"
	local conf = require "luci.config"
	local lang = conf.main.lang or "auto"

	if lang == "auto" then
		local aclang = http.getenv("HTTP_ACCEPT_LANGUAGE") or ""
		for lpat in aclang:gmatch("[%w-]+") do
			lpat = lpat and lpat:gsub("-", "_")
			if lpat == "zh_CN" then
				lpat = "zh_cn"
			end
			if conf.languages[lpat] then
				lang = lpat
				break
			end
		end
	end
	
	if lang =="zh_cn" then
		entry({"admin", "help"}, alias("admin", "help", "help"), i18n("Help"), 6).index = true
		entry({"admin", "help", "help"}, template("admin_status/help"), i18n("Help"), 1)
	end
end


