local printer = {}

printer.identifier = "[Identifier Not Set]"
printer.minPrintLevel = "All"

printer.loglevel = {}
setmetatable(printer.loglevel,{
  __index = function(t,k) return 0 end    --fallback, when getting called with invalid key, to always print
})
printer.loglevel["Error"] = 1               -- critical, print out
printer.loglevel["Warn"] = 2                -- something isn't right
printer.loglevel["Info"] = 3                -- misc info
printer.loglevel["Debug"] = 4               -- watching for unusual, hardly recognizeable, stuff
printer.loglevel["All"] = math.huge         -- tracing electrons through the processor


local oldprintlog = print
function printer.printlog(lvl, ...)
    if printer.loglevel[lvl] <= printer.loglevel[printer.minPrintLevel] then
        local x,y = Sector():getCoordinates()
        local ms = string.format("%03d", appTimeMs()  % 1000)
        oldprintlog("[" .. os.date("%Y-%m-%d %X") .. ":".. ms .. "] "..printer.identifier, x, y, Entity().name, ...)
    end
end

local oldprint = print
function printer.print(...)
    local x,y = Sector():getCoordinates()
    local ms = string.format("%03d", appTimeMs()  % 1000)
    oldprint("[" .. os.date("%Y-%m-%d %X") .. ":".. ms .. "] "..printer.identifier, x, y, Entity().name,...)
end

return printer
