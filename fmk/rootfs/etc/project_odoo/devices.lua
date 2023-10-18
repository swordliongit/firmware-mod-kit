--[[
Author: Kılıçarslan SIMSIKI

Date Created: 20-05-2023
Date Modified: 23-05-2023

Description:
All modification and duplication of this software is forbidden and licensed under Apache.
]]


local luci_sys = require("luci.sys")

Devices = {}

function Devices.Get_devices()
    local arptable = luci_sys.net.arptable()

    -- Mapping of flag values to status labels
    local statusLabels = {
        ["0x0"] = "Incomplete",
        ["0x1"] = "Complete",
        ["0x2"] = "Static"
    }

    local devices = {} -- Table to store device information

    for _, entry in ipairs(arptable) do
        local ipAddress = entry["IP address"] or "Unknown"
        local macAddress = entry["HW address"] or "Unknown"
        local statusFlag = entry["Flags"] or 0x0
        local status = statusLabels[statusFlag] or "Unknown"
        local deviceType = GetDeviceType(entry["HW type"])

        local deviceInfo = {
            device = deviceType,
            ip = ipAddress,
            mac = macAddress,
            status = status
        }
        table.insert(devices, deviceInfo)
    end

    return devices
end

-- Helper function to map hardware types to device types
function GetDeviceType(hwType)
    local deviceTypes = {
        ["0x1"] = "Computer",
        ["0x2"] = "Ethernet",
        ["0x3"] = "Wi-Fi",
        ["0x4"] = "Cellular",
        ["0x5"] = "Printer",
        ["0x6"] = "TV or Media Device",
        ["0x7"] = "Game Console",
        ["0x8"] = "IoT Device",
        ["0x9"] = "Unknown or Other"
    }

    return deviceTypes[hwType] or "Unknown"
end

-- Function to generate the string representation of devices
function Devices.Get_DevicesString()
    local devices = Devices.Get_devices()
    local devicesString = ""

    for _, deviceInfo in ipairs(devices) do
        devicesString = devicesString .. string.format("Device: %s\t\tIP: %s\t\tMAC: %s\t\tStatus: %s\n", deviceInfo.device, deviceInfo.ip, deviceInfo.mac, deviceInfo.status)
    end

    return devicesString
end

