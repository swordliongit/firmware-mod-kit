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
    local used_percent = (used / total) * 100

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
            local load1_percent = load1 * 100
            local load5_percent = load5 * 100
            local load15_percent = load15 * 100

            -- print("1-Minute Load Average: " .. load1_percent .. "%")
            -- print("5-Minute Load Average: " .. load5_percent .. "%")
            -- print("15-Minute Load Average: " .. load15_percent .. "%")
            return load1_percent
        else
            io.write("\n\nFailed to parse load averages.")
        end
    else
        io.write("\n\nUnable to open /proc/loadavg")
    end
end

function System.base64_encode(data)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do
            r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')
        end
        return r;
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then
            return ''
        end
        local c = 0
        for i = 1, 6 do
            c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0)
        end
        return b:sub(c + 1, c + 1)
    end) .. (data:len() % 3 == 1 and '==' or (data:len() % 3 == 2 and '=' or '')))
end

function System.Get_log()
    -- Attempt to open the log file
    local file = io.open("/tmp/script.log", "r")
    if not file then
        return "Error: Log file not found or cannot be opened."
    end

    local log_lines = {}
    local max_lines = 1000

    -- Read all lines into a table
    for line in file:lines() do
        table.insert(log_lines, line)
    end

    -- Calculate the number of lines to return
    local num_lines = #log_lines
    local start_index = math.max(num_lines - max_lines + 1, 1)

    -- Retrieve the last lines
    local last_lines = table.concat(log_lines, "\n", start_index, num_lines)

    -- Close the file
    file:close()

    return last_lines
end

-- Function to read the execution time
function System.Get_ScriptExecutionTime()
    -- Define the path to the execution time file
    local execution_time_file = "/tmp/script_execution_time.txt"
    local file = io.open(execution_time_file, "r")
    if file then
        local execution_time = file:read("*l")
        file:close()
        return tostring(execution_time)
    else
        return "Execution time not found"
    end
end
