

m = Map("userfw", "", "")

s = m:section(TypedSection, "protoBanned", translate("Proto Filters"))
s.anonymous = true
s.addremove = false



icmp=s:option(Flag, "icmp_wan", translate("ICMP From WAN"))
icmp.rmempty = false
telnet=s:option(Flag, "telnet_wan", translate("Telnet From WAN"))
telnet.rmempty = false
ssh=s:option(Flag, "ssh_wan", translate("SSH From WAN"))
ssh.rmempty = false
http=s:option(Flag, "http_wan", translate("HTTP From WAN"))
http.rmempty = false

return m
