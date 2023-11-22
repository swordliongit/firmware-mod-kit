--[[
Author: Kılıçarslan SIMSIKI

Date Created: 20-05-2023
Date Modified: 23-05-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]

Mac = {}

function Mac.Get_mac()
    local interface = "eth0" -- Replace with the desired network interface

    local mac_address = io.open("/sys/class/net/" .. interface .. "/address"):read("*line")

    -- Extract the last digit of the MAC address
    local last_digit = mac_address:sub(-2, -1)

    -- Convert the last digit to a number and add 2
    local modified_last_digit = tostring(tonumber(last_digit, 16) + 2)

    -- Convert the modified last digit back to hexadecimal representation
    modified_last_digit = string.format("%X", modified_last_digit)

    -- Modify the MAC address by replacing the last digit
    return (mac_address:gsub(last_digit, modified_last_digit))
end
