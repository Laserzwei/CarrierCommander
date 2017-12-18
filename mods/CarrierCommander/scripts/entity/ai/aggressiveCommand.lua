--if onServer() then
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")

--required Data
aggressiveCommand = {}
aggressiveCommand.prefix = nil
aggressiveCommand.active = false
aggressiveCommand.squads = {}               --[squadIndex] = squadIndex           --squads to manage
aggressiveCommand.controlledFighters = {}   --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
--data
aggressiveCommand.hostileThreshold = -40000
aggressiveCommand.tf = 0
aggressiveCommand.tfCounter = 0

--required UI
aggressiveCommand.needsButton = true
aggressiveCommand.inactiveButtonCaption = "Carrier - Start Attacking"
aggressiveCommand.activeButtonCaption = "Carrier - Stop Attacking"                 --Notice: the activeButtonCaption shows the caption WHILE the command is active
aggressiveCommand.activeTooltip = cc.l.actionTostringMap["idle"]
aggressiveCommand.inactiveTooltip = cc.l.actionTostringMap[-1]

function aggressiveCommand.init()
end

function aggressiveCommand.updateServer(timestep)
    aggressiveCommand.tf = aggressiveCommand.tf + timestep
    if aggressiveCommand.active then
        if aggressiveCommand.tf > 5 then
            aggressiveCommand.tf = 0
            if not valid(aggressiveCommand.enemyTarget) then
                if aggressiveCommand.findEnemy() then
                    aggressiveCommand.getSquadsToManage()
                    aggressiveCommand.attack()
                end
            end
            aggressiveCommand.tfCounter = aggressiveCommand.tfCounter + 1
            if aggressiveCommand.tfCounter > 4 and valid(aggressiveCommand.enemyTarget) then    --search for higher priority target
                aggressiveCommand.tfCounter = 0
                if aggressiveCommand.findEnemy() then
                    aggressiveCommand.getSquadsToManage()
                    aggressiveCommand.attack()
                end
            end
        end
    end
end

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
    checkBox.tooltip = "Determines wether enemy civil ships will be attacked (checkded), or not (unchecked)"
    checkBox.captionLeft = false
    checkBox.fontSize = 14
    pos = pos + vec2(0,35)

    local checkBox = scrollframe:createCheckBox(Rect(pos+vec2(0,5),pos+vec2(size.x-35, 25)), "Attack Stations", "onCheckBoxChecked")
    cc.l.uiElementToSettingMap[checkBox.index] = aggressiveCommand.prefix.."attackStations"
    checkBox.tooltip = "Determines wether enemy stations will be attacked (checkded), or not (unchecked)"
    checkBox.captionLeft = false
    checkBox.fontSize = 14
    pos = pos + vec2(0,35)

    return pos
end

function aggressiveCommand.registerTarget()
    if valid(aggressiveCommand.enemyTarget) then
        return aggressiveCommand.enemyTarget:registerCallback("onDestroyed", "enemyDestroyed")
    end
end

function aggressiveCommand.unregisterTarget(entity)
    if valid(entity) then
        return aggressiveCommand.enemyTarget:unregisterCallback("onDestroyed", "enemyDestroyed")
    end
    if valid(aggressiveCommand.enemyTarget) then
        return aggressiveCommand.enemyTarget:unregisterCallback("onDestroyed", "enemyDestroyed")
    end
end

function enemyDestroyed(index, lastDamageInflictor)
    if aggressiveCommand.findEnemy(index) then
        aggressiveCommand.attack()
    else
        cc.applyCurrentAction(aggressiveCommand.prefix, "idle")
    end
end

function aggressiveCommand.attack()
    if not valid(aggressiveCommand.enemyTarget) then
        if not aggressiveCommand.findEnemy() then print("invalid attack target"); cc.applyCurrentAction(aggressiveCommand.prefix, "idle") return end
    end
    local numSquads = 0
    local hangar = Hangar(Entity().index)
    local fighterController = FighterController(Entity().index)
    if not hangar then cc.applyCurrentAction(aggressiveCommand.prefix, "noHangar") return end

    for _,squad in pairs(aggressiveCommand.squads) do
        numSquads = numSquads + 1
        fighterController:setSquadOrders(squad, FighterOrders.Attack, aggressiveCommand.enemyTarget.index)
    end

    if numSquads > 0 then
        cc.applyCurrentAction(aggressiveCommand.prefix, FighterOrders.Attack, aggressiveCommand.enemyTarget.name)
    else
        print("T2")
        cc.applyCurrentAction(aggressiveCommand.prefix, "targetButNoFighter")
    end
    return numSquads
end

function aggressiveCommand.getSquadsToManage()
    local hangar = Hangar(Entity().index)
    if not hangar then cc.applyCurrentAction(aggressiveCommand.prefix, "noHangar") return end
    local hasChanged = false
    local oldLength = tablelength(aggressiveCommand.squads)
    local squads = {}
    for _,squad in pairs({hangar:getSquads()}) do
        if hangar:getSquadMainWeaponCategory(squad) == WeaponCategory.Armed then    --cargo fighters also have the weapon category armed- without a Weapon >.<
            if hangar:getSquadFighters(squad) > 0 and hangar:getFighter(squad,0).type == FighterType.Fighter then
                squads[squad] = squad
                if not aggressiveCommand.squads[squad] then
                    hasChanged = true
                end
            elseif hangar:getSquadFighters(squad) == 0 and hangar:getSquadFreeSlots(squad) < 12 then
                squads[squad] = squad
                if not aggressiveCommand.squads[squad] then
                    hasChanged = true
                end
            end
        end
    end

    aggressiveCommand.squads = squads
    local len = tablelength(squads)
    if (hasChanged  or oldLength ~= tablelength(squads)) and len > 0 then
        return true
    else
        if len == 0 then
            print("T3")
            cc.applyCurrentAction(aggressiveCommand.prefix, "targetButNoFighter")
        end
        return false
    end
end

-- check the sector for an enemy that can be attacked.
-- if there is one, assign enemyTarget
function aggressiveCommand.findEnemy(ignoredEntityIndex)
    local shipAI = ShipAI(Entity().index)
    if shipAI:isEnemyPresent(aggressiveCommand.hostileThreshold) then
        local ship = Entity()
        local oldEnemy = aggressiveCommand.enemyTarget

        if not aggressiveCommand.checkEnemy(oldEnemy, ignoredEntityIndex) then
            aggressiveCommand.enemyTarget = nil --in case ignoredEntityIndex is our current entity
            oldEnemy = nil
        end

        if ignoredEntityIndex then
            if aggressiveCommand.enemyTarget and aggressiveCommand.enemyTarget.index.number == ignoredEntityIndex.number then
                aggressiveCommand.enemyTarget = nil --in case ignoredEntityIndex is our current entity
                oldEnemy = nil
            end
        end

        local entities = {Sector():getEntitiesByComponent(ComponentType.Owner)} -- hopefully all possible enemies
        --local entities = {Sector():getEntities()}
        local nearest = math.huge
        local priority = 0
        if oldEnemy and aggressiveCommand.getPriority(oldEnemy) then priority = aggressiveCommand.getPriority(oldEnemy) + 1 end -- only take new target if priority is higher
        local hasTargetChanged = false
        for _, e in pairs(entities) do
            if aggressiveCommand.checkEnemy(e, ignoredEntityIndex) then
                local p = aggressiveCommand.getPriority(e)
                local dist = distance2(e.translationf, ship.translationf)
                if ((dist < nearest and priority <= p) or (priority < p)) then -- get a new target
                    nearest = dist
                    aggressiveCommand.enemyTarget = e
                    priority = p
                    hasTargetChanged = true
                end
            end
        end

        if valid(aggressiveCommand.enemyTarget) then
            --print(" FE Enemy", aggressiveCommand.enemyTarget.name, aggressiveCommand.enemyTarget.durability, hasTargetChanged)
            if hasTargetChanged then
                if oldEnemy and oldEnemy.durability > 0 then aggressiveCommand.unregisterTarget(oldEnemy) end
                aggressiveCommand.registerTarget()
                return true
            else
                return true
            end
        end
    end
    --No enemy found -> set Idle
    aggressiveCommand.setSquadsIdle()
    aggressiveCommand.enemyTarget = nil
    return false
end

function aggressiveCommand.getPriority(entity)
    if not valid(entity) then return -1 end
    local p = 0

    if(entity.isShip) then p = cc.Config.Settings.Aggressive.priorities.ship
    elseif entity.isStation and cc.Config.Settings.Aggressive.attackStations then p = cc.Config.Settings.Aggressive.priorities.station
    elseif entity.isFighter and cc.Config.Settings.Aggressive.attackFighters then p = cc.Config.Settings.Aggressive.priorities.fighter
    else p = -1 end -- do not attack other entities
    if entity:hasScript("story/wormholeguardian.lua") then p = 15 end -- Lets kill adds first, then the guardian

    return p
end
--checks for hostility, xsotan ownership, civil-config, station-config
function aggressiveCommand.checkEnemy(e, ignored)
    if not valid(e) then return false end
    if ignored and e.index.number == ignored.number then return false end
    local faction = Faction()
    local b = false
    if e.factionIndex and faction:getRelations(e.factionIndex) <= aggressiveCommand.hostileThreshold then b = true -- low faction
    elseif isXsotan(e.factionIndex) then b = true end-- xsotan ship
    if e:getValue("civil") and not cc.settings[aggressiveCommand.prefix.."spareCivilsSetting"] then
        b = false
    end
    if e.isStation and not cc.settings[aggressiveCommand.prefix.."attackStations"] then

        b = false
    end

    return b
end
function isXsotan(factionIndex)
    local xsotan = Galaxy():findFaction("The Xsotan"%_T)
    if not xsotan then
        return false
    end
    return factionIndex == xsotan.index
end
function aggressiveCommand.setSquadsIdle()
    local hangar = Hangar(Entity().index)
    local fighterController = FighterController(Entity().index)
    if not fighterController or not hangar then
        cc.applyCurrentAction(aggressiveCommand.prefix, "noHangar")
        return
    end

    local order = cc.settings["attackStopOrder"] or FighterOrders.Return
    local squads = {}
    for _,squad in pairs(aggressiveCommand.squads) do
        fighterController:setSquadOrders(squad, order, Entity().index)
        squads[squad] = squad
    end
    return order, Entity().name, squads
end

function aggressiveCommand.fighterAdded(entityId, squadIndex, fighterIndex, landed)
    if aggressiveCommand.active then
        if not landed then
            if aggressiveCommand.getSquadsToManage() then
                aggressiveCommand.attack()
            end
        end
    end
end

function aggressiveCommand.fighterRemove(entityId, squadIndex, fighterIndex, started) --entityTemplate is not accessable, even though it's supposed to be called BEFORE the fighter gets removed
    if aggressiveCommand.active then
        if not started then
            if aggressiveCommand.getSquadsToManage() then
                aggressiveCommand.attack()
            end
        end
    end
end

function aggressiveCommand.squadAdded(entityId, index)-- gets also called on squadRename
    if aggressiveCommand.active then
        if aggressiveCommand.getSquadsToManage() then
            aggressiveCommand.attack()
        end
    end
end
-- Notice: The squad with <index> is not available in the Hangar when this is fired
function aggressiveCommand.squadRemove(entityId, index)
    if aggressiveCommand.active then
        if aggressiveCommand.getSquadsToManage() then
            aggressiveCommand.attack()
        end
    end
end

function aggressiveCommand.onSectorChanged(x, y)
    if aggressiveCommand.active then
        if aggressiveCommand.findEnemy() then
            aggressiveCommand.getSquadsToManage()
            aggressiveCommand.attack()
        end
    end
end

function aggressiveCommand.flyableCreated(entity)
    if aggressiveCommand.active then
        if aggressiveCommand.enemyTarget then
            if aggressiveCommand.checkEnemy(entity) then
                local ship = Entity()

                local prioCurrent = aggressiveCommand.getPriority(aggressiveCommand.enemyTarget)
                local distCurrent = distance2(aggressiveCommand.enemyTarget.translationf, ship.translationf)

                local prioNew = aggressiveCommand.getPriority(entity)
                local distNew = distance2(entity.translationf, ship.translationf)
                if ((distNew < distCurrent and prioCurrent <= prioNew) or (prioCurrent < prioNew)) then
                    aggressiveCommand.enemyTarget = entity
                    aggressiveCommand.getSquadsToManage()
                    aggressiveCommand.attack()
                end
            end
        else
            if aggressiveCommand.findEnemy() then
                aggressiveCommand.getSquadsToManage()
                aggressiveCommand.attack()
            end
        end
    end
end

--<button> is clicked button-Object onClient and prefix onServer
function aggressiveCommand.activate(button)
    if onClient() then
        cc.l.tooltipadditions[aggressiveCommand.prefix] = "+ Attacking Enemies"
        cc.setAutoAssignTooltip(cc.autoAssignButton.onPressedFunction == "StopAutoAssign")

        return
    end
    -- space for stuff to do e.g. scanning all squads for suitable fighters/WeaponCategories etc.
    aggressiveCommand.squads = {}
    if not aggressiveCommand.getSquadsToManage() then print("T1");cc.applyCurrentAction(aggressiveCommand.prefix, "targetButNoFighter") return end

    if aggressiveCommand.findEnemy() then
        aggressiveCommand.attack()
    else
        cc.applyCurrentAction(aggressiveCommand.prefix, "idle")
    end
end

--<button> is clicked button-Object onClient and prefix onServer
function aggressiveCommand.deactivate(button)
    if onClient() then
        cc.l.tooltipadditions[aggressiveCommand.prefix] = "- Stopped Attacking Enemies"
        cc.setAutoAssignTooltip(cc.autoAssignButton.onPressedFunction == "StopAutoAssign")
        return
    end
    -- space for stuff to do e.g. landing your fighters
    -- When docking: Make sure to not reset template.squads
    cc.applyCurrentAction(aggressiveCommand.prefix, aggressiveCommand.setSquadsIdle())
    aggressiveCommand.targetEnemy = nil
end

return aggressiveCommand
--end
