--[[
Author: Kılıçarslan SIMSIKI

Date Created: 20-05-2023
Date Modified: 05-05-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]


local uci = require("uci")

Dhcp = {}
local cursor = uci.cursor()

function Dhcp.Get_dhcp_server()
    local dhcp_server =  cursor:get("dhcp", "dnsmasq_0", "dhcp_en")
    return dhcp_server == "1" and true or false
end

function Dhcp.Set_dhcp_server(dhcp_server)
    cursor:set("dhcp", "dnsmasq_0", "dhcp_en", dhcp_server)
    cursor:commit("dhcp")
end

function Dhcp.Get_dhcp_client()
    local dhcp_client = cursor:get("network", "lan", "proto")
    return dhcp_client == "dhcp" and true or false
end

function Dhcp.Set_dhcp_client(dhcp_client)
    cursor:set("network", "lan", "proto", dhcp_client)
    if dhcp_client == "static" then
        local ip = cursor:get("network", "lan", "ipaddr")
        local netmask = cursor:get("network", "lan", "netmask")
        print(ip, netmask)
        if ip == nil then
            cursor:set("network", "lan", "ipaddr", LanIP.Get_Ip())
        end
        if netmask == nil then
            cursor:set("network", "lan", "netmask", Netmask.Get_netmask())
        end
    elseif dhcp_client == "dhcp" then
        cursor:delete("network", "lan", "ipaddr")
        cursor:delete("network", "lan", "netmask")
        -- gateway will be replaced by the dhcp lease, it's not saved on the network config file
    end
    cursor:commit("network")
end