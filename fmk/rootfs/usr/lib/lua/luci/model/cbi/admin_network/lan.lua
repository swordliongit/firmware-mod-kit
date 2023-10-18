--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id: lan.lua 6065 2010-04-14 11:36:13Z ben $
]]--
local string = require "string"
local nw = require "luci.model.network"
local utl = require "luci.util"
local uci = require "luci.model.uci".cursor()
local ds = require "luci.dispatcher"
local ip = require "luci.ip"
local sauth = require "luci.sauth"

local has_v2 = nixio.fs.access("/lib/network/dhcp.sh")

require("luci.tools.webadmin")
--[[
	����޸ĺ��ipstart string ��ipend string �Ƿ�
	��ͬһ������ip��Χ�Ƿ�ipstart <= ipend,ipstart
	��ipend �Ƿ�Ϊ����ip
	return false or true 
	return new ipstart
	return new ipend
--]]
function check_rang_value(ipstart,ipend,ipmask)
	local valid = true
	local ips  = ip.IPv4(ipstart,ipmask) 
	local ipe  = ip.IPv4(ipend,ipmask)
	local iphostmin 
	local iphostmax
	
	iphostmin = ips:minhost()
	iphostmax = ips:maxhost()

	if ips:lower(iphostmin) == true then
		valid = false
		ips = iphostmin
	end

	if ips:higher(iphostmax) ==  true then
		valid = false
		ips = iphostmax
	end

	if ipe:lower(iphostmin) == true then
		valid = false
		ipe = iphostmin
	end

	if ipe:higher(iphostmax) ==  true then
		valid = false
		ipe = iphostmax
	end	
	
	if ips:higher(ipe) == true then
		valid = false
		ipe = ips
	end
	
	return valid,ips:string():match("([%d%.]+)"),ipe:string():match("([%d%.]+)")
end
function write_pool_value(ipstring,ipmask)
	local ipval = ip.IPv4(ipstring,ipmask)
	local ipnet = ipval:network()
	local stbl={}
	
	m.uci:foreach("dhcp","dhcp",function(section)
			if section.networkid ~= nil then --not consider the interface
				
				local ips = ip.IPv4(section.start,ipmask)
				local ipe = ip.IPv4(section["end"],ipmask)
						
				local ipsnet = ips:network()
				local ipenet = ipe:network()
			
				-- remove the subnet
				ips = ips:sub(ipsnet,1)
				ipe = ipe:sub(ipenet,1)
				-- add new subnet
				ips = ips:add(ipnet,1)
				ipe = ipe:add(ipnet,1)

				_,section.start,section["end"] = check_rang_value( ips:string():match("(.+)/"), ipe:string():match("(.+)/"),ipmask)
			
		--		section.start = ips:string():match("(.+)/")
		--		section["end"] = ipe:string():match("(.+)/")
				stbl[#stbl+1] = section
			end
		end)
	for i,v in ipairs(stbl) do
		m.uci:set("dhcp",v[".name"],"start",v.start)
		m.uci:set("dhcp",v[".name"],"end",v["end"])
	end
end
--[[
	���dhcp ��ip pool ����ֵ�Ƿ�Ϊhost ip
	�Ƿ���lan ip  ��ͬһ������
--]]
function check_address_subnet(ipstring,ipmask,poolstring)
	local ipval = ip.IPv4(ipstring,ipmask)
	local poolval = ip.IPv4(poolstring, ipmask)

	local poolnet = poolval:network()
	local ipnet = ipval:network()

	if poolnet:equal(ipnet) ~= true then -- not equal 
		return false
	end
	
	local iphostmin =  ipval:minhost()
	local iphostmax = ipval:maxhost()

	if poolval:lower(iphostmin) or poolval:higher(iphostmax) then
		return false	
	end
	
	return true
end
function validate_pool_value(ipstring,ipmask)
	local valid = true	
	m.uci:foreach("dhcp","dhcp",function(section)
			if s.networkid ~= nil then -- not consider interface wan
				local ips = s:formvalue(section[".name"],"start")
				local ipe = s:formvalue(section[".name"],"end")

				if (check_address_subnet(ipstring,ipmask,ips) ~= true ) or (check_address_subnet(ipstring,ipmask,ipe) ~=true ) then
						
						valid = false
				end							
			end
		end)
		
	return valid
end



m = Map("dhcp", translate("LAN"), "")
m:chain("network")
m.pagelanaction = true
m.redirect = ds.build_url("admin/system/reboot?reboot")

--s = m:section(NamedSection, "lan","interface", translate("LAN Settings"))
s = m:section(TypedSection, "dnsmasq",translate("LAN Settings"))
s.anonymous = true
s.addremove = false

ipad = s:option(Value, "ipaddr", translate("IP Address"),translate("Note: change the IP, will change the IP pool"))
ipad.rmempty = false
ipad.maxlength = 15
ipad.datatype = "ipaddr"
ipad.default = "192.168.1.1"

function ipad.cfgvalue(self, s)
--    return self.map:get(s,"ipaddr") 
	return m.uci:get("network","lan",self.option)
end
function ipad.write(self, s,value)
	local dhcpen = dhcp:formvalue(s)
	local ipmask =  nm:formvalue(s)
	
--	if dhcpen ~= "1" then --disable ,change the pool network
 		write_pool_value(value,ipmask)
--	end
--
--[[
	if ds.context.authsession then
		sauth.kill(ds.context.authsession)
		ds.context.urltoken.stok = nil
	end
--]]
	
	return m.uci:set("network","lan",self.option,value)
end
--[[
function ipad.validate(self, value,section)
	local dhcpen = 0
	local valid = true
	local ipmask =  nm:formvalue(section)

	dhcpen = dhcp:formvalue(section)
	if dhcpen ~= "1" then
		return value
	end
	valid = validate_pool_value(value,ipmask)

	if valid  ==  true then
		return value
	end

	m.message = translate("the dhcp ip pool and ip address are not in the same subnet!")
	return nil ,""
end
--]]

nm = s:option(Value, "netmask", translate("Subnet Mask"))
nm.rmempty = false
nm.maxlength = 15
nm.datatype = "ip4mask"
--[[
nm:value("255.255.255.0",translate("255.255.255.0"))
nm:value("255.255.0.0",translate("255.255.0.0"))
nm:value("255.0.0.0",translate("255.0.0.0"))
nm.default="255.255.255.0"
]]--
function nm.cfgvalue(self, s)
    return m.uci:get("network","lan",self.option)
end
function nm.write(self, s,value)
	local dhcpen = dhcp:formvalue(s)
	local ipstring = ipad:formvalue(s)
	
--	if dhcpen ~= "1" then --disable ,change the pool network
 		write_pool_value(ipstring,value)
--	end
	
	return m.uci:set("network","lan",self.option,value)
end
--[[
function nm.validate(self, value,section)
	local dhcpen = 0
	local valid = true
	local ipstring = ipad:formvalue(section)	

	local b1, b2, b3, b4 = ipstring:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
	
	local c1, c2, c3, c4 = value:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")

	b1 = tonumber(b1)
	if b1 > 0 then
		return value
	else
		m.message = translate("IP is Invalid!")
		return nil,""
	end


	dhcpen = dhcp:formvalue(section)
	if dhcpen ~= "1" then
		return value
	end
	

	valid = validate_pool_value(ipstring,value)

	if valid  ==  true then
		return value
	else

	m.message = translate("the dhcp ip pool and ip address are not in the same subnet!")
	end
	--	return nil , translate("the dhcp ip pool and ip address are not in the same subnet!")
	return nil,""
end
--]]

ldm = s:option(Value, "domain", translate("Local Domain Name"))
ldm.rmempty = false
ldm.maxlength = 64
ldm.datatype = "hostname"
function ldm.write(self, s,value)
    local llvalue
    llvalue="/" .. value .. "/"
    self.map:set(s,"domain",value)
    self.map:set(s,"local",llvalue)
	return true
end    
    

dhcp=s:option(Flag1, "dhcp_en", translate("DHCP Server Enable"))
dhcp.rmempty = false

s = m:section(TypedSection, "dhcp", translate("DHCP List"))
s.addremove = false
s.anonymous = true
s.template = "cbi/tblsection_d"

networkid = s:option(DummyValue, "networkid", translate("Network type"))
networkid.size = 15
function networkid.cfgvalue(self, s)
	local f = self.map:get(s, "networkid")

	if f == "n1" then
		return "STB"
	elseif f == "n2" then
		return "Phone"
	elseif f == "n3" then
		return "Camera"
	elseif f == "n4" then
		return "computer"
	end
end

start_ip = s:option(Value, "start", translate("Start IP"))
start_ip.datatype = "ipaddr"
start_ip.size = 15
function start_ip.write(self,section,value)
	local valid = true
	local dhcpen = 0
	m.uci:foreach("dhcp","dnsmasq",function(sec)
		    dhcpen = s:formvalue(sec[".name"],"dhcp_en")
		end)
	 
	if dhcpen ~= "1" then
		return true
	end

	--check subnet	
	m.uci:foreach("dhcp","dnsmasq",function(section)
			local ipstring = s:formvalue(section[".name"],"ipaddr")	
			local ipmask = s:formvalue(section[".name"],"netmask")		
			local dhcpen = s:formvalue(section[".name"],"dhcp_en")			
			
			if dhcpen == "1" then 
			    if check_address_subnet(ipstring,ipmask,value) ~= true  then
				valid = false
			    end
			end
		end)

	if valid ~= true then
		-- update by ipaddress
		return true
	end
	return self.map:set(section,self.option,value) 
end
function start_ip.validate(self, value,section)
	local valid = true
	local start_ip = ip.IPv4(value)
	local end_ip = ip.IPv4(end_ip:formvalue(section))
	
	if start_ip:higher(end_ip) then
      		valid = false      		
      	end
      	
      	if valid  ~= true then
      		m.message = translate("IP Start is greater than Soure IP End ")      		
      		return nil,""
	end
	
--[[
	--check subnet	
	m.uci:foreach("dhcp","dnsmasq",function(section)
			local ipstring = s:formvalue(section[".name"],"ipaddr")	
			local ipmask = s:formvalue(section[".name"],"netmask")		
			local dhcpen = s:formvalue(section[".name"],"dhcp_en")			
			
			if dhcpen == "1" then 
			    if check_address_subnet(ipstring,ipmask,value) ~= true  then
				valid = false
			    end
			end
		end)

	if valid ~= true then
		m.message = translate("the dhcp ip pool and ip address are not in the same subnet!")
		return nil ,""
	end
	
--]]
	return value
end

end_ip = s:option(Value, "end", translate("End IP"))
end_ip.datatype = "ipaddr"
end_ip.size = 15
function end_ip.write(self,section,value)
	local valid = true
	local dhcpen = 0
	m.uci:foreach("dhcp","dnsmasq",function(sec)
		    dhcpen = s:formvalue(sec[".name"],"dhcp_en")
		end)
	 
	if dhcpen ~= "1" then
		return true
	end
	--check subnet	
	m.uci:foreach("dhcp","dnsmasq",function(section)
			local ipstring = s:formvalue(section[".name"],"ipaddr")	
			local ipmask = s:formvalue(section[".name"],"netmask")		
			local dhcpen = s:formvalue(section[".name"],"dhcp_en")			
			
			if dhcpen == "1" then 
			    if check_address_subnet(ipstring,ipmask,value) ~= true  then
				valid = false
			    end
			end
		end)

	if valid ~= true then
		-- update by ipaddress
		return true
	end
	return  self.map:set(section,self.option,value)  
end

function end_ip.validate(self, value,section)
	local valid = true
	local end_ip = ip.IPv4(value)
	local start_ip = ip.IPv4(start_ip:formvalue(section))
	
	if start_ip:higher(end_ip) then
      		valid = false
      	end
      	
      	if valid  ~= true then      		
      		m.message = translate("IP Start is greater than Soure IP End ")
      		return nil ,""
	end
	
--[[
	--check subnet	
	m.uci:foreach("dhcp","dnsmasq",function(section)
			local ipstring = s:formvalue(section[".name"],"ipaddr")	
			local ipmask = s:formvalue(section[".name"],"netmask")
			local dhcpen = s:formvalue(section[".name"],"dhcp_en")			
			
			if dhcpen == "1" then 
			    if check_address_subnet(ipstring,ipmask,value) ~= true  then
			        valid = false
			    end
			end
		end)

	if valid ~= true then
		m.message = translate("the dhcp ip pool and ip address are not in the same subnet!")
		return nil,""
	end
	
--]]
	return value
end

leasetime = s:option(Value, "leasetime", translate("Leasetime (minutes)"))
leasetime.size = 15
leasetime.datatype = "uinteger"
leasetime.rmempty = false
function leasetime.cfgvalue(self, s)
	--return self.map:get(s, "leasetime") 

	local val = tostring(self.map:get(s, "leasetime"))
	if self.map:get(s, "leasetime") == nil then
		val = ""
		return val
	else
		if string.sub(val,-1) == "h" then                  
			return (string.sub(val,1,-2)*60)         
		else                                               
			return string.sub(val,1,-2)                
		end 
	end
	--return value
end

function leasetime.write(self, section, value)
	value = value.."m"
	--print(value)
	return self.map:set(section, "leasetime", value)
end

function leasetime.validate(self, value,section)
	local v = value
	if v == nil then
		m.message = translate("Leasetime is null")
		return nil
	end
	return value
end

s1=m:section(NamedSection, "wan","dhcp", translate("DNS Settings"))
s1.anonymous=true
s1.addremove=false

manualdns=s1:option(Flag, "manual_dns", translate("Manual DNS"))
manualdns.rmempty = false
manualdns.default = "0"

function manualdns.cfgvalue(self,section)	
	return m.uci:get("dhcp", "dnsmasq_0", "manual_dns") end
function manualdns.write(self, section, value)	
	m.uci:set("dhcp", "dnsmasq_0", "manual_dns", value) end

dns1_=s1:option(Value, "dns1", translate("Primary DNS"))
dns1_.default = "192.168.1.1"
dns1_.rmempty = false
dns1_:depends("manual_dns", "1")
dns1_.datatype = "ipaddr"

function dns1_.cfgvalue(self,section)	
	return m.uci:get("dhcp", "dnsmasq_0", "dns1") end
function dns1_.write(self, section, value)	
	m.uci:set("dhcp", "dnsmasq_0", "dns1", value) end

dns2_=s1:option(Value, "dns2", translate("Secondary DNS"))
dns2_.rmempty = true
dns2_:depends("manual_dns", "1")
dns2_.datatype = "ipaddr"

function dns2_.cfgvalue(self,section)	
	return m.uci:get("dhcp", "dnsmasq_0", "dns2") end
function dns2_.write(self, section, value)	
	m.uci:set("dhcp", "dnsmasq_0", "dns2", value) end

return m

