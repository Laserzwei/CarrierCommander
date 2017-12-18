--if onServer() then
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")

--required Data
mineCommand = {}
mineCommand.prefix = nil
mineCommand.active = false
mineCommand.squads = {}                 --[squadIndex] = squadIndex           --squads to manage
mineCommand.controlledFighters = {}     --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
--data

--required UI
mineCommand.needsButton = true
mineCommand.inactiveButtonCaption = "Carrier - Start Mining"
mineCommand.activeButtonCaption = "Carrier - Stop Mining"                 --Notice: the activeButtonCaption shows the caption WHILE the command is active
mineCommand.activeTooltip = cc.l.actionTostringMap[5]
mineCommand.inactiveTooltip = cc.l.actionTostringMap[-1]

function mineCommand.init()

end

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
    cc.l.uiElementToSettingMap[checkBox.index] = "mineAllSetting"
    checkBox.tooltip = "Determines wether all asteroids in a sector (checkded), \nor only resource asteroids (unchecked) will be mined."
    checkBox.captionLeft = false
    checkBox.fontSize = 14
    pos = pos + vec2(0,35)

    return pos
end

function mineCommand.registerTarget()
    if valid(mineCommand.minableAsteroid) then
        return mineCommand.minableAsteroid:registerCallback("onDestroyed", "asteroidDestroyed")
    end
end

function mineCommand.unregisterTarget()
    if valid(mineCommand.minableAsteroid) then
        return mineCommand.minableAsteroid:unregisterCallback("onDestroyed", "asteroidDestroyed")
    end
end

function asteroidDestroyed(index, lastDamageInflictor)
    print("asteroid destroyed fired")
    if mineCommand.findMinableAsteroid() then
        mineCommand.mine()
    else
        cc.applyCurrentAction(mineCommand.prefix, mineCommand.setSquadsIdle())
    end
end

function mineCommand.mine()
    if not valid(mineCommand.minableAsteroid) then
        if not mineCommand.findMinableAsteroid() then
            cc.applyCurrentAction(mineCommand.prefix, mineCommand.setSquadsIdle())
            return
        end
    end
    local numSquads = 0
    local hangar = Hangar(Entity().index)
    local fighterController = FighterController(Entity().index)
    if not hangar then cc.applyCurrentAction(mineCommand.prefix, "noHangar") return end

    local squads = {}
    for _,squad in pairs(mineCommand.squads) do
        numSquads = numSquads + 1
        fighterController:setSquadOrders(squad, FighterOrders.Attack, mineCommand.minableAsteroid.index)
    end

    if numSquads > 0 then
        cc.applyCurrentAction(mineCommand.prefix, 5)
    else
        cc.applyCurrentAction(mineCommand.prefix, "targetButNoFighter")
    end
    return numSquads
end

function mineCommand.getSquadsToManage()
    local hangar = Hangar(Entity().index)
    if not hangar then cc.applyCurrentAction(mineCommand.prefix, "noHangar") return end
    local hasChanged = false
    local oldLength = tablelength(mineCommand.squads)
    local squads = {}
    for _,squad in pairs({hangar:getSquads()}) do
        if hangar:getSquadMainWeaponCategory(squad) == WeaponCategory.Mining then
            squads[squad] = squad
            if not mineCommand.squads[squad] then
                hasChanged = true
            end
        end
    end

    mineCommand.squads = squads
    local len = tablelength(squads)
    if hasChanged or oldLength ~= tablelength(squads) and len > 0 then
        return true
    else
        if len == 0 then
            cc.applyCurrentAction(mineCommand.prefix, "targetButNoFighter")
        end
        return false
    end
end

-- check the sector for an asteroid that can be mined.
-- if there is one, assign minableAsteroid
function mineCommand.findMinableAsteroid()
    local ship = Entity()
    local sector = Sector()
    local oldAstroNum

    if valid(mineCommand.minableAsteroid) then -- because even after the "asteroiddestroyed" event fired it still is part of sector:getEntitiesByType(EntityType.Asteroid) >,<
        oldAstroNum = mineCommand.minableAsteroid.index.number
        mineCommand.unregisterTarget()
    end

    mineCommand.minableAsteroid = nil

    local asteroids = {sector:getEntitiesByType(EntityType.Asteroid)}
    local nearest = math.huge
    --Go after closest asteroids first
    for _, a in pairs(asteroids) do
        local resources = a:getMineableResources()
        if ((resources ~= nil and resources > 0) or cc.settings["mineAllSetting"]) and a.index.number ~= oldAstroNum then
            local dist = distance2(a.translationf, ship.translationf)
            if dist < nearest then
                nearest = dist
                mineCommand.minableAsteroid = a
            end
        end
    end

    if valid(mineCommand.minableAsteroid) then
        mineCommand.registerTarget()
        return true
    else
        return false
    end
end

function mineCommand.setSquadsIdle()
    local hangar = Hangar(Entity().index)
    local fighterController = FighterController(Entity().index)
    if not fighterController or not hangar then
        cc.applyCurrentAction(mineCommand.prefix, "noHangar")
        return
    end

    local order = cc.settings["mineStopOrder"] or FighterOrders.Return
    local squads = {}
    for _,squad in pairs(mineCommand.squads) do
        fighterController:setSquadOrders(squad, order, Entity().index)
        squads[squad] = squad
    end
    return order, Entity().name, squads
end

function mineCommand.fighterAdded(entityId, squadIndex, fighterIndex, landed)
    if mineCommand.active then
        if not landed then
            if mineCommand.getSquadsToManage() then
                mineCommand.mine()
            end
        end
    end
end

function mineCommand.fighterRemove(entityId, squadIndex, fighterIndex, started) --entityTemplate is not accessable, even though it's supposed to be called BEFORE the fighter gets removed
    if mineCommand.active then
        if mineCommand.getSquadsToManage() then
            mineCommand.mine()
        end
    end
end

function mineCommand.squadAdded(entityId, index)-- gets also called on squadRename
    if mineCommand.active then
        if mineCommand.getSquadsToManage() then
            mineCommand.mine()
        end
    end
end
-- Notice: The squad with <index> is not available in the Hangar when this is fired
function mineCommand.squadRemove(entityId, index)
    if mineCommand.active then
        if mineCommand.getSquadsToManage() then
            mineCommand.mine()
        end
    end
end

function mineCommand.onSectorChanged(x, y)
    if mineCommand.active then
        if mineCommand.findMinableAsteroid() then
            mineCommand.getSquadsToManage()
            mineCommand.mine()
        else
            cc.applyCurrentAction(mineCommand.prefix, mineCommand.setSquadsIdle())
        end
    end
end

--<button> is clicked button-Object onClient and prefix onServer
function mineCommand.activate(button)
    if onClient() then
        cc.l.tooltipadditions[mineCommand.prefix] = "+ Mining"
        cc.setAutoAssignTooltip(cc.autoAssignButton.onPressedFunction == "StopAutoAssign")

        return
    end
    -- space for stuff to do e.g. scanning all squads for suitable fighters/WeaponCategories etc.
    mineCommand.squads = {}
    if not mineCommand.getSquadsToManage() then cc.applyCurrentAction(mineCommand.prefix, "targetButNoFighter") return end
    if mineCommand.findMinableAsteroid() then
        mineCommand.mine()
    else
        cc.applyCurrentAction(mineCommand.prefix, "idle")
    end
end

--<button> is clicked button-Object onClient and prefix onServer
function mineCommand.deactivate(button)
    if onClient() then
        cc.l.tooltipadditions[mineCommand.prefix] = "- Stopped Mining"
        cc.setAutoAssignTooltip(cc.autoAssignButton.onPressedFunction == "StopAutoAssign")
        return
    end
    -- space for stuff to do e.g. landing your fighters
    -- When docking: Make sure to not reset template.squads
    cc.applyCurrentAction(mineCommand.prefix, mineCommand.setSquadsIdle())
    mineCommand.minableAsteroid = nil
end

return mineCommand
--end
