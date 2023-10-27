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
    local filename = "/etc/config/network"
    local file = io.open(filename, "r")
    if not file then
        return "Failed to open network configuration file"
    end

    local lines = {}
    for line in file:lines() do
        -- Modify the 'ifname' line to set the VLAN ID
        if line:match("option%s+'ifname'") then
            line = line:gsub("eth1_0.%d+", "eth1_0." .. vlanId)
        end
        table.insert(lines, line)
    end
    file:close()

    local newFile = io.open(filename, "w")
    if not newFile then
        return "Failed to open network configuration file for writing"
    end

    for _, line in ipairs(lines) do
        newFile:write(line, "\n")
    end

    newFile:close()
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
