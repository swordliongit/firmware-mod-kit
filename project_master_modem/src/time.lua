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

function Time.Get_currentTime()
    -- Get the current time in seconds since the epoch
    local os_time = os.time()

    -- Add 3 hours (3 * 3600 seconds) to adjust for the timezone
    os_time = os_time + 3 * 3600

    -- Convert to a table to extract date and time components
    local time_table = os.date("*t", os_time)

    -- Adjust day, month, and year if adding 3 hours exceeds 24 hours
    if time_table.hour >= 24 then
        time_table.hour = time_table.hour - 24
        time_table.day = time_table.day + 1
    end

    -- Convert the adjusted time back to a date string in the desired format
    local new_time_str = string.format("%02d.%02d.%04d %02d:%02d:%02d",
        time_table.day, time_table.month, time_table.year,
        time_table.hour, time_table.min, time_table.sec)

    return "[" .. new_time_str .. "]"
end
