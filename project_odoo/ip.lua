--[[
Author: Kılıçarslan SIMSIKI

Date Created: 20-05-2023
Date Modified: 23-05-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]


local uci = require("uci")

LanIP = {}
local cursor = uci.cursor()

function LanIP.Get_Ip()
    -- local handle = io.popen("ip addr show dev br-lan")
    -- if handle then
    --     local output = handle:read("*a")
    --     handle:close()
    --     local ip = output:match("inet (%d+%.%d+%.%d+%.%d+)")
    --     return ip
    -- end
    local ip = cursor:get("network", "lan", "ipaddr")
    return ip
end

function LanIP.Set_Ip(ip)
    cursor:set("network", "lan", "ipaddr", ip)
    cursor:commit("network")
end
