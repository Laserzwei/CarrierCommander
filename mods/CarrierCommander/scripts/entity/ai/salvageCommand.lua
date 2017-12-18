--if onServer() then
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")

--required Data
salvageCommand = {}
salvageCommand.prefix = nil
salvageCommand.active = false
salvageCommand.squads = {}                  --[squadIndex] = squadIndex           --squads to manage
salvageCommand.controlledFighters = {}      --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
--data

--required UI
salvageCommand.needsButton = true
salvageCommand.inactiveButtonCaption = "Carrier - Start Salvaging"
salvageCommand.activeButtonCaption = "Carrier - Stop Salvaging"                 --Notice: the activeButtonCaption shows the caption WHILE the command is active
salvageCommand.activeTooltip = cc.l.actionTostringMap[6]
salvageCommand.inactiveTooltip = cc.l.actionTostringMap[-1]

function salvageCommand.init()

end

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

    return pos
end

function salvageCommand.registerTarget()
    if valid(salvageCommand.salvagableWreck) then
        return salvageCommand.salvagableWreck:registerCallback("onDestroyed", "wreckageDestroyed")
    end
end

function salvageCommand.unregisterTarget()
    if valid(salvageCommand.salvagableWreck) then
        return salvageCommand.salvagableWreck:unregisterCallback("onDestroyed", "wreckageDestroyed")
    end
end

function wreckageDestroyed(index, lastDamageInflictor)
    if salvageCommand.findWreckage() then
        salvageCommand.salvage()
    else
        cc.applyCurrentAction(salvageCommand.prefix, salvageCommand.setSquadsIdle())
    end
end

function salvageCommand.salvage()
    if not valid(salvageCommand.salvagableWreck) then
        if not salvageCommand.findWreckage() then
            cc.applyCurrentAction(salvageCommand.prefix, salvageCommand.setSquadsIdle())
            return
        end
    end
    local numSquads = 0
    local hangar = Hangar(Entity().index)
    local fighterController = FighterController(Entity().index)
    if not hangar then cc.applyCurrentAction(salvageCommand.prefix, "noHangar") return end

    local squads = {}
    for _,squad in pairs(salvageCommand.squads) do
        numSquads = numSquads + 1
        fighterController:setSquadOrders(squad, FighterOrders.Attack, salvageCommand.salvagableWreck.index)
    end

    if numSquads > 0 then
        cc.applyCurrentAction(salvageCommand.prefix, 6)
    else
        cc.applyCurrentAction(salvageCommand.prefix, "targetButNoFighter")
    end
    return numSquads
end

function salvageCommand.getSquadsToManage()
    local hangar = Hangar(Entity().index)
    if not hangar then cc.applyCurrentAction(salvageCommand.prefix, "noHangar") return end
    local hasChanged = false
    local oldLength = tablelength(salvageCommand.squads)
    local squads = {}
    for _,squad in pairs({hangar:getSquads()}) do
        if hangar:getSquadMainWeaponCategory(squad) == WeaponCategory.Salvaging then
            squads[squad] = squad
            if not salvageCommand.squads[squad] then
                hasChanged = true
            end
        end
    end

    salvageCommand.squads = squads
    local len = tablelength(squads)
    if hasChanged or oldLength ~= tablelength(squads) and len > 0 then
        return true
    else
        if len == 0 then
            cc.applyCurrentAction(salvageCommand.prefix, "targetButNoFighter")
        end
        return false
    end
end

-- check the sector for an wreckage that can be salvaged.
-- if there is one, assign salvagableWreck
function salvageCommand.findWreckage()
    local ship = Entity()
    local sector = Sector()
    local oldWreckNum

    if valid(salvageCommand.salvagableWreck) then -- because even after the "wreckagedestroyed" event fired it still is part of sector:getEntitiesByType(EntityType.Wreckage) >,<
        oldWreckNum = salvageCommand.salvagableWreck.index.number
        salvageCommand.unregisterTarget()
    end

    salvageCommand.salvagableWreck = nil

    local wreckages = {sector:getEntitiesByType(EntityType.Wreckage)}
    local nearest = math.huge
    --Go after closest wreckage first
    for _, w in pairs(wreckages) do
        local resources = w:getMineableResources()
        if resources ~= nil and resources > 25 and oldWreckNum ~= w.index.number then
            local dist = distance2(w.translationf, ship.translationf)
            if dist < nearest then
                nearest = dist
                salvageCommand.salvagableWreck = w
            end
        end
    end

    if valid(salvageCommand.salvagableWreck) then
        salvageCommand.registerTarget()
        return true
    else
        return false
    end
end

function salvageCommand.setSquadsIdle()
    local hangar = Hangar(Entity().index)
    local fighterController = FighterController(Entity().index)
    if not fighterController or not hangar then
        cc.applyCurrentAction(salvageCommand.prefix, "noHangar")
        return
    end

    local order = cc.settings["salvageStopOrder"] or FighterOrders.Return
    local squads = {}
    for _,squad in pairs(salvageCommand.squads) do
        fighterController:setSquadOrders(squad, order, Entity().index)
        squads[squad] = squad
    end
    return order, Entity().name, squads
end

function salvageCommand.fighterAdded(entityId, squadIndex, fighterIndex, landed)
    if salvageCommand.active then
        if not landed then
            if salvageCommand.getSquadsToManage() then
                salvageCommand.salvage()
            end
        end
    end
end

function salvageCommand.fighterRemove(entityId, squadIndex, fighterIndex, started) --entityTemplate is not accessable, even though it's supposed to be called BEFORE the fighter gets removed
    if salvageCommand.active then
        if salvageCommand.getSquadsToManage() then
            salvageCommand.salvage()
        end
    end
end

function salvageCommand.squadAdded(entityId, index)-- gets also called on squadRename
    if salvageCommand.active then
        if salvageCommand.getSquadsToManage() then
            salvageCommand.salvage()
        end
    end
end
-- Notice: The squad with <index> is not available in the Hangar when this is fired
function salvageCommand.squadRemove(entityId, index)
    if salvageCommand.active then
        if salvageCommand.getSquadsToManage() then
            salvageCommand.salvage()
        end
    end
end

function salvageCommand.onSectorChanged(x, y)
    if salvageCommand.active then
        if salvageCommand.findWreckage() then
            salvageCommand.getSquadsToManage()
            salvageCommand.salvage()
        else
            cc.applyCurrentAction(salvageCommand.prefix, salvageCommand.setSquadsIdle())
        end
    end
end

function salvageCommand.wreckageCreated(entity)
    if salvageCommand.active then
        if not valid(salvageCommand.salvagableWreck) then
            local resources = entity:getMineableResources()
            if resources ~= nil and resources > 25 then
                salvageCommand.salvagableWreck = entity
                salvageCommand.salvage()
            end
        end
    end
end

--<button> is clicked button-Object onClient and prefix onServer
function salvageCommand.activate(button)
    if onClient() then
        cc.l.tooltipadditions[salvageCommand.prefix] = "+ Salvaging"
        cc.setAutoAssignTooltip(cc.autoAssignButton.onPressedFunction == "StopAutoAssign")

        return
    end
    -- space for stuff to do e.g. scanning all squads for suitable fighters/WeaponCategories etc.
    salvageCommand.squads = {}
    if not salvageCommand.getSquadsToManage() then cc.applyCurrentAction(salvageCommand.prefix, "targetButNoFighter") return end
    if salvageCommand.findWreckage() then
        salvageCommand.salvage()
    else
        cc.applyCurrentAction(salvageCommand.prefix, "idle")
    end
end

--<button> is clicked button-Object onClient and prefix onServer
function salvageCommand.deactivate(button)
    if onClient() then
        cc.l.tooltipadditions[salvageCommand.prefix] = "- Stopped Salvaging"
        cc.setAutoAssignTooltip(cc.autoAssignButton.onPressedFunction == "StopAutoAssign")
        return
    end
    -- space for stuff to do e.g. landing your fighters
    -- When docking: Make sure to not reset template.squads
    cc.applyCurrentAction(salvageCommand.prefix, salvageCommand.setSquadsIdle())
    salvageCommand.salvagableWreck = nil
end

return salvageCommand
--end
