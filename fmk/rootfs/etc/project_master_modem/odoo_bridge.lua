--[[
Author: Kılıçarslan SIMSIKI

Date Created: 20-05-2023
Date Modified: 10-08-2023

Description:
All modification and duplication of this software are forbidden and licensed under Apache.

Flow of the overall program:

Odoo_login
Odoo_write
loop:
    Odoo_execute <-- Odoo_parse <-- Odoo_read
    Odoo_write
]]

_G.cookie = "" -- global cookie
_G.Serror_backoff_counter = 0
_G.MAX_SERROR = 10
_G.Monitor = ""
-- local lfs = require("lfs")

-- -- Get the current working directory
-- local currentDirectory = lfs.currentdir()
-- io.write("\n" .. currentDirectory .. "\n")

Http = require("socket.http")
Ltn12 = require("ltn12")
Json = require("json")
dofile("/etc/project_master_modem/devices.lua")
dofile("/etc/project_master_modem/dhcp.lua")
dofile("/etc/project_master_modem/ip.lua")
dofile("/etc/project_master_modem/mac.lua")
dofile("/etc/project_master_modem/netmask.lua")
dofile("/etc/project_master_modem/password.lua")
dofile("/etc/project_master_modem/ssid.lua")
dofile("/etc/project_master_modem/time.lua")
dofile("/etc/project_master_modem/wireless.lua")
dofile("/etc/project_master_modem/site.lua")
dofile("/etc/project_master_modem/gateway.lua")
dofile("/etc/project_master_modem/sysupgrade.lua")
dofile("/etc/project_master_modem/name.lua")
dofile("/etc/project_master_modem/system.lua")
dofile("/etc/project_master_modem/vlan.lua")
dofile("/etc/project_master_modem/util.lua")

local Odoo_login = function()
    local body = {}

    local requestBody = Json.encode({
        ["jsonrpc"] = "2.0",
        ["params"] = {
            ["login"] = "admin",
            ["password"] = "Artin.modem",
            ["db"] = "modem"
        }
    })

    local res, code, headers, status = Http.request {
        method = "POST",
        url = "http://89.252.165.116:8069/web/session/authenticate",
        source = Ltn12.source.string(requestBody),
        headers = {
            ["content-type"] = "application/json",
            ["content-length"] = tostring(#requestBody)
        },
        sink = Ltn12.sink.table(body),
        protocol = "tlsv1_2"
    }

    local responseBody = table.concat(body)

    if code == 200 then
        -- Check for specific error conditions in the response body ( Odoo Server Error )
        if responseBody:find("Odoo Server Error") then
            -- Handle the server error condition here
            WriteLog(server .. "ERROR: " .. responseBody)
            if Serror_backoff_counter >= MAX_SERROR then
                Serror_backoff_counter = 0
                os.execute("reboot")
            end
            Serror_backoff_counter = Serror_backoff_counter + 1
            WriteLog(bridge ..
                "SERROR backoff activated! Rebooting in " .. tostring(MAX_SERROR - Serror_backoff_counter) .. " tries...")
        else
            _G.cookie = headers["set-cookie"]:match("(.-);")
            WriteLog(client .. cookie)
            Serror_backoff_counter = 0
        end
        return true
    else
        WriteLog(server .. "Failed to authenticate. HTTP code: " ..
            tostring(code) .. "\nResponse body:\n" .. responseBody)
        return false
    end
end


local Odoo_read = function()
    local body = {}

    local requestBody = Json.encode({
        ["id"] = 20,
        ["jsonrpc"] = "2.0",
        ["method"] = "call",
        ["params"] = {
            ["model"] = "modem.profile",
            ["domain"] = {
                { "x_mac", "=", Mac.Get_mac() }
            },
            ["fields"] = {
                "name",
                "x_site",
                -- "x_update_date",
                -- "x_uptime",
                "x_channel",
                -- "x_mac",
                -- "x_device_info",
                -- "x_ip",
                -- "x_subnet",
                -- "x_gateway",
                -- "x_dhcp_server",
                -- "x_dhcp_client",
                "x_enable_wireless",
                "x_ssid1",
                "x_passwd_1",
                "x_ssid2",
                "x_passwd_2",
                "x_ssid3",
                "x_passwd_3",
                -- "x_ssid4",
                -- "x_passwd_4",
                "x_enable_ssid1",
                "x_enable_ssid2",
                "x_enable_ssid3",
                -- "x_enable_ssid4",
                -- "x_manual_time",
                "x_new_password",
                "x_reboot",
                "x_upgrade",
                "x_vlanId",
                "x_terminal"
            },
            ["limit"] = 80,
            ["sort"] = "",
            ["context"] = {
                ["lang"] = "en_US",
                ["tz"] = "Europe/Istanbul",
                ["uid"] = 2,
                ["allowed_company_ids"] = { 1 },
                ["bin_size"] = true
            }
        }
    })
    WriteLog(client .. "Send " .. requestBody)

    local res, code, headers, status = Http.request {
        method = "POST",
        url = "http://89.252.165.116:8069/web/dataset/search_read",
        source = Ltn12.source.string(requestBody),
        headers = {
            ["content-type"] = "application/json",
            ["content-length"] = tostring(#requestBody),
            ["Cookie"] = _G.cookie
        },
        sink = Ltn12.sink.table(body),
        protocol = "tlsv1_2"
    }

    local responseBody = table.concat(body)

    if code == 200 then
        -- Check for specific error conditions in the response body ( Odoo Server Error )
        if responseBody:find("Odoo Server Error") then
            -- Handle the server error condition here
            WriteLog(server .. "ERROR: " .. responseBody)
            if Serror_backoff_counter >= MAX_SERROR then
                Serror_backoff_counter = 0
                os.execute("reboot")
            end
            Serror_backoff_counter = Serror_backoff_counter + 1
            WriteLog(bridge ..
                "SERROR backoff activated! Rebooting in " .. tostring(MAX_SERROR - Serror_backoff_counter) .. " tries...")
        else
            WriteLog(server .. responseBody)
            Serror_backoff_counter = 0
        end
        return true, responseBody
    else
        WriteLog(server ..
            "Failed to fetch data. HTTP code: " .. tostring(code) .. "\nResponse body:\n" .. responseBody)
        return false, responseBody
    end
end

local Odoo_parse = function(responseBody)
    local responseJson = Json.decode(responseBody)
    local records = responseJson.result.records
    local record = records[1]

    local name = record.name
    -- Access the individual field values inside the record
    local x_site = record.x_site[2] -- e.g [1, "artinsite"] <-- Many2One field
    local x_channel = record.x_channel
    -- local x_ip = record.x_ip
    -- local x_subnet = record.x_subnet
    -- local x_gateway = record.x_gateway
    -- local x_dhcp_server = record.x_dhcp_server
    -- local x_dhcp_client = record.x_dhcp_client
    local x_enable_wireless = record.x_enable_wireless
    local x_ssid1 = record.x_ssid1
    local x_passwd_1 = record.x_passwd_1
    local x_ssid2 = record.x_ssid2
    local x_passwd_2 = record.x_passwd_2
    local x_ssid3 = record.x_ssid3
    local x_passwd_3 = record.x_passwd_3
    -- local x_ssid4 = record.x_ssid4
    -- local x_passwd_4 = record.x_passwd_4
    local x_enable_ssid1 = record.x_enable_ssid1
    local x_enable_ssid2 = record.x_enable_ssid2
    local x_enable_ssid3 = record.x_enable_ssid3
    -- local x_enable_ssid4 = record.x_enable_ssid4
    -- local x_manual_time = record.x_manual_time
    local x_new_password = record.x_new_password
    local x_reboot = record.x_reboot
    local x_upgrade = record.x_upgrade
    local x_vlanId = record.x_vlanId
    local x_terminal = record.x_terminal

    local parsed_values = {
        ["name"] = name,
        ["x_site"] = x_site,
        ["x_channel"] = x_channel,
        -- ["x_ip"] = x_ip,
        -- ["x_subnet"] = x_subnet,
        -- ["x_gateway"] = x_gateway,
        -- ["x_dhcp_server"] = x_dhcp_server,
        -- ["x_dhcp_client"] = x_dhcp_client,
        ["x_enable_wireless"] = x_enable_wireless,
        ["x_ssid1"] = x_ssid1,
        ["x_passwd_1"] = x_passwd_1,
        ["x_ssid2"] = x_ssid2,
        ["x_passwd_2"] = x_passwd_2,
        ["x_ssid3"] = x_ssid3,
        ["x_passwd_3"] = x_passwd_3,
        -- ["x_ssid4"] = x_ssid4,
        -- ["x_passwd_4"] = x_passwd_4,
        ["x_enable_ssid1"] = x_enable_ssid1,
        ["x_enable_ssid2"] = x_enable_ssid2,
        ["x_enable_ssid3"] = x_enable_ssid3,
        -- ["x_enable_ssid4"] = x_enable_ssid4,
        -- ["x_manual_time"] = x_manual_time,
        ["x_new_password"] = x_new_password,
        ["x_reboot"] = x_reboot,
        ["x_upgrade"] = x_upgrade,
        ["x_vlanId"] = x_vlanId,
        ["x_terminal"] = x_terminal
    }

    -- for key, value in pairs(parsed_values) do
    --     print(key, value)
    -- end

    return parsed_values
end

local Odoo_execute = function(parsed_values)
    local luci_util = require("luci.util")
    local need_reboot = false
    local need_wifi_reload = false

    WriteLog(client .. "Execution Queue: [", "wrapper_start")
    for key, value in pairs(parsed_values) do
        if key == "name" and value ~= Name.Get_name() then
            WriteLog("Name", "task")
            Name.Set_name(value)
        end
        if key == "x_site" and value ~= Site.Get_site() then
            WriteLog("Site", "task")
            Site.Set_site(value)
        end
        if key == "x_channel" and value ~= Wireless.Get_wireless_channel() then
            WriteLog("Channel", "task")
            if value == "auto" then
                Wireless.Set_wireless_channel("0")
            else
                Wireless.Set_wireless_channel(value)
            end
            need_wifi_reload = true
        end
        -- if key == "x_dhcp_server" and value ~= Dhcp.Get_dhcp_server() then
        --     if value then
        --         Dhcp.Set_dhcp_server("1")
        --     else
        --         Dhcp.Set_dhcp_server("0")
        --     end
        --     need_reboot = true
        -- end
        -- if key == "x_ip" and value ~= LanIP.Get_Ip() then
        --     LanIP.Set_Ip(value)
        --     need_reboot = true
        -- end
        -- if key == "x_subnet" and value ~= Netmask.Get_netmask() then
        --     Netmask.Set_netmask(value)
        --     need_reboot = true
        -- end
        -- if key == "x_gateway" and value ~= Gateway.Get_gateway() then
        --     Gateway.Set_gateway(value)
        --     need_reboot = true
        -- end
        -- if key == "x_dhcp_client" and value ~= Dhcp.Get_dhcp_client() then
        --     if value then
        --         Dhcp.Set_dhcp_client("dhcp")
        --     else
        --         -- Find the process ID of udhcpc
        --         local pid_command = "pgrep -f 'udhcpc -t 0 -i br-lan -b -p /var/run/dhcp-br-lan.pid'"
        --         local handle = io.popen(pid_command)
        --         if handle then
        --             local pid = handle:read("*a")
        --             handle:close()
        --             -- Kill the udhcpc process if it is running
        --             if pid ~= "" then
        --                 local kill_command = "kill " .. pid
        --                 os.execute(kill_command)
        --             end
        --         end
        --         Dhcp.Set_dhcp_client("static")
        --     end
        --     need_reboot = true
        -- end
        if key == "x_enable_wireless" and value ~= Wireless.Get_wireless_status() then
            WriteLog("Wireless", "task")
            if value then
                Wireless.Set_wireless_status("1")
            else
                Wireless.Set_wireless_status("0")
            end
            need_wifi_reload = true
        end
        if key == "x_ssid1" and value ~= Ssid.Get_ssid1() then
            WriteLog("SSID1", "task")
            Ssid.Set_ssid1(value)
            need_wifi_reload = true
        end
        if key == "x_passwd_1" and value ~= Ssid.Get_ssid1_passwd() then
            WriteLog("PWD1", "task")
            Ssid.Set_ssid1_passwd(value)
            need_wifi_reload = true
        end
        if key == "x_ssid2" and value ~= Ssid.Get_ssid2() then
            WriteLog("SSID2", "task")
            Ssid.Set_ssid2(value)
            need_wifi_reload = true
        end
        if key == "x_passwd_2" and value ~= Ssid.Get_ssid2_passwd() then
            WriteLog("PWD2", "task")
            Ssid.Set_ssid2_passwd(value)
            need_wifi_reload = true
        end
        if key == "x_ssid3" and value ~= Ssid.Get_ssid3() then
            WriteLog("SSID3", "task")
            Ssid.Set_ssid3(value)
            need_wifi_reload = true
        end
        if key == "x_passwd_3" and value ~= Ssid.Get_ssid3_passwd() then
            WriteLog("PWD3", "task")
            Ssid.Set_ssid3_passwd(value)
            need_wifi_reload = true
        end
        -- if key == "x_ssid4" and value ~= Ssid.Get_ssid4() then
        --     Ssid.Set_ssid4(value)
        --     need_wifi_reload = true
        -- end
        -- if key == "x_passwd_4" and value ~= Ssid.Get_ssid4_passwd() then
        --     Ssid.Set_ssid4_passwd(value)
        --     need_wifi_reload = true
        -- end
        if key == "x_enable_ssid1" and value ~= Ssid.Get_ssid1_status() then
            WriteLog("ENSSID1", "task")
            if value then
                Ssid.Set_ssid1_status("1")
            else
                Ssid.Set_ssid1_status("0")
            end
            need_wifi_reload = true
        end
        if key == "x_enable_ssid2" and value ~= Ssid.Get_ssid2_status() then
            WriteLog("ENSSID2", "task")
            if value then
                Ssid.Set_ssid2_status("1")
            else
                Ssid.Set_ssid2_status("0")
            end
            need_wifi_reload = true
        end
        if key == "x_enable_ssid3" and value ~= Ssid.Get_ssid3_status() then
            WriteLog("ENSSID3", "task")
            if value then
                Ssid.Set_ssid3_status("1")
            else
                Ssid.Set_ssid3_status("0")
            end
            need_wifi_reload = true
        end
        -- if key == "x_enable_ssid4" and value ~= Ssid.Get_ssid4_status() then
        --     if value then
        --         Ssid.Set_ssid4_status("1")
        --     else
        --         Ssid.Set_ssid4_status("0")
        --     end
        --     need_wifi_reload = true
        -- end
        -- if key == "x_manual_time" and value ~= Time.Get_manualtime() then
        -- Time.Set_manualtime(value)
        -- end
        if key == "x_new_password" and value ~= false then
            WriteLog("NPWD", "task")
            Password.Set_LuciPasswd(value)
        end
        if key == "x_reboot" and value ~= false then
            WriteLog("Need Reboot", "task")
            need_reboot = true
        end
        if key == "x_upgrade" and value ~= false then
            WriteLog("Upgrade", "task")
            -- Ensure you're logged in before downloading
            -- if not _G.cookie or _G.cookie == "" then
            --     Odoo_login()
            -- end
            Sysupgrade.Upgrade()
        end
        if key == "x_vlanId" and value ~= Vlan.Get_VlanId() then
            WriteLog("Vlan", "task")
            Vlan.Set_VlanId(value)
            need_reboot = true
        end
        if key == "x_terminal" then
            if value ~= false then
                WriteLog("Terminal", "task")
                Monitor = ExecuteRemoteTerminal(value)
            end
        end
    end
    if need_wifi_reload then
        WriteLog("WIFI RELOAD", "task")
        luci_util.exec("/sbin/wifi")
    end
    if need_reboot then
        WriteLog("REBOOT", "task")
        os.execute("reboot")
    end
    WriteLog("]", "wrapper_end")
end

local Odoo_write = function()
    local body = {}

    local requestData = {
        ["name"] = Name.Get_name(),
        ["x_site"] = Site.Get_site(),
        -- ["x_device_update"] = false,
        -- ["x_update_date"] = Time.Get_updatetime(),  --> update time is now controlled through the web controller in Odoo server side
        ["x_uptime"] = Time.Get_uptime(),
        ["x_channel"] = Wireless.Get_wireless_channel(),
        ["x_mac"] = Mac.Get_mac(),
        ["x_device_info"] = Devices.Get_DevicesString(),
        ["x_ip"] = LanIP.Get_Ip(),
        ["x_subnet"] = Netmask.Get_netmask(),
        ["x_gateway"] = Gateway.Get_gateway(),
        -- ["x_dhcp_server"] = Dhcp.Get_dhcp_server(),
        -- ["x_dhcp_client"] = Dhcp.Get_dhcp_client(),
        ["x_enable_wireless"] = Wireless.Get_wireless_status(),
        ["x_ssid1"] = Ssid.Get_ssid1(),
        ["x_passwd_1"] = Ssid.Get_ssid1_passwd(),
        ["x_ssid2"] = Ssid.Get_ssid2(),
        ["x_passwd_2"] = Ssid.Get_ssid2_passwd(),
        ["x_ssid3"] = Ssid.Get_ssid3(),
        ["x_passwd_3"] = Ssid.Get_ssid3_passwd(),
        -- ["x_ssid4"] = Ssid.Get_ssid4(),
        -- ["x_passwd_4"] = Ssid.Get_ssid4_passwd(),
        ["x_enable_ssid1"] = Ssid.Get_ssid1_status(),
        ["x_enable_ssid2"] = Ssid.Get_ssid2_status(),
        ["x_enable_ssid3"] = Ssid.Get_ssid3_status(),
        -- ["x_enable_ssid4"] = Ssid.Get_ssid4_status(),
        ["x_lostConnection"] = false,
        ["x_ram"] = System.Get_ram(),
        ["x_cpu"] = System.Get_cpu(),
        ["x_log"] = Get_log(),
        ["x_vlanId"] = Vlan.Get_VlanId(),
        ["x_logTrunkExecTime"] = Get_ScriptExecutionTime(),
        ["x_monitor"] = Monitor
        -- ["x_manual_time"] = Time.Get_manualtime(),
        -- ["x_new_password"] = false,
        -- ["x_reboot"] = false,
        -- ["x_upgrade"] = false
    }

    local requestBody = Json.encode(requestData)
    -- Add excluded fields for logging purposes
    requestData["x_log"] = nil
    requestData["x_monitor"] = nil
    -- I need to exclude the log field
    local RequestBody_forPrint = Json.encode(requestData)

    WriteLog(client .. "Send " .. RequestBody_forPrint)

    local res, code, headers, status = Http.request({
        method = "POST",
        url = "http://89.252.165.116:8069/create/create_or_update_record",
        source = Ltn12.source.string(requestBody),
        headers = {
            ["content-type"] = "application/json",
            ["content-length"] = tostring(#requestBody),
            ["Cookie"] = _G.cookie
        },
        sink = Ltn12.sink.table(body),
        protocol = "tlsv1_2"
    })

    local responseBody = table.concat(body)

    if code == 200 then
        -- Check for specific error conditions in the response body ( Odoo Server Error )
        if responseBody:find("Odoo Server Error") then
            -- Handle the server error condition here
            WriteLog(server .. "ERROR: " .. responseBody)
            if Serror_backoff_counter >= MAX_SERROR then
                Serror_backoff_counter = 0
                os.execute("reboot")
            end
            Serror_backoff_counter = Serror_backoff_counter + 1
            WriteLog(bridge ..
                "SERROR backoff activated! Rebooting in " .. tostring(MAX_SERROR - Serror_backoff_counter) .. " tries...")
        else
            WriteLog(server .. responseBody)
            Serror_backoff_counter = 0
        end
        return true
    else
        WriteLog(server ..
            "Failed to post data. HTTP code: " .. tostring(code) .. "\nResponse body:\n" .. responseBody)
        return false
    end
end

-- local function Log_deleter()
--     local log_path = "/tmp/odoo_bridge.log"
--     -- Open the file in write mode and truncate it
--     local file = io.open(log_path, "w")
--     if file then
--         -- Truncate the file by writing an empty string
--         file:write("File cleared!")
--         file:close()
--     else
--         print("Failed to open file for clearing content")
--     end
-- end

function Odoo_Connector()
    local backoff_counter = 5
    local auth_completed = false
    local write_completed = false
    local read_completed = false
    local read_response = nil
    -- local flag_Logdeleter = 0
    -- Add the public IP
    -- LanIP.AddIpToBridge()
    -- Keep trying to login until successful

    backoff_counter = 5
    repeat
        auth_completed = Odoo_login()
        if auth_completed == false then
            WriteLog(bridge .. "Login backoff activated! Sleeping for " .. backoff_counter .. " seconds..")
            os.execute("echo 1 > /sys/class/leds/richerlink:green:system/brightness")
            os.execute("sleep " .. tostring(backoff_counter))
            backoff_counter = backoff_counter + 2
            if backoff_counter >= 30 then
                os.execute("reboot")
            end
        end
    until auth_completed
    os.execute("echo 0 > /sys/class/leds/richerlink:green:system/brightness")

    -- Keep trying to write ourselves into Odoo until successful
    backoff_counter = 5
    repeat
        write_completed = Odoo_write()
        if write_completed == false then
            WriteLog(bridge .. "Initial write backoff activated! Sleeping for " .. backoff_counter .. " seconds..")
            os.execute("echo 1 > /sys/class/leds/richerlink:green:system/brightness")
            os.execute("sleep " .. tostring(backoff_counter))
            backoff_counter = backoff_counter + 2
            if backoff_counter >= 30 then
                os.execute("reboot")
            end
        end
    until write_completed
    os.execute("echo 0 > /sys/class/leds/richerlink:green:system/brightness")

    write_completed = false

    -- Main program loop
    while true do
        os.execute("sleep 15")
        -- Keep trying to read data from Odoo until successful
        backoff_counter = 5 -- Defensive counter against continous error cycles
        repeat
            read_completed, read_response = Odoo_read()
            if read_completed == false then
                WriteLog(bridge .. "Read backoff activated! Sleeping for " .. backoff_counter .. " seconds..")
                os.execute("echo 1 > /sys/class/leds/richerlink:green:system/brightness")
                os.execute("sleep " .. tostring(backoff_counter))
                backoff_counter = backoff_counter + 2
                if backoff_counter >= 30 then
                    os.execute("reboot")
                end
            end
        until read_completed
        os.execute("echo 0 > /sys/class/leds/richerlink:green:system/brightness")

        -- Parse the read values and execute necessary modifications
        Odoo_execute(Odoo_parse(read_response))

        read_completed = false
        -- Keep trying to write ourselves into Odoo until successful
        backoff_counter = 5
        repeat
            write_completed = Odoo_write()
            if write_completed == false then
                WriteLog(bridge .. "Write backoff activated! Sleeping for " .. backoff_counter .. " seconds..")
                os.execute("echo 1 > /sys/class/leds/richerlink:green:system/brightness")
                os.execute("sleep " .. tostring(backoff_counter))
                backoff_counter = backoff_counter + 2
                if backoff_counter >= 30 then
                    os.execute("reboot")
                end
            end
        until write_completed
        os.execute("echo 0 > /sys/class/leds/richerlink:green:system/brightness")

        write_completed = false

        -- flag_Logdeleter = flag_Logdeleter + 1
        -- -- Clear the log file every 45 mins so it doesn't swell the RAM
        -- if flag_Logdeleter == 30 then
        --     flag_Logdeleter = 0
        --     Log_deleter()
        -- end
    end
end

Odoo_Connector()
