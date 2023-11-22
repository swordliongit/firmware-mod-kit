--[[
Author: Kılıçarslan SIMSIKI

Date Created: 17-10-2023
Date Modified: 26-10-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]

require("luci.sys")
local uci = require("uci")

Vlan = {}
local cursor = uci.cursor()

function Vlan.Get_VlanId()
    local vlanId = "1" -- Default VLAN ID is 1

    cursor:foreach("network", "interface", function(s)
        if s[".name"] == "lan" then
            local ifname = s["ifname"]
            local vlanPart = ifname:match("eth1_0%.(%d+)")
            if vlanPart then
                vlanId = vlanPart
            end
        end
    end)

    return tostring(vlanId)
end

function Vlan.Set_VlanId(vlanId)
    local ifname = (vlanId == "1") and "eth1_0" or string.format("eth1_0.%s", vlanId)
    local command = string.format("uci set network.lan.ifname='%s eth1_1 eth1_2 eth1_3 ra0 ra1 ra2'", ifname)
    luci.sys.call(command)
    luci.sys.call("uci commit network")
end

-- Didn't work
-- function Vlan.Set_VlanId(vlanId)
--     local vlanPart = "eth1_0." .. vlanId

--     local cursor = uci.cursor()
--     cursor:foreach("network", "interface", function(s)
--         if s[".name"] == "lan" then
--             s["ifname"] = s["ifname"]:gsub("eth1_0.%d+", vlanPart)
--         end
--     end)

--     cursor:commit("network")
-- end
