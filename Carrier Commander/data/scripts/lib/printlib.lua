local Printer = {}
Printer.__index = Printer

local function new(identifier, minPrintLevel)
    local instance = {}
    instance.identifier = identifier or "[Identifier Not Set]"
    instance.minPrintLevel = minPrintLevel or "All"
    return setmetatable(instance, Printer)
end

Printer.loglevel = {}
setmetatable(Printer.loglevel,{ __index = function(t,k) return 0 end }) -- Fallback, when getting called with invalid key, to always print
Printer.loglevel["Error"] = 1               -- Critical, print out
Printer.loglevel["Warn"] = 2                -- Something isn't right
Printer.loglevel["Info"] = 3                -- Misc info
Printer.loglevel["Debug"] = 4               -- Watching for unusual, hardly recognizeable, stuff
Printer.loglevel["All"] = math.huge         -- Only for comparison. Not meant for printlog("All", ...)

local oldprintlog = print
function Printer:printlog(lvl, ...)
    if self.loglevel[lvl] <= self.loglevel[self.minPrintLevel] then
        local x,y = Sector():getCoordinates()
        local ms = string.format("%03d", appTimeMs()  % 1000)
        oldprintlog("[" .. os.date("%Y-%m-%d %X") .. ":".. ms .. "] "..self.identifier, x, y, Entity().name, ...)
    end
end

local oldprint = print
function Printer:print(...)
    local x,y = Sector():getCoordinates()
    local ms = string.format("%03d", appTimeMs()  % 1000)
    oldprint("[" .. os.date("%Y-%m-%d %X") .. ":".. ms .. "] "..self.identifier, x, y, Entity().name,...)
end

return setmetatable(Printer, {__call = function (_,...)  return new(...) end})
