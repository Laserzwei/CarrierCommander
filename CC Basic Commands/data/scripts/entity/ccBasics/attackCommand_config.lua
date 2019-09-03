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
    cc.l.uiElementToSettingMap[comboBox.index] = {name = "attackSquadNearest", default = FighterOrders.Return}
    cc.addOrdersToCombo(comboBox)
    pos = pos + vec2(0,35)

    --attack Civils
    local civilCheckBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Attack Civils", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[civilCheckBox.index] = {name = "attackSpareCivilsSetting", default = false}
    civilCheckBox.tooltip = "Determines wether enemy civil ships will be attacked (checked), or not (unchecked)"
    civilCheckBox.captionLeft = false
    civilCheckBox.fontSize = 14
    pos = pos + vec2(0,35)

    local stationCheckBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Attack Stations", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[stationCheckBox.index] = {name = "attackStations", default = false}
    stationCheckBox.tooltip = "Determines wether enemy stations will be attacked (checked), or not (unchecked)"
    stationCheckBox.captionLeft = false
    stationCheckBox.fontSize = 14
    pos = pos + vec2(0,35)

    local slider = scrollframe:createSlider(Rect(pos+vec2(0,-5),pos+vec2(size.x-75, 40)), 1, 50, 49, "", "onSliderValueChanged")
    cc.l.uiElementToSettingMap[slider.index] = {name = "attack_reevaluationDistance", default = 5}
    slider.caption = "Re-targeting threshold distance"
    slider.description = ""
    slider.unit = "km"
    pos = pos + vec2(0,35)

    local targetingCheckBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Aggressive Targetting", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[targetingCheckBox.index] = {name = "attackSquadNearest", default = false}
    targetingCheckBox.tooltip = "Attack ship closest to squad (checked), or closest to ship (unchecked)"
    targetingCheckBox.captionLeft = false
    targetingCheckBox.fontSize = 14
    pos = pos + vec2(0,35)

    local vanillaCheckBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Unsupervised Targeting", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[vanillaCheckBox.index] = {name = "vanillaAttackPattern", default = false}
    vanillaCheckBox.tooltip = "(checked) This will use pure vanilla targeting: Attacking the closest target and only changing it after it died."
    .."\n - No priority for Fighters/bosses/stations etc."
    .."\n - No chasing the target closest to the fighters."
    .."\n - No preventions for civils."
    .."\n + Highly performant (recommended, when using endgame fighters)"
    vanillaCheckBox.captionLeft = false
    vanillaCheckBox.fontSize = 14
    pos = pos + vec2(0,35)

    if _G["cc"].Config.forceUnsupervisedTargeting then
        civilCheckBox:setCheckedNoCallback(false)
        civilCheckBox.active = false
        stationCheckBox:setCheckedNoCallback(false)
        stationCheckBox.active = false
        targetingCheckBox:setCheckedNoCallback(false)
        targetingCheckBox.active = false
        vanillaCheckBox:setCheckedNoCallback(true)
        vanillaCheckBox.active = false
        vanillaCheckBox.tooltip = "(checked) This will use pure vanilla targeting: Attacking the closest target and only changing it after it died."
        .."\n - No priority for Fighters/bosses/stations etc."
        .."\n - No chasing the target closest to the fighters."
        .."\n - No preventions for civils."
        .."\n + Highly performant (recommended, when using endgame fighters)"
        .."\n Unsupervised targeting is forced by the server-config!"
    end

    return pos
end

return aggressiveCommand
--end
