if not cc then print("[CC-Attack]", "Something went wrong CC mainscript not found") return end

package.path = package.path .. ";data/scripts/lib/?.lua"
include ("faction")
include ("utility")
local docker = include ("data/scripts/lib/dockingLib")

local printer = include ("data/scripts/lib/printlib")
local aprinter = printer("[CC-Attack] ", "All")
local print = function (...) return aprinter:print(...) end
local printlog = function (...) return aprinter:printlog(...) end


-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace attack
attack = {}
docker.integrate(attack)

attack.prefix = "attack"
attack.squads = {}               --[squadIndex] = squadIndex           --squads to manage
attack.controlledFighters = {}   --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch

attack.state = -1
attack.stateArgs = {}
attack.action = -1
attack.actionArgs = {}

local relationStatusMap = {             -- For printing
    [RelationStatus.War] = "War",
    [RelationStatus.Ceasefire] = "Ceasefire",
    [RelationStatus.Neutral] = "Neutral",
    [RelationStatus.Allies] = "Allies"
}

function attack.initializationFinished()
    if onServer() then
        if attack.state == "Disengaged" then
            attack.selectNewAndAttack()
        else
            attack.selectNewAndAttack()
        end
    else
        invokeServerFunction("sendState") -- makes sure the current state is available on client
    end
end

function attack.getUpdateInterval()
    if valid(attack.target) and attack.state ~= "Disengaged" then return 20 end -- check for a closer target
    return 30
end

function attack.updateServer(timestep)
    if valid(attack.target) and attack.state ~= "Disengaged" then
        -- check attack_reevaluationDistance
    end
end

function attack.applyState(state, stateArgs, action, actionArgs)
    if onServer() then
        printlog("Info","Apply State: ", attack.state, state, unpack(stateArgs))
        printlog("Info","Apply Action: ", attack.action, action, unpack(actionArgs))
        attack.state = state
        attack.stateArgs = stateArgs or {}
        attack.action = action
        attack.actionArgs = actionArgs or {}
        attack.sendState()
    end
end

-- No passable arguments, so no invalid states can be sneaked in
function attack.sendState()
    broadcastInvokeClientFunction("receiveAttackState", attack.state, attack.stateArgs, attack.action, attack.actionArgs)
end
callable(attack, "sendState")

function cc.receiveAttackState(...)
    printlog("All","cc receiveAttackState")
    attack.receiveAttackState(...)
end

function attack.receiveAttackState(state, stateArgs, action, actionArgs)
    if onClient() then
        printlog("All","Received state: ", attack.state, state, unpack(stateArgs), attack.action, action, unpack(actionArgs))
        attack.state = state
        attack.stateArgs = stateArgs
        attack.action = action
        attack.actionArgs = actionArgs
        if cc.uiInitialized then
            local text = attack.createStatusMessage()
            local color = cc.l.actionToColorMap[state]
            cc.changeIndicator("attack", text, color)
        end
    end
end

function attack.createStatusMessage()
    local text = string.format(cc.l.actionTostringMap[attack.state], unpack(attack.stateArgs))
    text = text .. "\n" .. string.format(cc.l.actionTostringMap[attack.action], unpack(attack.actionArgs))
    return text
end

-- set final orders for all controlled squads
function attack.disable()
    if valid(attack.target) then
        attack.target:unregisterCallback("onDestroyed", "onTargetDestroyed")
    end
    attack.target = nil
    local order = cc.settings.attackStopOrder
    attack.squads = cc.getClaimedSquads(attack.prefix)
    for _,squad in pairs(attack.squads) do
        FighterController():setSquadOrders(squad, order, Entity().index)
    end

    if order ~= FighterOrders.Return then
        attack.applyState("Disengaged", {}, "None", {})
        printlog("Debug","attack Terminate")
        attack.callTerminate()
    else
        local total, landing = docker.dockingFighters(attack.prefix, attack.squads)
        local action = FighterOrders.Return
        local actionArgs = {total, tablelength(landing), Entity().name}
        attack.applyState("Disengaged", {}, action, actionArgs)
        if total <= 0 then
            printlog("Debug","attack [D] Terminate")
            attack.callTerminate()
        end
    end
end

function attack.callTerminate()
    cc.unclaimSquads(attack.prefix, attack.squads)
    cc.clearIndicator(attack.prefix)
    local path = cc.commands[attack.prefix].path..".lua"
    local state = Entity():invokeFunction(path, "terminatus")
    if state == 3 then
        -- TODO Remove once windows pathing is fixed
        printlog("Error","Fixed yet? - No!")
        local repathed = string.gsub(path, "/", "\\")
        local state = Entity():invokeFunction(repathed, "terminatus")
    else
        printlog("Warn","Fixed yet? - Maybe yes")
    end
end

function attack.terminatus()
    terminate()
end

function attack.selectNewAndAttack()
    if attack.getSquadsToManage() then
        local attacking = {attack.findEnemy()} -- attacking[1] contains success, [2] is the subsequent state, [3] are stateArgs, [4] is action, [5] actionState
        if attacking[1] then
            attack.attack()
        else
            attack.setSquadsIdle()
            table.remove(attacking, 1) -- remove success, to only keep state & action and their Args
            attack.applyState(unpack(attacking))
        end
    else
        attack.applyState("TargetButNoFighter", {}, "None", {})
    end
end

function attack.attack()
    local fighterController = FighterController()
    for _,squad in pairs(attack.squads) do
        fighterController:setSquadOrders(squad, FighterOrders.Attack, attack.target.index)
    end
    attack.applyState("Fine", {}, FighterOrders.Attack, {attack.target.name})
end

function attack.getSquadsToManage()
    local hangar = Hangar(Entity().index)
    if not hangar or hangar.space <= 0 then return end -- never happenes, so no log message

    local squads = {}
    for _,squad in pairs({hangar:getSquads()}) do
        if hangar:getSquadMainWeaponCategory(squad) == WeaponCategory.Armed then    --cargo fighters also have the weapon category armed- without a Weapon >.<
            if hangar:getSquadFighters(squad) > 0 and hangar:getFighter(squad,0).type == FighterType.Fighter then
                squads[squad] = squad
            elseif hangar:getSquadFighters(squad) == 0 and hangar:getSquadFreeSlots(squad) < 12 then  -- fighters outside
                squads[squad] = squad
            end
        end
    end
    attack.squads = cc.claimSquads(attack.prefix, squads)
    if next(attack.squads) then  -- command has squads to control
        return true
    else
        return false
    end
end

-- check the sector for an enemy that can be attacked.
-- if there is one, assign target
function attack.findEnemy()
    local shipAI = ShipAI(Entity().index)
    local xsotan = Galaxy():findFaction("The Xsotan"%_T)
    if xsotan then
        shipAI:registerEnemyFaction(xsotan.index)
    else
        printlog("Error", "Could not find Xsotan Faction with: ", "The Xsotan"%_T)
    end

    local attackCivils = cc.settings.attackSpareCivilsSetting

    if shipAI:isEnemyPresent(attackCivils) then
        local ship = Entity()
        local numID = ship.index.number
        local currentPos

        local allEnemies = {getEnemies()} -- TODO includes what? Station, Fighter, Ship, ???, ?
        local enemyShips = {getEnemyShips()}
        local enemyFighters = {getEnemyFighters()}

        -- TODO what EntityType is included in function bool enemyShipsPresent(var countCivilEnemies) ?

        if cc.settings.vanillaAttackPattern or cc.Config.forceUnsupervisedTargeting then
            if not valid(attack.target) then
                local target = shipAI:getNearestEnemy()
                if valid(target) then
                    --[[if attack.checkEnemy(target) then -- checks if shipAI selected valid station or civil target

                    else -- well shipAI doesn't supply an alternative enemy, so nothing useful that can be done

                    end
                    ]]--
                    attack.target = target
                end
            else
                printlog("Error", "Tried to find new Enemy though a valid one alread exists", attack.target.string, attack.target.name)
            end
            return valid(attack.target)
        end
        if cc.settings.attackSquadNearest then  -- find center of all controlled fighters and use it as reference point
            local FighterController = FighterController()
            local num, pos = 0, vec3(0,0,0)
            for _,squad in pairs(attack.squads) do
                for _,fighter in pairs({FighterController():getDeployedFighters(squad)}) do
                    num = num + 1
                    pos = pos + fighter.translationf
                end
            end
            if num == 0 then
                currentPos = ship.translationf
            else
                currentPos = pos / num
            end
        else -- use mothership as reference point
            currentPos = ship.translationf
        end






        local entities = {Sector():getEntitiesByComponent(ComponentType.Owner)} -- hopefully all possible enemies
        local nearest = math.huge
        local hasTarget = valid(attack.target)
        local distThreshold = cc.settings.attack_reevaluationDistance
        local priority = hasTarget and attack.getPriority(attack.target) or 0
        local proposedTarget = attack.target

        for _, e in pairs(entities) do
            local dist = distance2(e.translationf, currentPos)
            local newPrio = attack.getPriority(e)
            -- higher prio -> new target
            -- same prio and no current Target -> select closest new target
            -- same prio and has a valid Target and new Target is 5km (default) closer than current target -> ignore current target and select closest new target
            if newPrio > priority or (newPrio >= priority and dist < nearest) then
               if (not hasTarget or
                  (hasTarget and (dist + distThreshold) < distance2(attack.target.translationf, currentPos))) then
                    if attack.checkEnemy(e) then
                        nearest = dist
                        attack.target = e -- TODO unregisterCallback("onDestroyed", "onDestroyed")
                        priority = newPrio
                    end
                end
            end
        end
        if valid(attack.target) then
            Entity():invokeFunction("attackCommand.lua", "registerTarget")
            state, stateArgs = "Fine", {}
            action, actionArgs = "Mining", {}
            return true, state, stateArgs, action, actionArgs
        else
            attack.target = nil
            state, stateArgs = "NoEnemy", {}
            action, actionArgs = "Idle", {}
            return false, state, stateArgs, action, actionArgs
        end
    end
end

-- Has to be invoked, when fired due to Events from CarrierCommander.lua
function attack.registerTarget()
    local registered = attack.target:registerCallback("onDestroyed", "onTargetDestroyed")
    return registered
end

function attack.onDestroyed(index, lastDamageInflictor)
    printlog("Info", "Target destroyed", index.string, lastDamageInflictor.number)
end

function attack.getPriority(entity)
    if not valid(entity) then return -1 end
    local priority = -1

    -- vanilla priorities
    if entity.isShip then
        priority = _G["cc"].Config.basePriorities.ship
    elseif entity.isStation then priority = _G["cc"].Config.basePriorities.station
    elseif entity.isFighter then priority = _G["cc"].Config.basePriorities.fighter end

    if entity:hasScript("story/wormholeguardian.lua") then
        priority = _G["cc"].Config.basePriorities.guardian
    end

    --custom priorities
    for k,p in pairs(_G["cc"].Config.additionalPriorities) do
        local val = entity:getValue(k)
        if val ~= nil then
            priority = p
        end
    end
    return priority
end
--checks for hostility, xsotan ownership, civil-config, station-config
function attack.checkEnemy(e)
    if not valid(e) then return false end
    local faction = Faction()
    local b = false
    if e.factionIndex and faction:getRelations(e.factionIndex) <= attack.hostileThreshold then -- low faction
        b = true
    elseif attack.isXsotan(e.factionIndex) then -- xsotan ship
        b = true
    end
    --check for civil ships
    if (e:getValue("civil") ~= nil or e:hasScript("civilship.lua") == true) and not _G["cc"].settings[attack.prefix.."spareCivilsSetting"] then
        b = false
    end
    --check for stations
    if e.isStation and not _G["cc"].settings["attackStations"] then
        b = false
    end

    return b
end

function attack.isXsotan(factionIndex)
    local xsotan = Galaxy():findFaction("The Xsotan"%_T)
    if not xsotan then
        return false
    end
    return factionIndex == xsotan.index
end

function attack.setSquadsIdle()
    local fighterController = FighterController(Entity().index)
    local order = cc.settings.attackStopOrder
    for _,squad in pairs(attack.squads) do
        fighterController:setSquadOrders(squad, order, Entity().index)
    end
end

function attack.onSquadOrdersChanged(squadIndex, order, targetId)
    if attack.squads[squadIndex] then
        printlog("Debug","Squad Order", squadIndex, ordernames[order], targetId.string, attack.state)
        -- we are waiting to get Disengaged and a different order was send to our last squad.
        -- Which makes waiting pointless. Our Job is done.
        if attack.state == "Disengaged" and order ~= cc.settings.attackStopOrder then
            if tablelength(attack.squads) <= 1 then
                printlog("Debug","squad changed terminate", cc.settings.attackStopOrder)
                attack.callTerminate()
            else --
                cc.unclaimSquads(attack.prefix, {[squadIndex] = squadIndex})
            end
        elseif attack.state ~= "Disengaged" and targetId.string == "00000000-0000-0000-0000-000000000000" then -- vanilla orderchain command fucking things up
            attack.selectNewAndAttack()
        end
    end
end

function attack.onFighterAdded(squadIndex, fighterIndex, landed)
    printlog("All","Fighter added", squadIndex, fighterIndex, landed)
    if attack.squads[squadIndex] then
        if landed then
            local state, stateArgs, action, actionArgs = attack.state, attack.stateArgs, attack.action, attack.actionArgs
            local missing, landingSquads = attack.dockingFighters(attack.prefix, attack.squads)
            if attack.state == "Disengaged" then
                if missing <= 0 then
                    printlog("Debug","Disengaged and all fighters returned")
                    attack.callTerminate()
                    return
                end
            end
            if missing <= 0 then
                action = "None"
                actionArgs = {}
            else
                action = FighterOrders.Return
                actionArgs = {missing, tablelength(landingSquads), Entity().name}
            end
            attack.applyState(state, stateArgs, action, actionArgs)
        else
            printlog("Debug","New fighter added", squadIndex, fighterIndex)
            if valid(attack.target) then attack.target:unregisterCallback("onDestroyed", "onDestroyed") end
            attack.target = nil
            attack.selectNewAndAttack()
            -- New figter added to this squad. Check for capabilities
        end
    end
end

function attack.onFlyableCreated(entity)
    local shipAI = ShipAI()

    printlog("Debug", "Created ", entity.name, shipAI:isEnemyPresent(false))
end

function attack.onEntityEntered(entity)
    printlog("Debug", "E entered", Entity(entity).name)
end

function attack.onJump(shipIndex, x, y)
    if valid(attack.target) then
        printlog("Debug","onjump")
        attack.target:unregisterCallback("onDestroyed", "onTargetDestroyed")
        attack.target = nil
    end
end

function attack.onSectorEntered(shipIndex, x, y)
    printlog("Debug","Entered Sector: ", x, y)
    attack.selectNewAndAttack()
end

function attack.onSettingChanged(setting, before, now)
    printlog("Debug","onSettingChanged", setting, before, now, cc.settings.attackStopOrder)
end

function attack.secure()
    local data = {}
    data.squads= attack.squads
    data.order = attack.order
    data.state = attack.state
    data.stateArgs = attack.stateArgs
    return data
end

function attack.restore(dataIn)
    attack.squads = dataIn.squads
    attack.order = dataIn.order
    attack.state = dataIn.state
    attack.stateArgs = dataIn.stateArgs
end
