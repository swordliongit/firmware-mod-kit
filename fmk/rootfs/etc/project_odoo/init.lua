--[[
    Daily logs:
    ...
]]

--[[
    DEFINITIONS
]]
-- Set output log file
local logFile = io.open("/tmp/script.log", "w")
io.output(logFile)

-- Check if packages were installed
local flagFile = "/etc/flag_packages_installed"

-- Check internet
local pingIP = "8.8.8.8"

-- Function to check if DHCP client should be started
local function shouldStartDhcpClient()
    local dhcpClientOn = dofile("/etc/project_odoo/dhcp_check.lua")
    return dhcpClientOn == true
end

local function hasInternet()
    return os.execute("ping -c 1 " .. pingIP .. " >/dev/null 2>&1") == 0
end

local function startUdhcpc()
    os.execute(
        "udhcpc -p /var/run/udhcpc-eth1_0.pid -s /usr/share/udhcpc/default.script -f -t 0 -i eth1_0 -x hostname:MSS5004W-OpenWrt -C -R -O staticroutes &>/dev/null &")
    os.execute("sleep 1")
end

local function dhcpOn()
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

local function clearIpOnBridge()
    local uci = require("uci")
    local cursor = uci.cursor()
    cursor:delete("network", "lan", "ipaddr")
    cursor:delete("network", "lan", "netmask")
    cursor:commit("network")
end

local function executeAndWait(command)
    local handle = io.popen(command)
    local output = handle:read("*all")
    handle:close()
    return output
end

-- Function to add IP from eth1_0 to br-lan
local function AddIpToBridge()
    local handle = io.popen("ifconfig eth1_0")
    local output = handle:read("*a")
    handle:close()

    local eth1_0_ip = output:match("inet addr:([%d%.]+)")
    local eth1_0_netmask = output:match("Mask:([%d%.]+)")

    if eth1_0_ip and eth1_0_netmask then
        local uci = require("uci")
        local cursor = uci.cursor()

        -- Set the IP details for br-lan
        cursor:set("network", "lan", "ipaddr", eth1_0_ip)
        cursor:set("network", "lan", "netmask", eth1_0_netmask)

        -- Commit the changes
        cursor:commit("network")
    else
        print("Failed to retrieve IP address or netmask from eth1_0")
    end
end

local function enableDhcpPass()
    local uci = require("uci")
    local cursor = uci.cursor()
    cursor:set("wanctl", "wanlink_0", "PassDhcp", "1")
    cursor:set("wanctl", "wanlink_0", "VlanID", "5")
    cursor:set("wanctl", "wanlink_0", "PortMap", "lan1 lan2 lan3 wlan1 wlan2 wlan3")
    cursor:commit("wanctl")
end

local function incrementBootCounter()
    local bootFilePath = "/etc/project_odoo/bootcount"

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

local function readBootCounter()
    local bootFilePath = "/etc/project_odoo/bootcount"

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

local function bootChecker()
    incrementBootCounter()
    if readBootCounter() < 2 then
        CronSetup()
        os.execute("reboot")
    end
end

local function isInterfacePluggedIn(interface)
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
    "0 */2 * * * /bin/ash /etc/project_odoo/clear_log.sh" -- We run every 2 hours
    local crontab_file = "/etc/crontabs/root"             -- Location of the crontab file

    os.execute("chmod +x /etc/project_odoo/clear_log.sh")
    local file = io.open(crontab_file, "w") -- Open the crontab file in write mode
    if file then
        file:write(crontab_entry .. "\n")   -- Write the new cron job
        file:close()                        -- Close the file
        -- Restart the cron service (optional, if needed)
        os.execute("/etc/init.d/cron restart")
    else
        io.write("Failed to open the crontab file")
    end
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

--[[
    EXECUTION START
]]

io.write("Log start\n")
io.write("Before killing the current udhcpc\n")

-- Power button red. It will turn green if we can read/write into Odoo.
os.execute("echo 1 > /sys/class/leds/richerlink:green:system/brightness")
enableDhcpPass()

-- UDHCPC Clear Block
os.execute("killall udhcpc")
io.write("After killing the current udhcpc\n")
os.execute("sleep 1")

-- Static IP Clear Block
if dhcpOn() then
    clearIpOnBridge()
    io.write("DHCPC IP cleared\n")
end
os.execute("sleep 1")
executeAndWait("/etc/init.d/network restart")

-- UDHCPC Start Block
io.write("Before ping loop\n")
while not hasInternet() do
    if isInterfacePluggedIn("eth1_0") then
        startUdhcpc()
        os.execute("sleep 5")
        if not hasInternet() then
            os.execute("killall udhcpc")
        end
    else
        io.write("Internet Cable Unplugged on Eth1_0!")
    end
    os.execute("sleep 2")
    io.write("Tried to get ip\n")
end
io.write("Connection Established using UDHCPC\n")

AddIpToBridge()

-- executeAndWait("/etc/init.d/network restart")
os.execute("sleep 1")

-- Package Installation and Main Loop Init Block
if hasInternet() then
    -- Get the time for the device
    os.execute("ntpd -p 176.235.250.150")
    os.execute("sleep 1")
    os.execute("/etc/init.d/sysntpd start")

    local flagExists = io.open(flagFile) ~= nil
    if flagExists then
        io.write("before lua init - flag on\n")

        bootChecker()
        -- Execute odoo_bridge.lua and capture errors to script.log
        local success, error_message = pcall(dofile, "/etc/project_odoo/odoo_bridge.lua")

        -- Log any error messages
        if not success then
            local logFile = io.open("/tmp/script.log", "a")
            io.output(logFile)
            io.write("Error in odoo_bridge.lua: " .. error_message .. "\n")
            io.close(logFile)
        end
    else
        -- luasocket & libopenssl
        -- changeOpkgEndpoint()
        os.execute("opkg update")
        os.execute("opkg install luasocket")
        os.execute("opkg update")
        -- os.execute(
        --     "wget -P /tmp http://81.0.124.218/attitude_adjustment/12.09/ramips/rt305x/packages/luasocket_2.0.2-3_ramips.ipk")
        os.execute(
            "wget -P /tmp http://81.0.124.218/chaos_calmer/15.05.1/ramips/rt288x/packages/packages/json4lua_0.9.53-1_ramips.ipk")
        -- os.execute(
        --     "wget -P /tmp http://81.0.124.218/attitude_adjustment/12.09/ramips/rt305x/packages/luafilesystem_1.5.0-1_ramips.ipk")
        -- os.execute(
        --     "wget -P /tmp http://81.0.124.218/attitude_adjustment/12.09/ramips/rt305x/packages/openssh-sftp-server_6.1p1-1_ramips.ipk")
        -- os.execute(
        --     "wget -P /tmp http://81.0.124.218/attitude_adjustment/12.09/ramips/rt305x/packages/openssh-keygen_6.1p1-1_ramips.ipk")
        -- os.execute(
        --     "wget -P /tmp http://81.0.124.218/attitude_adjustment/12.09/ramips/rt305x/packages/openssh-server_6.1p1-1_ramips.ipk")
        -- os.execute(
        --     "wget -P /tmp http://81.0.124.218/attitude_adjustment/12.09/ramips/rt305x/packages/luasec_0.4-1_ramips.ipk"
        -- )

        -- os.execute("opkg install /tmp/luasocket_2.0.2-3_ramips.ipk")
        os.execute("opkg install /tmp/json4lua_0.9.53-1_ramips.ipk")
        -- os.execute("opkg install /tmp/luafilesystem_1.5.0-1_ramips.ipk")
        -- os.execute("opkg install /tmp/openssh-sftp-server_6.1p1-1_ramips.ipk")
        -- os.execute("opkg install /tmp/openssh-keygen_6.1p1-1_ramips.ipk")
        -- os.execute("opkg install /tmp/openssh-server_6.1p1-1_ramips.ipk")
        -- os.execute("opkg install /tmp/luasec_0.4-1_ramips.ipk")

        -- os.remove("/tmp/luasocket_2.0.2-3_ramips.ipk")
        os.remove("/tmp/json4lua_0.9.53-1_ramips.ipk")
        -- os.remove("/tmp/luafilesystem_1.5.0-1_ramips.ipk")
        -- os.remove("/tmp/openssh-sftp-server_6.1p1-1_ramips.ipk")
        -- os.remove("/tmp/openssh-keygen_6.1p1-1_ramips.ipk")
        -- os.remove("/tmp/openssh-server_6.1p1-1_ramips.ipk")
        -- os.remove("/tmp/luasec_0.4-1_ramips.ipk")

        io.open(flagFile, "w"):close()
        io.write("before lua init - flag off\n")

        bootChecker()
        -- Execute odoo_bridge.lua and capture errors to script.log
        local success, error_message = pcall(dofile, "/etc/project_odoo/odoo_bridge.lua")

        -- Log any error messages
        if not success then
            local logFile = io.open("/tmp/script.log", "a")
            io.output(logFile)
            io.write("Error in odoo_bridge.lua: " .. error_message .. "\n")
            io.close(logFile)
        end
    end
end

io.close(logFile)
