local printer = {}

printer.identifier = "[Identifier Not Set]"
local oldprintlog = print
function printer.printlog(...)
    local x,y = Sector():getCoordinates()
    local ms = string.format("%03d", appTimeMs()  % 1000)
    oldprintlog("[" .. os.date("%Y-%m-%d %X") .. ":".. ms .. "] "..printer.identifier, x, y, Entity().name, ...)
end

local oldprint = print
function printer.print(...)
    local x,y = Sector():getCoordinates()
    local ms = string.format("%03d", appTimeMs()  % 1000)
    oldprint("[" .. os.date("%Y-%m-%d %X") .. ":".. ms .. "] "..printer.identifier, x, y, Entity().name,...)
end

return printer
