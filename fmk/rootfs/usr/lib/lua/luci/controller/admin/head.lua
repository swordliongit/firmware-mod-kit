--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2010 Jo-Philipp Wich <xm@subsignal.org>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: uci.lua 6779 2011-01-22 00:09:43Z jow $
]]--

module("luci.controller.admin.head", package.seeall)

function index()
	local i18n = luci.i18n.translate
	local redir = luci.http.formvalue("redir", true) or
	luci.dispatcher.build_url(unpack(luci.dispatcher.context.request))

	entry({"admin", "head"},nil, i18n("Configuration"))
--	entry({"admin", "head", "language"}, cbi("admin_head/lang"), i18n("Language"), 30).query = {redir=redir}
	entry({"admin", "head", "logout"}, call("action_logout"), i18n("Logout"), 20).query = {redir=redir}

end


function action_logout()

--	local logout = luci.http.formvalue("logout")
	
--	if not logout then
--		luci.template.render("admin_head/logout", {logout=logout})
--	end
	
--	if logout then
		local e=require"luci.dispatcher"
		local t=require"luci.sauth"
		if  e.context.authsession then
			t.kill(e.context.authsession)
			e.context.urltoken.stok=nil
		end

		luci.http.header("Set-Cookie","sysauth=; path="..e.build_url())
		luci.http.redirect(luci.dispatcher.build_url())
--	end
end
function change_lang_en()
	local value = luci.http.formvalue("language") or "en"

	uci:set("luci", "main", "lang", value)
	uci:commit("luci")
	luci.http.redirect( luci.dispatcher.build_url("admin"))
end	
function change_lang_cn()
	local value = luci.http.formvalue("language") or "zh_cn"

	uci:set("luci", "main", "lang", value)
	uci:commit("luci")
	luci.http.redirect( luci.dispatcher.build_url("admin"))
end	





