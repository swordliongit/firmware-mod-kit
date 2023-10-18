--[[
Author: Kılıçarslan SIMSIKI
]]


Password = {}

local luci_sys = require("luci.sys")

function Password.Set_LuciPasswd(newPassword)
    luci_sys.user.setpasswd("R3000admin", newPassword)
end