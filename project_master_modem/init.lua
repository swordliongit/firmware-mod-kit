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

dofile("/etc/project_master_modem/util.lua")

-- Check if packages were installed
local flagFile = "/etc/flag_packages_installed"

-- Check internet
local pingIp = "8.8.8.8"

function MASTER_CHECK(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        local errorMsg = "Error: " .. result
        local backupLog = io.open("/etc/project_master_modem/master_init.log", "a")
        io.output(backupLog)
        io.write(errorMsg .. "\n")
        io.close(backupLog)
    end
end

--[[
    EXECUTION START
]]
MASTER_CHECK(function()
    WriteLog(client .. "LOG START")
end)

-- Power button red. It will turn green if we can read/write into Odoo.
-- DHCP PASS BLOCK
MASTER_CHECK(function()
    WriteLog(client .. "{DHCP PASS BLOCK}")
    os.execute("echo 1 > /sys/class/leds/richerlink:green:system/brightness")
    EnableDhcpPass()
    BootChecker()
end)

-- UDHCPC Clear Block
MASTER_CHECK(function()
    WriteLog(client .. "{UDHCPC CLEAR BLOCK}")
    os.execute("killall udhcpc")
    os.execute("sleep 1")
end)

-- Static IP Clear Block
MASTER_CHECK(function()
    WriteLog(client .. "{STATIC IP CLEAR BLOCK}")
    if DhcpOn() then
        ClearIpOnBridge()
        WriteLog(client .. "DHCPC IP cleared")
    end
    os.execute("sleep 1")
    ExecuteAndWait("/etc/init.d/network restart")
end)

-- UDHCPC Start Block
MASTER_CHECK(function()
    WriteLog(client .. "{UDHCPC START BLOCK}")
    local cable_fallback_counter = 5
    while not HasInternet(pingIp) do
        WriteLog(client .. "Trying to get ip")
        if IsInterfacePluggedIn("eth1_0") then
            StartUdhcpc()
            os.execute("sleep 5")
            if not HasInternet(pingIp) then
                os.execute("killall udhcpc")
            end
        else
            WriteLog(client .. "Internet Cable Unplugged on Eth1_0!")
            if cable_fallback_counter >= 30 then
                -- cable not fixed, reboot
                os.execute("reboot")
            end
            cable_fallback_counter = cable_fallback_counter + 2
        end
        os.execute("sleep " .. cable_fallback_counter)
    end
    cable_fallback_counter = 5
    WriteLog(client .. "Connection Established using UDHCPC")
end)


MASTER_CHECK(function()
    AddIpToBridge()
end)

-- Package Installation and Main Loop Init Block
MASTER_CHECK(function()
    WriteLog(client .. "{PACKAGE INSTALLATION AND LAUNCH BLOCK}")
    if HasInternet(pingIp) then
        -- Get the time for the device
        os.execute("ntpd -p 176.235.250.150")
        os.execute("sleep 1")
        os.execute("/etc/init.d/sysntpd start")

        local flagExists = io.open(flagFile) ~= nil
        if flagExists then
            WriteLog(client .. "before lua init - flag on")
            -- Execute odoo_bridge.lua and capture errors to script.log
            local success, error_message = pcall(dofile, "/etc/project_master_modem/odoo_bridge.lua")

            -- Log any error messages
            if not success then
                WriteLog(bridge .. "Error in odoo_bridge.lua: " .. error_message)
                if error_message:match("not enough memory") then
                    os.execute("/etc/project_master_modem/clear_log.sh")
                    WriteLog(bridge .. "Log trimmed, rebooting...")
                else
                    WriteLog(bridge .. "Rebooting...")
                end
                os.execute("sleep 2")
                os.execute("reboot")
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
            WriteLog(client .. "before lua init - flag off")
            -- Execute odoo_bridge.lua and capture errors to script.log
            local success, error_message = pcall(dofile, "/etc/project_master_modem/odoo_bridge.lua")

            -- Log any error messages
            if not success then
                WriteLog(bridge .. "Error in odoo_bridge.lua: " .. error_message)
                if error_message:match("not enough memory") then
                    os.execute("/etc/project_master_modem/clear_log.sh")
                    WriteLog(bridge .. "Log trimmed, rebooting...")
                else
                    WriteLog(bridge .. "Rebooting...")
                end
                os.execute("sleep 2")
                os.execute("reboot")
            end
        end
    end
end)
