--[[
Author: Kılıçarslan SIMSIKI

Date Created: 30-05-2023
Date Modified: 31-05-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]


local uci = require("uci")

Site = {}
local cursor = uci.cursor()


function Site.Get_site()
    return cursor:get("site", "router_site", "name")
end

function Site.Set_site(site)
    cursor:set("site", "router_site", "name", site)
    cursor:commit("site")
end