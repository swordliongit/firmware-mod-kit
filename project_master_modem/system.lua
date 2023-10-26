--[[
Author: Kılıçarslan SIMSIKI

Date Created: 17-10-2023
Date Modified: 17-10-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]


System = {}

function System.Get_ram()
    local sys = require("luci.sys")

    local output = sys.exec("free -m")

    local total, used, free = output:match("Mem:%s*(%d+)%s*(%d+)%s*(%d+)")

    -- Calculate the used RAM as a percentage
    local used_percent = (used / total)

    -- Format the percentage to two decimal places
    local formatted_percentage = string.format("%.2f", used_percent)
    return formatted_percentage
end

function System.Get_cpu()
    local file = io.open("/proc/loadavg", "r")
    if file then
        local loadavg = file:read("*all")
        file:close()
        local load1, load5, load15 = loadavg:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
        if load1 and load5 and load15 then
            -- Calculate load averages as percentages
            local load1_percent = load1
            local load5_percent = load5
            local load15_percent = load15

            -- print("1-Minute Load Average: " .. load1_percent .. "%")
            -- print("5-Minute Load Average: " .. load5_percent .. "%")
            -- print("15-Minute Load Average: " .. load15_percent .. "%")
            return load1_percent
        else
            WriteLog("Failed to parse load averages.")
        end
    else
        WriteLog("Unable to open /proc/loadavg")
    end
end
