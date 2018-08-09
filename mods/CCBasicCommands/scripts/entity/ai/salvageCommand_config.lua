local salvageCommand = {}
salvageCommand.prefix = "salvage"

function salvageCommand.initConfigUI(scrollframe, pos, size)
    local label = scrollframe:createLabel(pos, "Salvaging config", 15)
    label.tooltip = "Set the behaviour once the Salvaging-operation ends"
    label.fontSize = 15
    label.font = FontType.Normal
    label.size = vec2(size.x-20, 35)
    pos = pos + vec2(0,35)

    local comboBox = scrollframe:createValueComboBox(Rect(pos+vec2(35,5),pos+vec2(200,25)), "onComboBoxSelected")
    cc.l.uiElementToSettingMap[comboBox.index] = "salvageStopOrder"
    cc.addOrdersToCombo(comboBox)
    pos = pos + vec2(0,35)

    local checkBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Salvage Nearest", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[checkBox.index] = "salvageSquadNearest"
    checkBox.tooltip = "Fighters will target the nearest wreckage to the squad (checked), \nor the one nearest to the mothership (unchecked)."
    checkBox.captionLeft = false
    checkBox.fontSize = 14
    pos = pos + vec2(0,35)

    return pos
end

return salvageCommand
