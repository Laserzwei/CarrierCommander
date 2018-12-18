
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")
local docker = require ("mods.CarrierCommander.scripts.lib.dockingLib")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace attack
attack = {}
docker.integrate(attack)

attack.prefix = "attack"
attack.squads = {}               --[squadIndex] = squadIndex           --squads to manage
attack.controlledFighters = {}   --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
attack.disabled = false
attack.hostileThreshold = -40000

function attack.initialize()
    if onServer() then
        --attack.updateServer(0)
    else
        attack.applyStatus("idle")
    end
end

function attack.getUpdateInterval()
    if not valid(attack.target) and attack.disabled == false then return 15 end --deep sleep
    if valid(attack.target) and attack.disabled == false then return 2 end -- light sleep
    return 1 --awake
end

function attack.updateServer(timestep)
    if attack.disabled == false then
        if not valid(attack.target) then

            if attack.getSquadsToManage() then
                if attack.findEnemy() then
                    broadcastInvokeClientFunction("applyStatus", FighterOrders.Attack, attack.target.name or "")
                    attack.attack()
                else
                    attack.setSquadsIdle()
                    if attack.order == FighterOrders.Return then

                        local total, numSquads = attack.dockingFighters(attack.prefix, attack.squads)
                        if numSquads <= 0 then
                            broadcastInvokeClientFunction("applyStatus", "idle")
                        else
                            broadcastInvokeClientFunction("applyStatus", FighterOrders.Return, total, numSquads, Entity().name)
                        end
                    else
                        broadcastInvokeClientFunction("applyStatus", "idle")
                    end
                end
            else
                broadcastInvokeClientFunction("applyStatus", "targetButNoFighter")
            end
        else
            if attack.getSquadsToManage() then
                if attack.findEnemy() then
                    broadcastInvokeClientFunction("applyStatus", FighterOrders.Attack, attack.target.name or "")
                    attack.attack()
                end
            end
        end
    else
        attack.setSquadsIdle()
        if attack.order == FighterOrders.Return then -- show docking status in UI
            attack.squads = _G["cc"].claimSquads(attack.prefix, attack.squads)

            local total, numSquads = attack.dockingFighters(attack.prefix, attack.squads)

            if numSquads <= 0 then
                broadcastInvokeClientFunction("applyStatus", -1)
                terminate()
            else
                broadcastInvokeClientFunction("applyStatus", FighterOrders.Return, total, numSquads, Entity().name)
            end
        else
            broadcastInvokeClientFunction("applyStatus", -1)
            terminate()
        end
    end
end

-- set final orders for all controlled squads
function attack.disable()
    attack.disabled = true
    attack.target = nil
    attack.order = _G["cc"].settings.attackStopOrder or FighterOrders.Return
    local fighterController = FighterController(Entity().index)
    attack.squads = _G["cc"].getClaimedSquads(attack.prefix)
    for _,squad in pairs(attack.squads) do
        fighterController:setSquadOrders(squad, attack.order, Entity().index)
    end

    if attack.order ~= FighterOrders.Return then
        _G["cc"].unclaimSquads(attack.prefix, attack.squads)
        broadcastInvokeClientFunction("applyStatus", -1)
        terminate()
    end
end

function attack.applyStatus(status, ...)
    if onClient() then
        if  _G["cc"].uiInitialized then
            local args = {...}

            local pic = _G["cc"].commands[attack.prefix].statusPicture

            pic.color = _G["cc"].l.actionToColorMap[status]
            pic.tooltip = string.format(_G["cc"].l.actionTostringMap[status], unpack(args))
        end
    end
end

function attack.attack()
    local fighterController = FighterController(Entity().index)
    for _,squad in pairs(attack.squads) do
        fighterController:setSquadOrders(squad, FighterOrders.Attack, attack.target.index)
    end
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
    attack.squads = _G["cc"].claimSquads(attack.prefix, squads)
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
    end

    if shipAI:isEnemyPresent(attack.hostileThreshold) then
        local ship = Entity()
        local numID = ship.index.number
        local currentPos


        if _G["cc"].settings["vanillaAttackPattern"] or _G["cc"].Config.forceUnsupervisedTargeting then
            if not valid(attack.target) then
                local target = shipAI:getNearestEnemy(attack.hostileThreshold)
                if valid(target) then
                    --[[if attack.checkEnemy(target) then -- checks if shipAI selected valid station or civil target

                    else -- well shipAI doesn't supply an alternative enemy, so nothing useful that can be done

                    end
                    ]]--
                    attack.target = target
                end
            else

            end
            return valid(attack.target)
        end
        if _G["cc"].settings["attackSquadNearest"] then  -- find center of all controlled fighters and use it as reference point
            local fighters = {Sector():getEntitiesByType(EntityType.Fighter)}
            local num, pos = 0, vec3(0,0,0)
            for _,fighter in pairs(fighters) do
                local fAI = FighterAI(fighter)
                if fAI.mothershipId.number == numID and attack.squads[fAI.squad] then
                    num = num + 1
                    pos = pos + fighter.translationf
                end

            end
            if num == 0 then  -- no fighter started
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
        local distThreshold = (_G["cc"].settings["attack_reevaluationDistance"] or 15) * 1000
        local priority = hasTarget and attack.getPriority(attack.target) or 0
        local proposedTarget = attack.target


        for _, e in pairs(entities) do
            local dist = distance2(e.translationf, currentPos)
            local newPrio = attack.getPriority(e)
            -- higher prio -> new target
            -- same prio and no current Target -> select closest new target
            -- same prio and has a valid Target and new Target is 15km (default) closer than current target -> ignore current target and select closest new target
            if newPrio > priority or (newPrio >= priority and dist < nearest) then
               if (not hasTarget or
                  (hasTarget and (dist + distThreshold) < distance2(attack.target.translationf, currentPos))) then
                    if attack.checkEnemy(e) then
                        nearest = dist
                        proposedTarget = e
                        priority = newPrio
                    end
                end
            end
        end
        if valid(proposedTarget) then
            attack.target = proposedTarget
            return true
        else
            return false
        end
    end
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
    attack.order = _G["cc"].settings.attackStopOrder or FighterOrders.Return
    for _,squad in pairs(attack.squads) do
        fighterController:setSquadOrders(squad, attack.order, Entity().index)
    end
end

function attack.secure()
    local data = {}
    data.squads= attack.squads
    data.order = attack.order
    data.disabled = attack.disabled
    return data
end

function attack.restore(dataIn)
    attack.squads = dataIn.squads
    attack.order = dataIn.order
    attack.disabled = dataIn.disabled or false
end
