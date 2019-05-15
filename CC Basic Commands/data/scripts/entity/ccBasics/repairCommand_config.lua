local repairCommand = {}

function repairCommand.initConfigUI(scrollframe, pos, size)
    local label = scrollframe:createLabel(pos, "Repair config", 15)
    label.tooltip = "Set the behaviour once the Rpair-operation ends"
    label.fontSize = 15
    label.font = FontType.Normal
    label.size = vec2(size.x-20, 35)
    pos = pos + vec2(0,35)

    local comboBox = scrollframe:createValueComboBox(Rect(pos+vec2(35,5),pos+vec2(200,25)), "onComboBoxSelected")
    cc.l.uiElementToSettingMap[comboBox.index] = "repairStopOrder"
    cc.addOrdersToCombo(comboBox)
    pos = pos + vec2(0,35)

    local checkBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Repair ALL friendly", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[checkBox.index] ="repairFriendlySetting"
    checkBox.tooltip = "Determines wether all friendly (relation > -5000) ships in a sector will be repaired by fighters (checked), \nor only those of your own faction (unchecked) will be repaired."
    checkBox.captionLeft = false
    checkBox.fontSize = 14
    pos = pos + vec2(0,35)

    local checkBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Repair lowest HP first", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[checkBox.index] = "repairLowHPSetting"
    checkBox.tooltip = "Fighters will repair the target with the lowest HP (in %) first (checked), \nor the one nearest to the mothership (unchecked)."
    checkBox.captionLeft = false
    checkBox.fontSize = 14
    pos = pos + vec2(0,35)

    return pos
end

return repairCommand
--end
