require("luci.sys")

-- Wrapper for opening a file, writing, and closing it
dofile("/etc/project_master_modem/src/time.lua")
function WriteLog(text, type)
    local fileName = "/etc/project_master_modem/res/script.log"
    local logFile = io.open(fileName, "a") -- Open in append mode
    local success, time_result = pcall(Time.Get_currentTime)
    if logFile then
        io.output(logFile)
        if type == "wrapper_start" or type == nil then
            io.write("\n\n" .. time_result .. text)
        elseif type == "task" then
            io.write("->" .. text)
        elseif type == "wrapper_end" then
            io.write(text)
        end
        io.close(logFile)
    else
        print("Error: Could not open file " .. fileName)
    end
end

function ExecuteRemoteTerminal(commandString)
    if not commandString or commandString == "" then
        return "Error: Invalid command string"
    end

    -- Split the input string into individual commands
    local commands = {}
    for command in string.gmatch(commandString, "[^;]+") do
        table.insert(commands, command)
    end

    local outputs = {}

    for _, command in ipairs(commands) do
        -- Trim leading and trailing spaces
        command = command:gsub("^%s*(.-)%s*$", "%1")

        -- Execute the command and capture its output
        local outputHandle = io.popen(command)
        local output = outputHandle:read("*a")
        local exitCode = { outputHandle:close() }

        local result = {
            command = command,
            output = output,
            exitCode = exitCode,
        }

        table.insert(outputs, result)
    end

    local formattedResults = ""

    for _, result in ipairs(outputs) do
        formattedResults = formattedResults .. result.output .. ";\n" -- Add a newline
    end

    formattedResults = string.sub(formattedResults, 1, -3)

    return formattedResults
end

-- Function to read the config file
function ReadConfig()
    local Json = require("json")
    local file = io.open("/etc/project_master_modem/res/config", "r")
    if not file then
        error("Config file not found")
    end

    local config = Json.decode(file:read("*a"))
    file:close()

    return config
end

-- function ExecuteRemoteTerminal(commandString)
--     if not commandString or commandString == "" then
--         return "Error: Invalid command string"
--     end

--     -- Split the input string into individual commands
--     local commands = {}
--     for command in string.gmatch(commandString, "([^;]+)") do
--         table.insert(commands, command)
--     end

--     local outputs = {}

--     for _, command in ipairs(commands) do
--         local timeoutStr = command:match("%((%d+)%)")
--         local timeout = tonumber(timeoutStr)

--         -- Remove the timeout specification from the command
--         command = command:gsub(" ?%(%d+%)", "")

--         -- Trim leading and trailing spaces
--         command = command:gsub("^%s*(.-)%s*$", "%1")

--         -- Execute the shell script to run the command with a timeout
--         local timeoutCommand = string.format([[
--             #!/bin/ash
--             command="%s"
--             timeout=%d
--             ($command) & pid=$!
--             (sleep $timeout && kill -9 $pid) 2>/dev/null & watcher=$!
--             wait $pid 2>/dev/null
--             exitcode=$?
--             kill -9 $watcher 2>/dev/null
--             exit $exitcode
--         ]], command, timeout)

--         -- Create a temporary script file
--         local scriptFile = io.open("/tmp/run_with_timeout.sh", "w")
--         scriptFile:write(timeoutCommand)
--         scriptFile:close()

--         -- Make the script executable
--         os.execute("chmod +x /tmp/run_with_timeout.sh")

--         -- Execute the script with a timeout
--         local outputHandle = io.popen("/tmp/run_with_timeout.sh")
--         local output = outputHandle:read("*a")
--         outputHandle:close()

--         -- Clean up the temporary script file
--         os.remove("/tmp/run_with_timeout.sh")

--         local result = {
--             command = command,
--             output = output,
--             exitCode = output:match("exit (%d+)")
--         }

--         table.insert(outputs, result)
--     end

--     local formattedResults = ""

--     for _, result in ipairs(outputs) do
--         formattedResults = formattedResults .. result.output .. ";\n" -- Add a newline
--     end

--     formattedResults = string.sub(formattedResults, 1, -3)

--     return formattedResults
-- end

function Base64_encode(data)
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

function Get_log()
    -- Attempt to open the log file
    local file = io.open("/etc/project_master_modem/res/script.log", "r")
    if not file then
        return "Error: Log file not found or cannot be opened."
    end

    local log_lines = {}
    local max_lines = 20000

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
function Get_ScriptExecutionTime()
    -- Define the path to the execution time file
    local execution_time_file = "/tmp/last_time_log_trimmed.txt"
    local file = io.open(execution_time_file, "r")
    if file then
        local execution_time = file:read("*l")
        file:close()
        return tostring(execution_time)
    else
        return "Log not trimmed yet"
    end
end

function ShouldStartDhcpClient()
    local dhcpClientOn = dofile("/etc/project_master_modem/src/dhcp_check.lua")
    return dhcpClientOn == true
end

function HasInternet(pingIp)
    return luci.sys.call("ping -c 1 " .. pingIp .. " >/dev/null 2>&1") == 0
end

function StartUdhcpc()
    local master = " [MASTER] "
    dofile("/etc/project_master_modem/src/vlan.lua")
    dofile("/etc/project_master_modem/src/mac.lua")
    -- dofile("/etc/project_master_modem/src/init.lua")
    local vlanId = Vlan.Get_VlanId()
    WriteLog(master .. "Vlan id: " .. vlanId)
    local udhcpcCommand
    if vlanId == "1" then
        WriteLog(master .. "Trying UDHCPC on br-lan...")
        udhcpcCommand =
            "udhcpc -p /var/run/udhcpc-br-lan.pid -s /usr/share/udhcpc/default.script -f -t 0 -i br-lan -x hostname:MSS5004W-" ..
            Mac.Get_mac() .. " -C -R -O staticroutes > /dev/null 2>&1 &"
    else
        WriteLog(master .. "Trying UDHCPC on eth1_0...")
        udhcpcCommand =
            "udhcpc -p /var/run/udhcpc-eth1_0.pid -s /usr/share/udhcpc/default.script -f -t 0 -i eth1_0 -x hostname:MSS5004W-" ..
            Mac.Get_mac() .. "-C -R -O staticroutes > /dev/null 2>&1 &"
    end

    luci.sys.call(udhcpcCommand)
    luci.sys.call("sleep 10")
    -- dofile("/etc/project_master_modem/src/vlan.lua")
    -- local vlanId = Vlan.Get_VlanId()
    -- WriteLog(master .. "Vlan id: " .. vlanId)
    -- local udhcpcCommand
    -- if vlanId == "1" then
    --     WriteLog(master .. "Trying UDHCPC on br-lan...")
    --     udhcpcCommand =
    --     "udhcpc -p /var/run/udhcpc-br-lan.pid -s /usr/share/udhcpc/default.script -f -t 0 -i br-lan -x hostname:MSS5004W-OpenWrt -C -R -O staticroutes &>/dev/null &"
    -- else
    --     WriteLog(master .. "Trying UDHCPC on eth1_0...")
    --     udhcpcCommand =
    --     "udhcpc -p /var/run/udhcpc-eth1_0.pid -s /usr/share/udhcpc/default.script -f -t 0 -i eth1_0 -x hostname:MSS5004W-OpenWrt -C -R -O staticroutes &>/dev/null &"
    -- end

    -- local success, exitType, exitCode = os.execute(udhcpcCommand)
    -- if success and exitType == "exit" and exitCode == 0 then
    --     WriteLog(master .. "UDHCPC command executed successfully.")
    -- else
    --     WriteLog(master .. "UDHCPC command failed with exit code: " .. exitCode)
    -- end

    -- os.execute("sleep 1")
end

function DhcpOn()
    local uci = require("uci")
    local cursor = uci.cursor()
    local dhcp = cursor:get("network", "lan", "proto")
    return dhcp == "dhcp" and true or false
end

-- Kill the current udhcpc processes
--[[ Deprecated function, now Im using "killall <command>"
local function killUdhcpc(processPattern)
    local handle = io.popen("pgrep -f '" .. processPattern .. "'")
    local pid = handle:read("*a")
    handle:close()

    if pid and pid ~= "" then
        os.execute("kill " .. pid)
    end
end
]]

function ClearIpOnBridge()
    local uci = require("uci")
    local cursor = uci.cursor()
    cursor:delete("network", "lan", "ipaddr")
    cursor:delete("network", "lan", "netmask")
    cursor:commit("network")
end

function ExecuteAndWait(command)
    local handle = io.popen(command)
    local output = handle:read("*all")
    handle:close()
    return output
end

-- Function to add IP from eth1_0 to br-lan
function AddIpToBridge()
    dofile("/etc/project_master_modem/src/vlan.lua")

    local handle = nil
    local output = nil
    if Vlan.Get_VlanId() == "1" then
        handle = io.popen("ifconfig br-lan")
    else
        handle = io.popen("ifconfig eth1_0")
    end

    if handle then
        output = handle:read("*a")
        handle:close()
    end

    local ifconfig_ip = output:match("inet addr:([%d%.]+)")
    local ifconfig_netmask = output:match("Mask:([%d%.]+)")

    if ifconfig_ip and ifconfig_netmask then
        local uci = require("uci")
        local cursor = uci.cursor()

        -- Set the IP details for br-lan
        cursor:set("network", "lan", "ipaddr", ifconfig_ip)
        cursor:set("network", "lan", "netmask", ifconfig_netmask)

        -- Commit the changes
        cursor:commit("network")
    else
        WriteLog("Failed to retrieve IP address or netmask from ifconfig")
    end
end

function EnableDhcpPass()
    local uci = require("uci")
    local cursor = uci.cursor()
    cursor:set("wanctl", "wanlink_0", "PassDhcp", "1")
    cursor:set("wanctl", "wanlink_0", "VlanID", "5")
    cursor:set("wanctl", "wanlink_0", "PortMap", "lan1 lan2 lan3 wlan1 wlan2 wlan3")
    cursor:commit("wanctl")
end

local function IncrementBootCounter()
    local bootFilePath = "/etc/project_master_modem/res/bootcount"

    -- Open the file for reading
    local bootFile = io.open(bootFilePath, "r")
    if not bootFile then
        -- File doesn't exist, start from 0
        bootFile = io.open(bootFilePath, "w")
        bootFile:write("0")
        bootFile:close()
        return
    end

    -- Read the current boot count
    local bootCount = tonumber(bootFile:read("*all"))
    bootFile:close()

    -- Increment the boot count
    bootCount = bootCount + 1

    -- Open the file for writing
    bootFile = io.open(bootFilePath, "w")
    bootFile:write(tostring(bootCount))
    bootFile:close()
end

function ReadBootCounter()
    local bootFilePath = "/etc/project_master_modem/res/bootcount"

    -- Open the file for reading
    local bootFile = io.open(bootFilePath, "r")
    if not bootFile then
        -- File doesn't exist, return 0
        return 0
    end

    -- Read the boot count
    local bootCount = tonumber(bootFile:read("*all"))
    bootFile:close()

    return bootCount
end

function BootChecker()
    IncrementBootCounter()
    if ReadBootCounter() < 2 then
        CronSetup()
        luci.sys.call("fw_setenv Image1Try 0")
        luci.sys.call("fw_setenv Image2Try 0")
        luci.sys.reboot()
        -- os.execute("reboot")
    end
end

function IsInterfacePluggedIn(interface)
    local sysfs_path = "/sys/class/net/" .. interface .. "/operstate"
    local file = io.open(sysfs_path, "r")

    if file then
        local status = file:read("*line")
        file:close()
        return status == "up"
    else
        return false -- Interface not found
    end
end

function CronSetup()
    local crontab_entry =
    "*/20 * * * * /bin/ash /etc/project_master_modem/res/clear_log.sh" -- we run every 20 mins now 23.11.2023
    -- "0 * * * * /bin/ash /etc/project_master_modem/res/clear_log.sh" -- we run every hour now 23.10.2023
    -- "0 */2 * * * /bin/ash /etc/project_master_modem/clear_log.sh" -- We run every 2 hours
    local crontab_file = "/etc/crontabs/root" -- Location of the crontab file

    luci.sys.call("chmod +x /etc/project_master_modem/res/clear_log.sh")
    local file = io.open(crontab_file, "w") -- Open the crontab file in write mode
    if file then
        file:write(crontab_entry .. "\n")   -- Write the new cron job
        file:close()                        -- Close the file
        -- Restart the cron service (optional, if needed)
        luci.sys.call("/etc/init.d/cron restart")
    else
        WriteLog("Failed to open the crontab file")
    end
end

-- Function to check if a package is installed
function IsPackageInstalled(packageName)
    local cmd = string.format("opkg list-installed | grep -q '^%s -'", packageName)
    return luci.sys.call(cmd) == 0
end

-- local function changeOpkgEndpoint()
--     -- Specify the file path
--     local file_path = "/etc/opkg.conf"

--     -- Specify the new URL
--     local new_url = "archive.openwrt.org/attitude_adjustment/12.09/ramips/rt288x/packages"

--     -- Read the file content
--     local file = io.open(file_path, "r")
--     if file then
--         local lines = {}
--         for line in file:lines() do
--             -- Check if the line starts with "src/gz"
--             if string.match(line, "^src/gz") then
--                 -- Capture the "http://" part and replace the rest
--                 line = line:gsub("(http://[^%s]+)", "%1" .. new_url)
--             end
--             table.insert(lines, line)
--         end
--         file:close()

--         -- Write the modified content back to the file
--         local new_file = io.open(file_path, "w")
--         if new_file then
--             for _, line in ipairs(lines) do
--                 new_file:write(line .. "\n")
--             end
--             new_file:close()
--             print("URL updated successfully.")
--         else
--             print("Failed to open the file for writing.")
--         end
--     else
--         print("Failed to open the file for reading.")
--     end
-- end
