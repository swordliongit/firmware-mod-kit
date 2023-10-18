
module("luci.controller.failsafe.failsafe", package.seeall)

function index()
    luci.i18n.loadc("base")
    local i18n = luci.i18n.translate
    local fs = require "nixio.fs"
	local root = node()
	if not root.target then
		root.target = alias("failsafe")
		root.index = true
	end

	--page          = node()
	--page.lock     = true
	--page.target   = alias("failsafe")
	--page.subindex = true
	--page.index    = false

	page          = node("failsafe")
	page.title    = i18n("Fail-safe")
	page.target   = alias("failsafe", "passwd")
	page.order    = 5
	page.sysauth  = "failsafe"
	page.sysauth_authenticator = "htmlauth"
	page.index    = true

	entry({"failsafe", "passwd"}, cbi("failsafe/passwd"), i18n("Admin Password"), 70).index = true
	entry({"failsafe", "styles"}, call("action_styles"), i18n("Select Styles"), 80)
end
function action_styles()
	local tmpfile = "/var/vendor.cfg"
	
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

	-- upload 
	local upload = luci.http.formvalue("archive")

	if upload and #upload > 0 then
		
		if nixio.fork() == 0 then
			local i = nixio.open("/dev/null", "r")
			local o = nixio.open("/dev/null", "w")

			nixio.dup(i, nixio.stdin)
			nixio.dup(o, nixio.stdout)

			i:close()
			o:close()

			nixio.exec("/bin/sh" ,"-c","fw_setenv customized 0 && mtd -r write " .. tmpfile .. " vendor") 
		else
			luci.template.render("failsafe/applyreboot",{msg="change the product styles, please waiting..."})
			os.exit(0)
		end
	else
		luci.template.render("styles" )
	end
end
