--[[
Author: Kılıçarslan SIMSIKI

Date Created: 06-06-2023
Date Modified: 06-06-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]


local uci = require("uci")

Gateway = {}
local cursor = uci.cursor()

function Gateway.Get_gateway()
    local handle = io.popen("ip route | awk '/default.*eth1_0/ { print $3 }'")
    if handle then
        local gateway = handle:read("*a")
        handle:close()
        gateway = string.gsub(gateway, "^%s*(.-)%s*$", "%1") -- trim leading/trailing whitespace

        -- Save the gateway so we can set this gateway when we reboot when dhcp client is off. ( Device doesn't auto initiate gw by default )
        local file = io.open("/etc/project_odoo/gateway_for_static", "w")
        if file then
            file:write("gateway:" .. gateway)
            file:close()
        end

        return gateway
    end
end

function Gateway.Set_gateway(gateway)
    local command = string.format("ip route replace default via %s", gateway)
    os.execute(command)
end
