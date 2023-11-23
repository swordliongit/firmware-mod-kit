--[[
Author: Kılıçarslan SIMSIKI

Date Created: 20-05-2023
Date Modified: 10-08-2023

Description:
All modification and duplication of this software are forbidden and licensed under Apache.

Flow of the overall program:

Odoo_Write
loop:
    Odoo_execute <-- Bridge_Parse <-- Odoo_Read
    Odoo_Write
]]

_G.Serror_backoff_counter = 0
_G.MAX_SERROR = 10
_G.Monitor = ""
_G.Prev_Read_Accepted = true

require("luci.sys")
Http = require("socket.http")
Ltn12 = require("ltn12")
Json = require("json")
dofile("/etc/project_master_modem/src/devices.lua")
dofile("/etc/project_master_modem/src/dhcp.lua")
dofile("/etc/project_master_modem/src/ip.lua")
dofile("/etc/project_master_modem/src/mac.lua")
dofile("/etc/project_master_modem/src/netmask.lua")
dofile("/etc/project_master_modem/src/password.lua")
dofile("/etc/project_master_modem/src/ssid.lua")
dofile("/etc/project_master_modem/src/time.lua")
dofile("/etc/project_master_modem/src/wireless.lua")
dofile("/etc/project_master_modem/src/site.lua")
dofile("/etc/project_master_modem/src/gateway.lua")
dofile("/etc/project_master_modem/src/sysupgrade.lua")
dofile("/etc/project_master_modem/src/name.lua")
dofile("/etc/project_master_modem/src/system.lua")
dofile("/etc/project_master_modem/src/vlan.lua")
dofile("/etc/project_master_modem/src/util.lua")

function BRIDGE_CHECK(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        WriteLog(bridge .. "Error: " .. result)
    end
    return result
end

local Odoo_Read = function()
    local body = {}
    local config = ReadConfig()

    local requestBody = Json.encode({
        ["x_mac"] = Mac.Get_mac(),
        ["fields"] = {
            "name",
            "x_site",
            "x_channel",
            "x_enable_wireless",
            "x_ssid1",
            "x_passwd_1",
            "x_ssid2",
            "x_passwd_2",
            "x_ssid3",
            "x_passwd_3",
            "x_enable_ssid1",
            "x_enable_ssid2",
            "x_enable_ssid3",
            "x_new_password",
            "x_reboot",
            "x_upgrade",
            "x_vlanId",
            "x_terminal",
        }
    })

    WriteLog(client .. "Read " .. requestBody)

    local res, code, headers, status = Http.request {
        method = "POST",
        url = config.url_read,
        source = Ltn12.source.string(requestBody),
        headers = {
            ["content-type"] = "application/json",
            ["content-length"] = tostring(#requestBody),
        },
        sink = Ltn12.sink.table(body),
        protocol = "tlsv1_2"
    }

    local responseBody = table.concat(body)

    if code == 200 then
        -- Check for specific error conditions in the response body ( Odoo Server Error )
        if responseBody:find("Odoo Server Error") then
            -- Handle the server error condition here
            WriteLog(server .. "Read ERROR: " .. responseBody)
            return false
        else
            WriteLog(client .. "Receive " .. responseBody)
            return true, responseBody
        end
    else
        WriteLog(server ..
            "Failed to fetch data. HTTP code: " .. tostring(code) .. "\nResponse body:\n" .. responseBody)
        return false, responseBody
    end
end

local Bridge_Parse = function(responseBody)
    local responseJson = Json.decode(responseBody)
    local modem = responseJson.result.modem

    if responseJson.result.success then
        _G.Prev_Read_Accepted = true
    else
        _G.Prev_Read_Accepted = false
    end

    local parsed_values = {
        ["name"] = modem.name,
        ["x_site"] = modem.x_site,
        ["x_channel"] = modem.x_channel,
        ["x_enable_wireless"] = modem.x_enable_wireless,
        ["x_ssid1"] = modem.x_ssid1,
        ["x_passwd_1"] = modem.x_passwd_1,
        ["x_ssid2"] = modem.x_ssid2,
        ["x_passwd_2"] = modem.x_passwd_2,
        ["x_ssid3"] = modem.x_ssid3,
        ["x_passwd_3"] = modem.x_passwd_3,
        ["x_enable_ssid1"] = modem.x_enable_ssid1,
        ["x_enable_ssid2"] = modem.x_enable_ssid2,
        ["x_enable_ssid3"] = modem.x_enable_ssid3,
        ["x_reboot"] = modem.x_reboot,
        ["x_upgrade"] = modem.x_upgrade,
        ["x_vlanId"] = modem.x_vlanId,
        ["x_terminal"] = modem.x_terminal,
    }

    return parsed_values
end

local Bridge_Execute = function(parsed_values)
    local luci_util = require("luci.util")
    local need_reboot = false
    local need_wifi_reload = false
    local need_upgrade = false
    local pra_fail = false

    -- Define the order of execution for keys
    local execution_order = {
        "x_upgrade",
        "name",
        "x_ssid1",
        "x_ssid2",
        "x_ssid3",
        "x_passwd_1",
        "x_passwd_2",
        "x_passwd_3",
        "x_enable_ssid1",
        "x_enable_ssid2",
        "x_enable_ssid3",
        "x_enable_wireless",
        "x_site",
        "x_channel",
        "x_terminal",
        "x_vlanId",
        "x_reboot"
    }

    WriteLog(client .. "Execution Queue: [", "wrapper_start")
    if _G.Prev_Read_Accepted then
        for _, key in pairs(execution_order) do
            local value = parsed_values[key]

            if key == "name" and value ~= BRIDGE_CHECK(Name.Get_name) then
                WriteLog("Change Name", "task")
                BRIDGE_CHECK(Name.Set_name, value)
            elseif key == "x_site" and value ~= BRIDGE_CHECK(Site.Get_site) then
                WriteLog("Change Site", "task")
                BRIDGE_CHECK(Site.Set_site, value)
            elseif key == "x_channel" and value ~= BRIDGE_CHECK(Wireless.Get_wireless_channel) then
                WriteLog("Change Channel", "task")
                if value == "auto" then
                    BRIDGE_CHECK(Wireless.Set_wireless_channel, "0")
                else
                    BRIDGE_CHECK(Wireless.Set_wireless_channel, value)
                end
                need_wifi_reload = true
            elseif key == "x_enable_wireless" and value ~= BRIDGE_CHECK(Wireless.Get_wireless_status) then
                if value then
                    WriteLog("Enable Wireless", "task")
                    BRIDGE_CHECK(Wireless.Set_wireless_status, "1")
                else
                    WriteLog("Disable Wireless", "task")
                    BRIDGE_CHECK(Wireless.Set_wireless_status, "0")
                end
                need_wifi_reload = true
            elseif key == "x_ssid1" and value ~= BRIDGE_CHECK(Ssid.Get_ssid1) then
                WriteLog("Change SSID1", "task")
                BRIDGE_CHECK(Ssid.Set_ssid1, value)
                need_wifi_reload = true
            elseif key == "x_passwd_1" and value ~= BRIDGE_CHECK(Ssid.Get_ssid1_passwd) then
                WriteLog("Change SSID1 Password", "task")
                BRIDGE_CHECK(Ssid.Set_ssid1_passwd, value)
                need_wifi_reload = true
            elseif key == "x_ssid2" and value ~= BRIDGE_CHECK(Ssid.Get_ssid2) then
                WriteLog("Change SSID2", "task")
                BRIDGE_CHECK(Ssid.Set_ssid2, value)
                need_wifi_reload = true
            elseif key == "x_passwd_2" and value ~= BRIDGE_CHECK(Ssid.Get_ssid2_passwd) then
                WriteLog("Change SSID2 Password", "task")
                BRIDGE_CHECK(Ssid.Set_ssid2_passwd, value)
                need_wifi_reload = true
            elseif key == "x_ssid3" and value ~= BRIDGE_CHECK(Ssid.Get_ssid3) then
                WriteLog("Change SSID3", "task")
                BRIDGE_CHECK(Ssid.Set_ssid3, value)
                need_wifi_reload = true
            elseif key == "x_passwd_3" and value ~= BRIDGE_CHECK(Ssid.Get_ssid3_passwd) then
                WriteLog("Change SSID3 Password", "task")
                BRIDGE_CHECK(Ssid.Set_ssid3_passwd, value)
                need_wifi_reload = true
            elseif key == "x_enable_ssid1" and value ~= BRIDGE_CHECK(Ssid.Get_ssid1_status) then
                if value then
                    WriteLog("Enable SSID1", "task")
                    BRIDGE_CHECK(Ssid.Set_ssid1_status, "1")
                else
                    WriteLog("Disable SSID1", "task")
                    BRIDGE_CHECK(Ssid.Set_ssid1_status, "0")
                end
                need_wifi_reload = true
            elseif key == "x_enable_ssid2" and value ~= BRIDGE_CHECK(Ssid.Get_ssid2_status) then
                if value then
                    WriteLog("Enable SSID2", "task")
                    BRIDGE_CHECK(Ssid.Set_ssid2_status, "1")
                else
                    WriteLog("Disable SSID2", "task")
                    BRIDGE_CHECK(Ssid.Set_ssid2_status, "0")
                end
                need_wifi_reload = true
            elseif key == "x_enable_ssid3" and value ~= BRIDGE_CHECK(Ssid.Get_ssid3_status) then
                if value then
                    WriteLog("Enable SSID3", "task")
                    BRIDGE_CHECK(Ssid.Set_ssid3_status, "1")
                else
                    WriteLog("Disable SSID3", "task")
                    BRIDGE_CHECK(Ssid.Set_ssid3_status, "0")
                end
                need_wifi_reload = true
            elseif key == "x_reboot" and value ~= false then
                WriteLog("Forced Reboot", "task")
                need_reboot = true
            elseif key == "x_upgrade" and value ~= false then
                WriteLog("Upgrade", "task")
                need_upgrade = true
            elseif key == "x_vlanId" and value ~= BRIDGE_CHECK(Vlan.Get_VlanId) then
                WriteLog("Change VlanId", "task")
                BRIDGE_CHECK(Vlan.Set_VlanId, value)
                need_reboot = true
            elseif key == "x_terminal" then
                if value ~= false then
                    WriteLog("Execute Remote Command", "task")
                    Monitor = BRIDGE_CHECK(ExecuteRemoteTerminal, value)
                end
            end
        end
    else
        pra_fail = true
    end

    if need_upgrade then
        WriteLog("]", "wrapper_end")
        BRIDGE_CHECK(Sysupgrade.Upgrade)
    end
    if need_reboot then
        WriteLog("Reboot", "task")
        WriteLog("]", "wrapper_end")
        return true
        -- os.execute("reboot")
    end
    if need_wifi_reload then
        WriteLog("Reload Wifi", "task")
        luci_util.exec("/sbin/wifi")
    end

    WriteLog("]", "wrapper_end")
    if pra_fail then
        WriteLog(client .. "Previous read attempt unsuccessful, not changing anything...")
    end
end

local Odoo_Write = function()
    local body = {}
    local config = ReadConfig()

    local requestData = {
        ["name"] = BRIDGE_CHECK(Name.Get_name),
        ["x_site"] = BRIDGE_CHECK(Site.Get_site),
        ["x_uptime"] = BRIDGE_CHECK(Time.Get_uptime),
        ["x_channel"] = BRIDGE_CHECK(Wireless.Get_wireless_channel),
        ["x_mac"] = BRIDGE_CHECK(Mac.Get_mac),
        ["x_device_info"] = BRIDGE_CHECK(Devices.Get_DevicesString),
        ["x_ip"] = BRIDGE_CHECK(LanIP.Get_Ip),
        ["x_subnet"] = BRIDGE_CHECK(Netmask.Get_netmask),
        ["x_gateway"] = BRIDGE_CHECK(Gateway.Get_gateway),
        ["x_enable_wireless"] = BRIDGE_CHECK(Wireless.Get_wireless_status),
        ["x_ssid1"] = BRIDGE_CHECK(Ssid.Get_ssid1),
        ["x_passwd_1"] = BRIDGE_CHECK(Ssid.Get_ssid1_passwd),
        ["x_ssid2"] = BRIDGE_CHECK(Ssid.Get_ssid2),
        ["x_passwd_2"] = BRIDGE_CHECK(Ssid.Get_ssid2_passwd),
        ["x_ssid3"] = BRIDGE_CHECK(Ssid.Get_ssid3),
        ["x_passwd_3"] = BRIDGE_CHECK(Ssid.Get_ssid3_passwd),
        ["x_enable_ssid1"] = BRIDGE_CHECK(Ssid.Get_ssid1_status),
        ["x_enable_ssid2"] = BRIDGE_CHECK(Ssid.Get_ssid2_status),
        ["x_enable_ssid3"] = BRIDGE_CHECK(Ssid.Get_ssid3_status),
        ["x_ram"] = BRIDGE_CHECK(System.Get_ram),
        ["x_cpu"] = BRIDGE_CHECK(System.Get_cpu),
        ["x_disk"] = BRIDGE_CHECK(System.Get_disk),
        ["x_log"] = BRIDGE_CHECK(Get_log),
        ["x_vlanId"] = BRIDGE_CHECK(Vlan.Get_VlanId),
        ["x_lastTimeLogTrimmed"] = BRIDGE_CHECK(Get_ScriptExecutionTime),
        ["x_monitor"] = _G.Monitor,
        ["x_firmwareVersion"] = BRIDGE_CHECK(System.Get_firmwareVersion),
        ["pra"] = _G.Prev_Read_Accepted
    }

    local requestBody = Json.encode(requestData)
    -- Add excluded fields for logging purposes
    requestData["x_log"] = nil
    requestData["x_monitor"] = nil
    -- I need to exclude the log field
    local RequestBody_forPrint = Json.encode(requestData)

    WriteLog(client .. "Write " .. RequestBody_forPrint)

    local res, code, headers, status = Http.request({
        method = "POST",
        url = config.url_write,
        source = Ltn12.source.string(requestBody),
        headers = {
            ["content-type"] = "application/json",
            ["content-length"] = tostring(#requestBody),
        },
        sink = Ltn12.sink.table(body),
        protocol = "tlsv1_2"
    })

    local responseBody = table.concat(body)

    if code == 200 then
        -- Check for specific error conditions in the response body ( Odoo Server Error )
        if responseBody:find("Odoo Server Error") then
            -- Handle the server error condition here
            WriteLog(server .. "Write ERROR: " .. responseBody)
            return false
        else
            WriteLog(client .. "Receive " .. responseBody)
            return true
        end
    else
        WriteLog(server ..
            "Failed to post data. HTTP code: " .. tostring(code) .. "\nResponse body:\n" .. responseBody)
        return false
    end
end


function Odoo_Connector()
    local backoff_counter = 5
    local write_completed = false
    local read_completed = false
    local read_response = nil
    local reboot_required = false

    -- Main program loop
    while true do
        WriteLog(bridge .. "CYCLE ------------{")
        -- Keep trying to write ourselves into Odoo until successful
        -- WriteLog(master .. "Entering Write Block" .. tostring(backoff_counter))
        backoff_counter = 5
        repeat
            write_completed = BRIDGE_CHECK(Odoo_Write)
            if write_completed == false then
                WriteLog(bridge .. "Write Backoff activated! Sleeping for " .. backoff_counter .. " seconds..")
                luci.sys.call("echo 1 > /sys/class/leds/richerlink:green:system/brightness")
                luci.sys.call("sleep " .. tostring(backoff_counter))
                backoff_counter = backoff_counter + 2
                if backoff_counter >= 36 then
                    reboot_required = true
                    WriteLog(bridge .. "Write Backoff reboot signal received...")
                    break
                end
            end
        until write_completed
        -- WriteLog(bridge .. "Write Successful..")
        luci.sys.call("echo 0 > /sys/class/leds/richerlink:green:system/brightness")

        if reboot_required then
            break
        end

        -- WriteLog(master .. "Exiting Write Block" .. tostring(backoff_counter))

        write_completed = false

        -- WriteLog(bridge .. "Sleeping before Read..")
        luci.sys.call("sleep 10")
        -- WriteLog(bridge .. "Waking up before Read..")

        -- Keep trying to read data from Odoo until successful
        -- WriteLog(master .. "Entering Read Block" .. tostring(backoff_counter))
        backoff_counter = 5 -- Defensive counter against continous error cycles
        repeat
            read_completed, read_response = Odoo_Read()
            if read_completed == false then
                WriteLog(bridge .. "Read Backoff activated! Sleeping for " .. backoff_counter .. " seconds..")
                luci.sys.call("echo 1 > /sys/class/leds/richerlink:green:system/brightness")
                luci.sys.call("sleep " .. tostring(backoff_counter))
                backoff_counter = backoff_counter + 2
                if backoff_counter >= 36 then
                    reboot_required = true
                    WriteLog(bridge .. "Read Backoff reboot signal received...")
                    break
                end
            end
        until read_completed
        -- WriteLog(bridge .. "Read Successful..")
        luci.sys.call("echo 0 > /sys/class/leds/richerlink:green:system/brightness")
        -- WriteLog(master .. "Exiting Read Block" .. tostring(backoff_counter))

        if reboot_required then
            break
        end

        -- WriteLog(master .. "Entering Parse Block" .. tostring(backoff_counter))
        -- Parse the read values and execute necessary modifications
        local parse_results = BRIDGE_CHECK(Bridge_Parse, read_response)
        if Bridge_Execute(parse_results) then
            WriteLog(bridge .. "Reboot signal received from Parse()...")
            break -- Reboot signal received, break
        end
        -- WriteLog(master .. "Exiting Parse Block" .. tostring(backoff_counter))

        read_completed = false
        WriteLog(bridge .. "CYCLE ------------}")
    end

    WriteLog(bridge .. "Elevating Reboot signal to PIALB()")
    return true
end

return Odoo_Connector()
