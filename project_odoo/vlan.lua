--[[
Author: Kılıçarslan SIMSIKI

Date Created: 17-10-2023
Date Modified: 17-10-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]


local uci = require("uci")

Vlan = {}
local cursor = uci.cursor()

function Vlan.Get_VlanId()
    local vlanId

    cursor:foreach("network", "interface", function(s)
        if s[".name"] == "lan" then
            local ifname = s["ifname"]
            local vlanPart = ifname:match("eth1_0%.(%d+)")
            if vlanPart then
                vlanId = tonumber(vlanPart)
            end
        end
    end)

    return tostring(vlanId)
end

function Vlan.Set_VlanId(vlanId)
    local vlanPart = "eth1_0." .. vlanId

    local cursor = uci.cursor()
    cursor:foreach("network", "interface", function(s)
        if s[".name"] == "lan" then
            s["ifname"] = s["ifname"]:gsub("eth1_0.%d+", vlanPart)
        end
    end)

    cursor:commit("network")
end
