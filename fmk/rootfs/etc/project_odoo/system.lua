--[[
Author: Kılıçarslan SIMSIKI

Date Created: 17-10-2023
Date Modified: 17-10-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]


System = {}

function System.Get_ram()
    local logFile = io.open("/tmp/script.log", "a")
    io.output(logFile)
    local sys = require("luci.sys")

    local output = sys.exec("free -m")

    local total, used, free = output:match("Mem:%s*(%d+)%s*(%d+)%s*(%d+)")

    -- Calculate the used RAM as a percentage
    local used_percent = (used / total) * 100

    -- Format the percentage to two decimal places
    local formatted_percentage = string.format("%.2f", used_percent)
    return formatted_percentage
end

function System.Get_cpu()
    local logFile = io.open("/tmp/script.log", "a")
    io.output(logFile)
    local file = io.open("/proc/loadavg", "r")
    if file then
        local loadavg = file:read("*all")
        file:close()
        local load1, load5, load15 = loadavg:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
        if load1 and load5 and load15 then
            -- Calculate load averages as percentages
            local load1_percent = load1 * 100
            local load5_percent = load5 * 100
            local load15_percent = load15 * 100

            -- print("1-Minute Load Average: " .. load1_percent .. "%")
            -- print("5-Minute Load Average: " .. load5_percent .. "%")
            -- print("15-Minute Load Average: " .. load15_percent .. "%")
            return load1_percent
        else
            io.write("Failed to parse load averages.")
        end
    else
        io.write("Unable to open /proc/loadavg")
    end
end

function System.Get_log()
    -- Read the last 200 lines of the log file
    local file = io.open("/tmp/script.log", "r")
    local log_text = ""

    if file then
        local lines = {}
        local line_count = 0

        -- Read the file line by line
        for line in file:lines() do
            line_count = line_count + 1
            lines[line_count] = line

            -- If we have read more than 200 lines, remove the oldest line
            if line_count > 200 then
                table.remove(lines, 1)
            end
        end

        -- Convert the list of log lines into a single string
        log_text = table.concat(lines, "\n")

        -- Close the file
        file:close()

        return log_text
    end
end
