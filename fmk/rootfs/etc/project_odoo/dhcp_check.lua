--[[
Author: Kılıçarslan SIMSIKI

Date Created: 05-06-2023
Date Modified: 05-06-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.

Usage:
This program will be executed by the /etc/rc.local to check if static ip has been set or not
]]


local uci = require("uci")
local cursor = uci.cursor()

function Dhcp_client_on()
    local ip = cursor:get("network", "lan", "ipaddr")
    local netmask = cursor:get("network", "lan", "netmask")
    if ip == nil and netmask == nil then
        return true
    else
        return false
    end
end

Dhcp_client_on()
