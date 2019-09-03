local printer = {}

printer.identifier = "[Identifier Not Set]"
local oldprintlog = printlog
function printer.printlog(...)
    local x,y = Sector():getCoordinates()
    oldprintlog("[" .. os.date("%Y-%m-%d %X") .. "] "..printer.identifier, x, y, Entity().name, ...)
end

local oldprint = print
function printer.print(...)
    local x,y = Sector():getCoordinates()
    oldprint("[" .. os.date("%Y-%m-%d %X") .. "] "..printer.identifier, ...)
end

return printer
