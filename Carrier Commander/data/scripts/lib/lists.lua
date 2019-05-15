local list = {}

list.uiElementToSettingMap = {}
list.tooltipadditions = {}

list.selectableOrderNames = {}
    list.selectableOrderNames[FighterOrders.Return] = "Dock"
    list.selectableOrderNames[FighterOrders.Defend] = "Defend"

list.actionTostringMap = {}
setmetatable(list.actionTostringMap,{
  __index = function(t,k) return "Invalid order received" end    --fallbackfunction, getting called when indexed with an invalid key
})
    list.actionTostringMap["noHangar"] = "No Hangar found!"%_t
    list.actionTostringMap["noFighterController"] = "No FighterController found! (Critical Error, please report)"%_t
    list.actionTostringMap["targetButNoFighter"] = "Found a target, but no suitable fighters."%_t
    list.actionTostringMap["idle"] = "Idle and waiting for targets."%_t
    list.actionTostringMap[-1] = "Not doing anything."%_t

list.actionToColorMap = {}
setmetatable(list.actionToColorMap,{
  __index = function(t,k) return ColorRGB(1, 0, 0) end    --fallbackfunction, getting called when indexed with an invalid key
})
    list.actionToColorMap["noHangar"] = ColorRGB(0.9, 0.1, 0.1)  -- default red (error)
    list.actionToColorMap["noFighterController"] = ColorRGB(0.9, 0.1, 0.1)
    list.actionToColorMap["targetButNoFighter"] = ColorRGB(0.9, 0.1, 0.1)
    list.actionToColorMap["idle"] = ColorRGB(0.3, 0.3, 0.9)  -- default blue (idle and active)
    list.actionToColorMap[-1] = ColorRGB(0.3, 0.3, 0.3)  -- (nothing to do)

return list
