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
    list.actionTostringMap["NoHangar"] = "No Hangar found!"%_t
    list.actionTostringMap["NoFighterController"] = "No FighterController found! (Critical Error, please report)"%_t
    list.actionTostringMap["Idle"] = "Idle and waiting for targets."%_t
    list.actionTostringMap["Fine"] = "Running fine."%_t
    list.actionTostringMap["None"] = ""%_t
    list.actionTostringMap[-1] = "Not doing anything."%_t

list.actionToColorMap = {}
setmetatable(list.actionToColorMap,{
  __index = function(t,k) return ColorRGB(1, 0, 0) end    --fallbackfunction, getting called when indexed with an invalid key
})
    list.actionToColorMap["NoHangar"] = ColorRGB(0.9, 0.1, 0.1)  -- default red (error)
    list.actionToColorMap["NoFighterController"] = ColorRGB(0.9, 0.1, 0.1)
    list.actionToColorMap["Idle"] = ColorRGB(0.3, 0.3, 0.9)  -- default blue (idle and active)
    list.actionToColorMap["Fine"] = ColorRGB(0.1, 0.8, 0.1)
    list.actionToColorMap["None"] = ColorRGB(0.1, 0.8, 0.1)
    list.actionToColorMap[-1] = ColorRGB(0.3, 0.3, 0.3)  -- (nothing to do)

return list
