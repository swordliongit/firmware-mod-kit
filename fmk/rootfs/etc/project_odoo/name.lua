--[[
Author: Kılıçarslan SIMSIKI

Date Created: 08-09-2023
Date Modified: 08-09-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]


local uci = require("uci")

Name = {}
local cursor = uci.cursor()


function Name.Get_name()
    return cursor:get("name", "router_name", "name")
end

function Name.Set_name(name)
    cursor:set("name", "router_name", "name", name)
    cursor:commit("name")
end
