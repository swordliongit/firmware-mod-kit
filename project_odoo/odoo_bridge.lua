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
-- local lfs = require("lfs")

-- -- Get the current working directory
-- local currentDirectory = lfs.currentdir()
-- io.write("\n" .. currentDirectory .. "\n")

http = require("socket.http")
ltn12 = require("ltn12")
json = require("json")
dofile("/etc/project_odoo/devices.lua")
dofile("/etc/project_odoo/dhcp.lua")
dofile("/etc/project_odoo/ip.lua")
dofile("/etc/project_odoo/mac.lua")
dofile("/etc/project_odoo/netmask.lua")
dofile("/etc/project_odoo/password.lua")
dofile("/etc/project_odoo/ssid.lua")
dofile("/etc/project_odoo/time.lua")
dofile("/etc/project_odoo/wireless.lua")
dofile("/etc/project_odoo/site.lua")
dofile("/etc/project_odoo/gateway.lua")
dofile("/etc/project_odoo/sysupgrade.lua")
dofile("/etc/project_odoo/name.lua")
dofile("/etc/project_odoo/system.lua")
dofile("/etc/project_odoo/vlan.lua")

local Odoo_login = function()
    local body = {}

    local requestBody = json.encode({
        ["jsonrpc"] = "2.0",
        ["params"] = {
            ["login"] = "admin",
            ["password"] = "Artin.modem",
            ["db"] = "modem"
        }
    })

    local res, code, headers, status = http.request {
        method = "POST",
        url = "http://89.252.165.116:8069/web/session/authenticate",
        source = ltn12.source.string(requestBody),
        headers = {
            ["content-type"] = "application/json",
            ["content-length"] = tostring(#requestBody)
        },
        sink = ltn12.sink.table(body),
        protocol = "tlsv1_2"
    }

    local responseBody = table.concat(body)

    if code == 200 then
        _G.cookie = headers["set-cookie"]:match("(.-);")
        io.write(client .. cookie .. "\n\n")
        return true
    else
        io.write(server .. "Failed to authenticate. HTTP code: " ..
            tostring(code) .. "\nResponse body:\n" .. responseBody .. "\n\n")
        return false
    end
end


local Odoo_read = function()
    local body = {}

    local requestBody = json.encode({
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
                "x_vlanId"
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

    local res, code, headers, status = http.request {
        method = "POST",
        url = "http://89.252.165.116:8069/web/dataset/search_read",
        source = ltn12.source.string(requestBody),
        headers = {
            ["content-type"] = "application/json",
            ["content-length"] = tostring(#requestBody),
            ["Cookie"] = _G.cookie
        },
        sink = ltn12.sink.table(body),
        protocol = "tlsv1_2"
    }

    local responseBody = table.concat(body)

    if code == 200 then
        io.write(client .. responseBody .. "\n\n")
        return true, responseBody
    else
        io.write(server ..
            "Failed to fetch data. HTTP code: " .. tostring(code) .. "\nResponse body:\n" .. responseBody .. "\n\n")
        return false, responseBody
    end
end

local Odoo_parse = function(responseBody)
    local responseJson = json.decode(responseBody)
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
        ["x_vlanId"] = x_vlanId
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

    io.write(client .. "\nExecution Query: **")
    for key, value in pairs(parsed_values) do
        if key == "name" and value ~= Name.Get_name() then
            io.write(client .. "-Name-")
            Name.Set_name(value)
        end
        if key == "x_site" and value ~= Site.Get_site() then
            io.write(client .. "-Site-")
            Site.Set_site(value)
        end
        if key == "x_channel" and value ~= Wireless.Get_wireless_channel() then
            io.write(client .. "-Channel-")
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
            io.write(client .. "-Wireless-")
            if value then
                Wireless.Set_wireless_status("1")
            else
                Wireless.Set_wireless_status("0")
            end
            need_wifi_reload = true
        end
        if key == "x_ssid1" and value ~= Ssid.Get_ssid1() then
            io.write(client .. "-SSID1-")
            Ssid.Set_ssid1(value)
            need_wifi_reload = true
        end
        if key == "x_passwd_1" and value ~= Ssid.Get_ssid1_passwd() then
            io.write(client .. "-PWD1-")
            Ssid.Set_ssid1_passwd(value)
            need_wifi_reload = true
        end
        if key == "x_ssid2" and value ~= Ssid.Get_ssid2() then
            io.write(client .. "-SSID2-")
            Ssid.Set_ssid2(value)
            need_wifi_reload = true
        end
        if key == "x_passwd_2" and value ~= Ssid.Get_ssid2_passwd() then
            io.write(client .. "-PWD2-")
            Ssid.Set_ssid2_passwd(value)
            need_wifi_reload = true
        end
        if key == "x_ssid3" and value ~= Ssid.Get_ssid3() then
            io.write(client .. "-SSID3-")
            Ssid.Set_ssid3(value)
            need_wifi_reload = true
        end
        if key == "x_passwd_3" and value ~= Ssid.Get_ssid3_passwd() then
            io.write(client .. "-PWD3-")
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
            io.write(client .. "-ENSSID1-")
            if value then
                Ssid.Set_ssid1_status("1")
            else
                Ssid.Set_ssid1_status("0")
            end
            need_wifi_reload = true
        end
        if key == "x_enable_ssid2" and value ~= Ssid.Get_ssid2_status() then
            io.write(client .. "-ENSSID2-")
            if value then
                Ssid.Set_ssid2_status("1")
            else
                Ssid.Set_ssid2_status("0")
            end
            need_wifi_reload = true
        end
        if key == "x_enable_ssid3" and value ~= Ssid.Get_ssid3_status() then
            io.write(client .. "-ENSSID3-")
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
            io.write(client .. "-NPWD-")
            Password.Set_LuciPasswd(value)
        end
        if key == "x_reboot" and value ~= false then
            io.write(client .. "-Need Reboot")
            need_reboot = true
        end
        if key == "x_upgrade" and value ~= false then
            io.write(client .. "-Upgrade-")
            -- Ensure you're logged in before downloading
            -- if not _G.cookie or _G.cookie == "" then
            --     Odoo_login()
            -- end
            Sysupgrade.Upgrade()
        end
        if key == "x_vlanId" and value ~= Vlan.Get_VlanId() then
            io.write(client .. "-Vlan-")
            Vlan.Set_VlanId(value)
            io.write(Vlan.Get_VlanId())
            need_reboot = true
        end
    end
    if need_wifi_reload then
        io.write(client .. "-WIFI RELOAD-")
        luci_util.exec("/sbin/wifi")
    end
    if need_reboot then
        io.write(client .. "-REBOOT-")
        os.execute("reboot")
    end
end

local Odoo_write = function()
    local body = {}

    local requestBody = json.encode({
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
        ["x_log"] = System.Get_log(),
        ["x_vlanId"] = Vlan.Get_VlanId(),
        ["x_logTrunkExecTime"] = System.Get_ScriptExecutionTime()
        -- ["x_manual_time"] = Time.Get_manualtime(),
        -- ["x_new_password"] = false,
        -- ["x_reboot"] = false,
        -- ["x_upgrade"] = false
    })

    local res, code, headers, status = http.request({
        method = "POST",
        url = "http://89.252.165.116:8069/create/create_or_update_record",
        source = ltn12.source.string(requestBody),
        headers = {
            ["content-type"] = "application/json",
            ["content-length"] = tostring(#requestBody),
            ["Cookie"] = _G.cookie
        },
        sink = ltn12.sink.table(body),
        protocol = "tlsv1_2"
    })

    local responseBody = table.concat(body)

    if code == 200 then
        io.write(client .. responseBody .. "\n\n")
        return true
    else
        io.write(server ..
            "Failed to post data. HTTP code: " .. tostring(code) .. "\nResponse body:\n" .. responseBody .. "\n\n")
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
            io.write(client .. "\n\nLogin backoff activated! Sleeping for " .. backoff_counter .. " seconds..\n\n")
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
            io.write(client ..
                "\n\nInitial write backoff activated! Sleeping for " .. backoff_counter .. " seconds..\n\n")
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
                io.write(client ..
                    "\n\nRead backoff activated! Sleeping for " .. backoff_counter .. " seconds..\n\n")
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
                io.write(client ..
                    "\n\nWrite backoff activated! Sleeping for " .. backoff_counter .. " seconds..\n\n")
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
