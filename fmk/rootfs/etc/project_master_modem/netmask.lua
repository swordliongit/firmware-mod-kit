--[[
Author: Kılıçarslan SIMSIKI

Date Created: 20-05-2023
Date Modified: 23-05-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]

local uci = require("uci")

Netmask = {}
local cursor = uci.cursor()

function Netmask.Get_netmask()
    -- if dhcp client is off, we want to return a template so it will trigger the Set_netmask function to set the netmask.
    -- if we don't do this, this function will get the netmask from the ifconfig and it won't set a netmask in the config
    -- because it could be the same.
    -- local handle = io.popen("ifconfig br-lan")
    -- local subnetMask = nil

    -- if handle then
    --     for line in handle:lines() do
    --         subnetMask = line:match("Mask:(%d+%.%d+%.%d+%.%d+)")
    --         if subnetMask then
    --             break
    --         end
    --     end
    --     handle:close()
    --     return subnetMask
    -- end
    local ip = cursor:get("network", "lan", "netmask")
    return ip
end

function Netmask.Set_netmask(netmask)
    cursor:set("network", "lan", "netmask", netmask)
    cursor:commit("network")
end
