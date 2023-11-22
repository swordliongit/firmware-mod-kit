Sysupgrade = {}

require("luci.sys")

dofile("/etc/project_master_modem/src/util.lua")
function Sysupgrade.Upgrade()
    local config = ReadConfig()
    local url = config.url_download
    local filename = "new-firmware.bin"

    local response = {}
    local _, code, headers, status = Http.request {
        url = url,
        redirect = true, -- Follow redirection
        sink = Ltn12.sink.table(response),
        timeout = 60,    -- Set a timeout (adjust as needed)
    }

    if code == 200 then
        local contentDisposition = headers["content-disposition"]
        if contentDisposition and contentDisposition:match("filename=\"([^\"]+)\"") then
            filename = contentDisposition:match("filename=\"([^\"]+)\"")
        end

        local file = io.open("/tmp/" .. filename, "wb")
        if file then
            for _, chunk in ipairs(response) do
                local result, error_message = file:write(chunk)
                if not result then
                    WriteLog(client .. "Error writing to file: " .. error_message)
                    file:close()
                    return false
                end
            end
            file:close()
            WriteLog(client .. "File downloaded and saved: " .. filename)
            local exitStatus = luci.sys.call("sysupgrade -n /tmp/" .. filename)
            return exitStatus
        else
            WriteLog(client .. "Error opening file for writing")
        end
    end
end
