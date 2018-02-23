--if onServer() then
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")

--required Data
dummyCommand = {}
dummyCommand.prefix = "dummyCommand"
dummyCommand.active = false
dummyCommand.squads = {}            --[squadIndex] = squadIndex           --squads to manage
dummyCommand.controlledFighters = {}   --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
--data
dummyCommand.responseTime = 25
dummyCommand.passedTime = 0
dummyCommand.starting = false

--required UI
dummyCommand.needsButton = true
dummyCommand.inactiveButtonCaption = "Carrier - Dummy Start"
dummyCommand.activeButtonCaption = "Carrier - Dummy Stop"                 --Notice: the activeButtonCaption shows the caption WHILE the command is active
dummyCommand.activeTooltip = "Dummying around"
dummyCommand.inactiveTooltip = "Dummy-Not doing anything."



function dummyCommand.init()
    if onClient() then
        cc.l.actionTostringMap[dummyCommand.prefix.."customStart"] = "Dummy Custom Start Message"
        cc.l.actionToColorMap[dummyCommand.prefix.."customStart"] = ColorRGB(0.0, 0.0, 1)
    end
end

function dummyCommand.initConfigUI(scrollframe, pos, size)
    local label = scrollframe:createLabel(pos, "Dummy config", 15)
	label.tooltip = "Set the behaviour once the Dummy-operation ends"
	label.fontSize = 15
	label.font = FontType.Normal
	label.size = vec2(size.x-20, 35)
	pos = pos + vec2(0,35)

	local comboBox = scrollframe:createValueComboBox(Rect(pos+vec2(35,5),pos+vec2(200,25)), "onComboBoxSelected")
	cc.l.uiElementToSettingMap[comboBox.index] = dummyCommand.prefix.."StopOrder"   -- it is totally possible to use "dummyCommandStopOrder", insted or another selfcreated string
	cc.addOrdersToCombo(comboBox)
	pos = pos + vec2(0,35)

    local checkBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Random Color", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[checkBox.index] = dummyCommand.prefix.."colorSetting"
	checkBox.tooltip = "Determines wether the colors will be changed to a Random Value every time the order changes.\n *Will not lock the color after restart."
    checkBox.captionLeft = false
    checkBox.fontSize = 14
	pos = pos + vec2(0,35)

    local slider = scrollframe:createSlider(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), 0, 1.0, 255, "Caption", "onSliderValueChanged")
    cc.l.uiElementToSettingMap[slider.index] = dummyCommand.prefix.."redValue"
	slider.tooltip = "Sets the RedValue of the Icon."
    --slider.description = "Description."
    --slider.unit = "Units."
    --slider.showValue = true
    --slider.showCaption = true
    --slider.showDescription = true
	pos = pos + vec2(0,35)

    return pos
end
function dummyCommand.updateServer(timeStep)
    if dummyCommand.active then
        dummyCommand.passedTime = dummyCommand.passedTime + timeStep
        if dummyCommand.passedTime >= dummyCommand.responseTime then
            dummyCommand.passedTime = dummyCommand.passedTime - dummyCommand.responseTime   --excess time is accounted for (proper way of resetting timmers; instead of set to 0)
            local controller = FighterController(Entity().index)
            if not dummyCommand.starting then
                dummyCommand.starting = true
                print(Entity().name,"start",dummyCommand.squads[1])
                controller:setSquadOrders(dummyCommand.squads[1], FighterOrders.Defend, Entity().index)  -- this also starts the fighters
                broadcastInvokeClientFunction("randomColor", cc.settings[dummyCommand.prefix.."redValue"]or math.random(), math.random(), math.random())
            else
                dummyCommand.starting = false
                print(Entity().name,"Land",dummyCommand.squads[1])
                controller:setSquadOrders(dummyCommand.squads[1], FighterOrders.Return, Entity().index)
                broadcastInvokeClientFunction("randomColor", cc.settings[dummyCommand.prefix.."redValue"]or math.random(), math.random(), math.random())
            end
        end
    end
end

function randomColor(R, G, B)
    if cc.commands[dummyCommand.prefix].statusPicture and cc.settings[dummyCommand.prefix.."colorSetting"] then --on non playerships, UI is not initialized before interaction
        cc.commands[dummyCommand.prefix].statusPicture.color = ColorRGB(R, G, B)
    end
end

function dummyCommand.getAllMyFightersCalled()
    if dummyCommand.active then
        print("allFightersCalled")
    end
end

function dummyCommand.getSquadsToManage()
    local hangar = Hangar(Entity().index)
    if not hangar then return end
    local squad = hangar:getSquads()
    dummyCommand.squads[squad] = squad
end

function dummyCommand.setSquadsIdle()
    local hangar = Hangar(Entity().index)
    local fighterController = FighterController(Entity().index)
    if not fighterController or not hangar then
        print("Carrier - Salvage couldn't dock Fighters, hangar and/or Fightercontroller missing")
        return
    end
    if not next(dummyCommand.squads) then return -1 end
    local order = cc.settings[dummyCommand.prefix.."StopOrder"] or FighterOrders.Return

    fighterController:setSquadOrders(dummyCommand.squads[1], order, Entity().index)
    return order, Entity().name, dummyCommand.squads
end

--whan a player leaves a ship into his drone, this is fired for every squad
function dummyCommand.squadOrdersChanged(entityId, squadIndex, orders, targetId)
    if dummyCommand.active then
        local e = Entity(targetId)
        if valid(e) then e = e.name else e = nil end
    	print(Entity().name, "order changed squad",squadIndex, "to", cc.l.actionTostringMap[orders], e or "target")
    end
end

function dummyCommand.fighterStarted(entityId, squadIndex, fighterId)
    if dummyCommand.active then
        local fighter = Entity(fighterId)
        print("Cargo space",fighter.maxCargoSpace)
    	local fAI = FighterAI(fighterId)
    	if fAI then
    		print(Entity().name, "fighter started squad", squadIndex, cc.l.actionTostringMap[fAI.orders])
    	else
    	    print(Entity().name, "fighter started squad", squadIndex, Entity(fighterId).name)
    	end
    end
end

function dummyCommand.fighterLanded(entityId, squadIndex, fighterId)
    if dummyCommand.active then
        print(Entity().name, "fighter landed squad", squadIndex, Entity(fighterId).name)
    end
end

function dummyCommand.fighterAdded(entityId, squadIndex, fighterIndex, landed)
    if dummyCommand.active then
        local hangar = Hangar(Entity().index)
	       print(Entity().name, "fighter added to squad", squadIndex, fighterIndex, landed, hangar:getFighter(squadIndex, fighterIndex).weaponName)
    end
end

function dummyCommand.fighterRemove(entityId, squadIndex, fighterIndex, started) --entityTemplate is not accessable, even though it's supposed to be called BEFORE the fighter gets removed
    if dummyCommand.active then
        print(Entity().name, "fighter removed from squad", squadIndex, fighterIndex, started)
    end
end

function dummyCommand.squadAdded(entityId, index)-- gets also called on squadRename
    if dummyCommand.active then
        if index <= dummyCommand.squads then
            dummyCommand.getSquadsToManage()
        end
    	local hangar = Hangar(Entity().index)
    	print(Entity().name, "Squad Changed, added", index, hangar:getSquadName(index))
    end
end
-- Notice: The squad with <index> is not available in the Hangar when this is fired
function dummyCommand.squadRemove(entityId, index)
    if dummyCommand.active then
        if index == dummyCommand.squads then
            dummyCommand.getSquadsToManage()
        end
	print(Entity().name, "Squad Changed, remove", index)
    end
end

function dummyCommand.onSectorChanged(x, y)
    if dummyCommand.active then
        print("SectorChanged")
    end
end

--<button> is clicked button-Object onClient and prefix onServer
function dummyCommand.activate(button)
    if onClient() then
        cc.l.tooltipadditions[dummyCommand.prefix] = "Dummying"
        cc.setAutoAssignTooltip(cc.autoAssignButton.onPressedFunction == "StopAutoAssign")

        cc.applyCurrentAction(dummyCommand.prefix, dummyCommand.prefix.."customStart")
        local color = cc.l.actionToColorMap[dummyCommand.prefix.."customStart"]
        color.r = cc.settings[dummyCommand.prefix.."redValue"]or 0.1
        cc.commands[dummyCommand.prefix].statusPicture.color = color
        return
    end
    -- space for stuff to do e.g. scanning all squads for suitable fighters/WeaponCategories etc.
    dummyCommand.squads = {}
    dummyCommand.starting = false
    dummyCommand.getSquadsToManage()
end

--<button> is clicked button-Object onClient and prefix onServer
function dummyCommand.deactivate(button)
    if onClient() then
        cc.l.tooltipadditions[dummyCommand.prefix] = "- Stopped Dummy command"
        cc.setAutoAssignTooltip(cc.autoAssignButton.onPressedFunction == "StopAutoAssign")
        return
    end
    -- space for stuff to do e.g. landing your fighters
    -- When docking: Make sure to not reset template.squads
    cc.applyCurrentAction(dummyCommand.prefix, dummyCommand.setSquadsIdle())
end

return dummyCommand
--end
