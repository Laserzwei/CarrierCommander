local mineCommand = {}

function mineCommand.initConfigUI(scrollframe, pos, size)
    local label = scrollframe:createLabel(pos, "Mining config", 15)
    label.tooltip = "Set the behaviour once the Mining-operation ends"
    label.fontSize = 15
    label.font = FontType.Normal
    label.size = vec2(size.x-20, 35)
    pos = pos + vec2(0,35)

    local comboBox = scrollframe:createValueComboBox(Rect(pos+vec2(35,5),pos+vec2(200,25)), "onComboBoxSelected")
    cc.l.uiElementToSettingMap[comboBox.index] = "mineStopOrder"
    cc.addOrdersToCombo(comboBox)
    pos = pos + vec2(0,35)

    local checkBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Mine all Asteroids", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[checkBox.index] ="mineAllSetting"
    checkBox.tooltip = "Determines wether all asteroids in a sector (checked), \nor only resource asteroids (unchecked) will be mined."
    checkBox.captionLeft = false
    checkBox.fontSize = 14
    pos = pos + vec2(0,35)

    local checkBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Mine Nearest", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[checkBox.index] = "mineSquadNearest"
    checkBox.tooltip = "Fighters will target the nearest asteroid to the squad (checked), \nor the one nearest to the mothership (unchecked)."
    checkBox.captionLeft = false
    checkBox.fontSize = 14
    pos = pos + vec2(0,35)

    return pos
end

return mineCommand
--end
