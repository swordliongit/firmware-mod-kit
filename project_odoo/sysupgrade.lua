Sysupgrade = {}

function Sysupgrade.Upgrade()
    local url = "http://89.252.165.116:8069/web/content/45?download=true&access_token="
    local filename = "new-firmware.bin"

    local response = {}
    local _, code, headers = http.request {
        url = url,
        redirect = true,           -- Follow redirection
        headers = {
            ["Cookie"] = _G.cookie -- Include the session cookie
        },
        sink = ltn12.sink.table(response),
    }

    if code == 200 then
        local contentDisposition = headers["content-disposition"]
        if contentDisposition and contentDisposition:match("filename=\"([^\"]+)\"") then
            filename = contentDisposition:match("filename=\"([^\"]+)\"")
        end

        local file = io.open("/tmp/" .. filename, "wb")
        if file then
            file:write(table.concat(response))
            file:close()
            io.write("\n\n" .. client .. "File downloaded and saved:", filename)
            os.execute("sysupgrade -n tmp/" .. filename)
        else
            io.write("\n\n" .. client .. "Error opening file for writing")
        end
    else
        io.write("\n\n" .. server .. "HTTP request failed with status code:", code)
    end
end
