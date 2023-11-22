--[[
    Daily logs:
    ...
]]

--[[
    Description:

    First boot -> Enable DHCP pass
    -> Reboot -> Clear static Ip -> Restart Network
    -> Start UDHCPC -> Set Dummy Ip -> Install Packages -> Start Bridging
]]

--[[
    Field Definitions
]]
_G.server = " [SERVER] "
_G.client = " [MSS5004W] "
_G.bridge = " [BRIDGE] "
_G.master = " [MASTER] "

dofile("/etc/project_master_modem/src/util.lua")
require("luci.sys")

-- Check if packages were installed
local flagFile = "/etc/flag_packages_installed"

-- Check internet
local pingIp = "8.8.8.8"

function MASTER_CHECK(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        local errorMsg = "Error: " .. result
        local backupLog = io.open("/etc/project_master_modem/res/master_init.log", "a")
        io.output(backupLog)
        io.write(errorMsg .. "\n")
        io.close(backupLog)
    end
end

function PIALB()
    if HasInternet(pingIp) then
        -- Get the time for the device
        luci.sys.call("ntpd -p 176.235.250.150")
        luci.sys.call("sleep 1")
        luci.sys.call("/etc/init.d/sysntpd start")

        local flagExists = io.open(flagFile) ~= nil
        if flagExists then
            WriteLog(master .. "before lua init - flag on")
            -- Execute odoo_bridge.lua and capture errors to script.log
            local success, result = pcall(dofile, "/etc/project_master_modem/src/odoo_bridge.lua")
            -- WriteLog(master .. " " .. tostring(success) .. " " .. tostring(result))

            -- Log any error messages
            if not success then
                WriteLog(master .. "Error in odoo_bridge.lua: " .. result)
                if result:match("not enough memory") then
                    luci.sys.call("/etc/project_master_modem/res/clear_log.sh")
                    WriteLog(master .. "Log trimmed, rebooting...")
                    luci.sys.call("sleep 2")
                    return true
                else
                    WriteLog(master .. result)
                    return false
                end
            else
                if result then
                    WriteLog(master .. "Elevating reboot signal to Initiator")
                    return true
                end
            end
        else
            local packages_installed = false
            local luas_installed = false
            local json4_installed = false
            local PIALB_retry_counter = 0
            repeat
                if IsPackageInstalled("luasocket") then
                    luas_installed = true
                else
                    luas_installed = false
                    WriteLog(master .. "Trying to install luasocket...")
                    luci.sys.call("opkg update")
                    luci.sys.call("opkg install luasocket")
                end
                if IsPackageInstalled("json4lua") then
                    json4_installed = true
                else
                    json4_installed = false
                    WriteLog(master .. "Trying to install json4lua...")
                    luci.sys.call("opkg update")
                    luci.sys.call(
                        "wget -P /tmp http://81.0.124.218/chaos_calmer/15.05.1/ramips/rt288x/packages/packages/json4lua_0.9.53-1_ramips.ipk")
                    luci.sys.call("opkg install /tmp/json4lua_0.9.53-1_ramips.ipk")
                    os.remove("/tmp/json4lua_0.9.53-1_ramips.ipk")
                end
                if json4_installed and luas_installed then
                    packages_installed = true
                else
                    packages_installed = false
                    PIALB_retry_counter = PIALB_retry_counter + 1
                end
                if PIALB_retry_counter == 5 then
                    WriteLog(master .. "Aborting Package Installation, rebooting...")
                    return true
                end
            until packages_installed
            WriteLog(master .. "Package installation successful!")


            io.open(flagFile, "w"):close()
            WriteLog(master .. "before lua init - flag off")
            -- Execute odoo_bridge.lua and capture errors to script.log
            local success, result = pcall(dofile, "/etc/project_master_modem/src/odoo_bridge.lua")
            -- WriteLog(master .. " " .. tostring(success) .. " " .. tostring(result))

            -- Log any error messages
            if not success then
                WriteLog(master .. "Error in odoo_bridge.lua: " .. result)
                if result:match("not enough memory") then
                    luci.sys.call("/etc/project_master_modem/res/clear_log.sh")
                    WriteLog(master .. "Log trimmed, rebooting...")
                    luci.sys.call("sleep 2")
                    return true
                else
                    WriteLog(master .. result)
                    return false
                end
            else
                if result then
                    WriteLog(master .. "Elevating reboot signal to Initiator")
                    return true
                end
            end
        end
    else
        return false
    end
end

--[[
    EXECUTION START
]]
MASTER_CHECK(function()
    WriteLog(master .. "LOG START")
end)

-- Power button red. It will turn green if we can read/write into Odoo.
-- DHCP PASS BLOCK
MASTER_CHECK(function()
    WriteLog(master .. "{DHCP PASS BLOCK}")
    luci.sys.call("echo 1 > /sys/class/leds/richerlink:green:system/brightness")
    EnableDhcpPass()
    BootChecker()
end)

-- UDHCPC Clear Block
MASTER_CHECK(function()
    WriteLog(master .. "{UDHCPC CLEAR BLOCK}")
    luci.sys.call("killall udhcpc")
    luci.sys.call("sleep 1")
end)

-- Static IP Clear Block
MASTER_CHECK(function()
    WriteLog(master .. "{STATIC IP CLEAR BLOCK}")
    if DhcpOn() then
        ClearIpOnBridge()
        WriteLog(master .. "DHCPC IP cleared")
    end
    luci.sys.call("sleep 1")
    ExecuteAndWait("/etc/init.d/network restart")
end)

-- UDHCPC Start Block
MASTER_CHECK(function()
    WriteLog(master .. "{UDHCPC START BLOCK}")
    local cable_fallback_counter = 5
    local udhcpc_fallback_counter = 0
    while not HasInternet(pingIp) do
        WriteLog(master .. "Trying to get ip")
        if IsInterfacePluggedIn("eth1_0") then
            StartUdhcpc()
            if not HasInternet(pingIp) then
                WriteLog(master .. "No IP from Upstream. UDHCPC Backoff Activated!")
                luci.sys.call("killall udhcpc")
                udhcpc_fallback_counter = udhcpc_fallback_counter + 1
                luci.sys.call("sleep 5")
            end
        else
            WriteLog(master .. "Internet Cable Unplugged on Eth1_0. Cable Backoff Activated!")
            if cable_fallback_counter >= 40 then
                -- cable not fixed, reboot
                luci.sys.reboot()
            end
            cable_fallback_counter = cable_fallback_counter + 2
            luci.sys.call("sleep " .. cable_fallback_counter)
        end
        if udhcpc_fallback_counter >= 4 then
            WriteLog(master .. "UDHCPC Backoff Rebooting...")
            luci.sys.reboot()
        end
    end
    WriteLog(master .. "Connection Established using UDHCPC")
end)

MASTER_CHECK(function()
    AddIpToBridge()
end)

-- Package Installation and Launch Block
MASTER_CHECK(function()
    WriteLog(master .. "{PACKAGE INSTALLATION AND LAUNCH BLOCK}")
    local pialb_fallback = 0
    local state
    repeat
        state = PIALB()
        if not state then
            WriteLog(master .. "PIALB Fallback activated!")
            pialb_fallback = pialb_fallback + 1
            luci.sys.call("sleep " .. pialb_fallback)
        else
            WriteLog(master .. "Reboot signal received from PIALB()")
            break -- Reboot signal received
        end
    until pialb_fallback == 5
    if pialb_fallback == 5 then
        WriteLog(master .. "Error in PIALB() tree, exiting...")
        return false
    end
    WriteLog(master .. "Rebooting...")
    WriteLog(bridge .. "CYCLE ------------}")
    luci.sys.reboot() -- 5 tries done, no success OR reboot signal received from child processes
end)
