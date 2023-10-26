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
    -- Sample current time in the format you provided
    local current_time_str = os.date("%c")

    -- Define a table to map month names to month numbers
    local months = {
        Jan = "01",
        Feb = "02",
        Mar = "03",
        Apr = "04",
        May = "05",
        Jun = "06",
        Jul = "07",
        Aug = "08",
        Sep = "09",
        Oct = "10",
        Nov = "11",
        Dec = "12"
    }

    -- Extract the date and time components
    local day, month, day_num, time, year = current_time_str:match("(%a+) (%a+) (%d+) (%d+:%d+:%d+) (%d+)")

    -- Convert the month name to a number
    local month_num = months[month]

    -- Parse the time components (hours, minutes, and seconds)
    local hours, minutes, seconds = time:match("(%d+):(%d+):(%d+)")

    -- Add 3 hours and 50 minutes
    hours = tonumber(hours) + 3
    minutes = tonumber(minutes)

    -- Ensure minutes do not exceed 59 and handle carryover
    if minutes >= 60 then
        hours = hours + 1
        minutes = minutes - 60
    end

    -- Create a new time string with the adjusted time
    local new_time = string.format("%s.%s.%s %02d:%02d:%02d", day_num, month_num, year, hours, minutes, seconds)

    return "[" .. new_time .. "]"
end
