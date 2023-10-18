--[[
Author: Kılıçarslan SIMSIKI

Date Created: 20-05-2023
Date Modified: 23-05-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]


Time = {}

function Time.Get_updatetime()
    -- Get the current timestamp
    local current_timestamp = os.time()

    -- Add 3 hours in seconds (3 hours * 3600 seconds/hour)
    local adjusted_timestamp = current_timestamp + 3 * 3600

    -- Format the adjusted timestamp
    local formatted_date = os.date("%d-%m-%Y %H:%M:%S", adjusted_timestamp)
    if formatted_date then
        return formatted_date
    else
        return "Failed to retrieve current time"
    end
end

-- function Time.Get_manualtime()
--     return os.date("%Y-%m-%d %H:%M:%S")
-- end

-- function Time.Set_manualtime(time)
--     local command = string.format("date -s '%s'", time)
--     os.execute(command)
-- end

function Time.Get_uptime()
    local luci_sys = require("luci.sys")

    local seconds = luci_sys.uptime()
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainingSeconds = seconds % 60

    local uptimeString = ""

    if hours > 0 then
        uptimeString = uptimeString .. hours .. "h "
    end

    if minutes > 0 then
        uptimeString = uptimeString .. minutes .. "m "
    end

    uptimeString = uptimeString .. remainingSeconds .. "s"

    return uptimeString
end
