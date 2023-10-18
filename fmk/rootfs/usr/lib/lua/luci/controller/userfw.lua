
module("luci.controller.userfw", package.seeall)

function index()

	if not nixio.fs.access("/etc/config/userfw") then
		return
	end
	local page 
	require("luci.i18n").loadc("userfw")
	local i18n = luci.i18n.translate
	local page = entry({"admin", "security", "userfw"}, cbi("userfw/userfw"), i18n("Proto Filters"))
	page.i18n = "userfw"
	page.dependent = true
end
