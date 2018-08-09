local aggressiveCommand = {}
aggressiveCommand.prefix = "attack"

function aggressiveCommand.initConfigUI(scrollframe, pos, size)

    local label = scrollframe:createLabel(pos, "Attack config", 15)
    label.tooltip = "Set the behaviour once the Attack-operation ends"
    label.fontSize = 15
    label.font = FontType.Normal
    label.size = vec2(size.x-20, 35)
    pos = pos + vec2(0,35)

    local comboBox = scrollframe:createValueComboBox(Rect(pos+vec2(35,5),pos+vec2(200,25)), "onComboBoxSelected")
    cc.l.uiElementToSettingMap[comboBox.index] = "attackStopOrder"
    cc.addOrdersToCombo(comboBox)
    pos = pos + vec2(0,35)
    --attack Civils
    local checkBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Attack Civils", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[checkBox.index] = aggressiveCommand.prefix.."spareCivilsSetting"
    checkBox.tooltip = "Determines wether enemy civil ships will be attacked (checked), or not (unchecked)"
    checkBox.captionLeft = false
    checkBox.fontSize = 14
    pos = pos + vec2(0,35)

    local checkBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Attack Stations", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[checkBox.index] = "attackStations"
    checkBox.tooltip = "Determines wether enemy stations will be attacked (checked), or not (unchecked)"
    checkBox.captionLeft = false
    checkBox.fontSize = 14
    pos = pos + vec2(0,35)

    local checkBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Aggressive Targetting", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[checkBox.index] = "attackSquadNearest"
    checkBox.tooltip = "Attack ship closest to squad (checked), or closest to ship (unchecked)"
    checkBox.captionLeft = false
    checkBox.fontSize = 14
    pos = pos + vec2(0,35)

    return pos
end

return aggressiveCommand
--end
