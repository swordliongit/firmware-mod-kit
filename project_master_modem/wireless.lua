--[[
Author: Kılıçarslan SIMSIKI

Date Created: 20-05-2023
Date Modified: 23-05-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]


local uci = require("uci")

Wireless = {}
local cursor = uci.cursor()

function Wireless.Get_wireless_status()
    local status = cursor:get("wireless", "wifi_ctrl_0", "enabled")
    return status == "1" and true or false
end

function Wireless.Set_wireless_status(wireless)
    cursor:set("wireless", "wifi_ctrl_0", "enabled", wireless)
    cursor:commit("wireless")
end

function Wireless.Get_wireless_channel()
    local channel = cursor:get("wireless", "RT5392AP", "channel")
    return channel == "0" and "auto" or channel
end

function Wireless.Set_wireless_channel(channel)
    cursor:set("wireless", "RT5392AP", "channel", channel)
    cursor:commit("wireless")
end
