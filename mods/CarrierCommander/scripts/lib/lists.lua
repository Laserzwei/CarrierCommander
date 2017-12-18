local list = {}
--
list.selectableOrderNames = {}
    list.selectableOrderNames[FighterOrders.Return] = "Dock"
    list.selectableOrderNames[FighterOrders.Defend] = "Defend"

list.uiElementToSettingMap = {}

list.actionTostringMap = {}
setmetatable(list.actionTostringMap,{
  __index = function(t,k) return "Invalid order received" end    --fallbackfunction, getting called when indexed with an invalid key
})
    list.actionTostringMap["noHangar"] = "No Hangar found!"
    list.actionTostringMap["noFighterController"] = "No FighterController found!"
    list.actionTostringMap["targetButNoFighter"] = "Found a target, but no suitable fighters."
    list.actionTostringMap["idle"] = "Idle and waiting for targets."
    list.actionTostringMap[-1] = "Not doing anything."
    list.actionTostringMap[FighterOrders.Attack] = "Attacking ship %s"
    list.actionTostringMap[FighterOrders.Defend] = "Defending ship %s"
    list.actionTostringMap[FighterOrders.Return] = "Waiting for %i Fighter(s) in %i Squad(s) to dock at %s"
    list.actionTostringMap[FighterOrders.FlyToLocation] = "flying to location."
    --list.actionTostringMap[4] = nil                       reserved for new vanilla command
    list.actionTostringMap[5] = "Mining asteroids."
    list.actionTostringMap[6] = "Salvaging wrecks."

list.actionToColorMap = {}
setmetatable(list.actionToColorMap,{
  __index = function(t,k) return ColorRGB(0.9, 0.1, 0.1) end    --fallbackfunction, getting called when indexed with an invalid key
})
    list.actionToColorMap["noHangar"] = ColorRGB(0.9, 0.1, 0.1)
    list.actionToColorMap["noFighterController"] = ColorRGB(0.9, 0.1, 0.1)
    list.actionToColorMap["targetButNoFighter"] = ColorRGB(0.9, 0.1, 0.1)
    list.actionToColorMap["idle"] = ColorRGB(0.3, 0.3, 0.9)
    list.actionToColorMap[-1] = ColorRGB(0.3, 0.3, 0.3)
    list.actionToColorMap[FighterOrders.Attack] = ColorRGB(0.1, 0.8, 0.1)
    list.actionToColorMap[FighterOrders.Defend] = ColorRGB(0.3, 0.3, 0.3)
    list.actionToColorMap[FighterOrders.Return] = ColorRGB(0.5, 0.5, 0.0)
    list.actionToColorMap[FighterOrders.FlyToLocation] = ColorRGB(0.0, 0.5, 0.5)
    --list.actionToColorMap[4] = nil                       reserved for new vanilla command
    list.actionToColorMap[5] = ColorRGB(0.1, 0.8, 0.1)
    list.actionToColorMap[6] = ColorRGB(0.1, 0.8, 0.1)
    list.tooltipadditions = {}

return list
