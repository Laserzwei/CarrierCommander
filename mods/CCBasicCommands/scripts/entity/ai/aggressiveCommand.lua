
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")
local docker = require ("mods.CarrierCommander.scripts.lib.dockingLib")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace attack
attack = {}
attack.prefix = "attack"
attack.squads = {}               --[squadIndex] = squadIndex           --squads to manage
attack.controlledFighters = {}   --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
attack.disabled = false
attack.hostileThreshold = -40000

function attack.initialize()
    print("attack")
end

function attack.getUpdateInterval()
    if not valid(attack.target) and attack.disabled == false then return 15 end --deep sleep
    if valid(attack.target) and attack.disabled == false then return 5 end -- light sleep
    return 1 --awake
end

function attack.updateServer(timestep)
    if not valid(attack.target) then

        if attack.getSquadsToManage() then
            if attack.findEnemy() then
                broadcastInvokeClientFunction("applyStatus", FighterOrders.Attack, attack.target.name)
                attack.attack()
            else
                attack.setSquadsIdle()
                if attack.order == FighterOrders.Return then

                    local total, numSquads = docker.dockingFighters(attack.prefix, attack.squads)
                    if numSquads <= 0 then
                        broadcastInvokeClientFunction("applyStatus", "idle")
                    else
                        broadcastInvokeClientFunction("applyStatus", FighterOrders.Return, total, numSquads, Entity().name)
                    end
                else
                    print("T")
                    broadcastInvokeClientFunction("applyStatus", "idle")
                end
            end
        else
            print("b")
            broadcastInvokeClientFunction("applyStatus", "targetButNoFighter")
        end
    else
        print("target", attack.target.name)
        if attack.getSquadsToManage() then
            if attack.findEnemy(attack.target.index) then
                broadcastInvokeClientFunction("applyStatus", FighterOrders.Attack, attack.target.name)
                attack.attack()
            end
        end
    end
    if attack.disabled == true then
        if attack.order == FighterOrders.Return then
            attack.squads = _G["cc"].claimSquads(attack.prefix, attack.squads)

            local total, numSquads = docker.dockingFighters(attack.prefix, attack.squads)

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
        _G["cc"].unclaimSquads(attack.squads)
        broadcastInvokeClientFunction("applyStatus", -1)
        terminate()
    end
end

function attack.applyStatus(status, ...)
    if onClient() then
        print("attack", status, ...)
        if  _G["cc"].uiInitialized then
            local args = {...}

            local pic = _G["cc"].commands[attack.prefix].statusPicture

            pic.color = _G["cc"].l.actionToColorMap[status]
            pic.tooltip = string.format(_G["cc"].l.actionTostringMap[status], unpack(args))
            if status == -1 then _G["cc"].commands[attack.prefix].activationButton.onPressedFunction = "buttonActivate" end
        end
    else
        print("why?")
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
    if not hangar or hangar.space <= 0 then print("noHangar") return end

    local squads = {}
    for _,squad in pairs({hangar:getSquads()}) do
        if hangar:getSquadMainWeaponCategory(squad) == WeaponCategory.Armed then    --cargo fighters also have the weapon category armed- without a Weapon >.<
            if hangar:getSquadFighters(squad) > 0 and hangar:getFighter(squad,0).type == FighterType.Fighter then
                squads[squad] = squad
            elseif hangar:getSquadFighters(squad) == 0 and hangar:getSquadFreeSlots(squad) < 12 then
                squads[squad] = squad
            end
        end
    end
    attack.squads = _G["cc"].claimSquads(attack.prefix, squads)
    if next(attack.squads) then
        return true
    else
        return false
    end
end

-- check the sector for an enemy that can be attacked.
-- if there is one, assign target
function attack.findEnemy(ignoredEntityIndex)
    local shipAI = ShipAI(Entity().index)
    if shipAI:isEnemyPresent(attack.hostileThreshold) then
        local ship = Entity()
        local currentPos

        --Cwhizard's Nearest-Neighbor
        if _G["cc"].settings["attackNN"] then
            currentPos = attack.target and attack.target.translationf or ship.translationf
        else
            currentPos = ship.translationf
        end
        --Cwhizard

        local entities = {Sector():getEntitiesByComponent(ComponentType.Owner)} -- hopefully all possible enemies
        local nearest = math.huge
        local priority = 0
        local hasTargetChanged = false
        for _, e in pairs(entities) do
            if attack.checkEnemy(e, ignoredEntityIndex) then
                local p = attack.getPriority(e)
                local dist = distance2(e.translationf, currentPos)
                if ((dist < nearest and priority <= p) or (priority < p)) then -- get a new target
                    nearest = dist
                    attack.target = e
                    priority = p
                    hasTargetChanged = true
                end
            end
        end
    else
        -- xsotan ships are not recognized by the shipAI:isEnemyPresent()
        local xsotan = Galaxy():findFaction("The Xsotan"%_T)--TODO check for other nationalities
        if not xsotan then return false end
        local ship = Entity()
        local currentPos

        --Cwhizard's Nearest-Neighbor
        if _G["cc"].settings["attackNN"] then
            currentPos = attack.target.translationf or ship.translationf
        else
            currentPos = ship.translationf
        end
        --Cwhizard

        local nearest = math.huge
        local priority = 0
        local xsotanships = {Sector():getEntitiesByFaction(xsotan.index) }
        for _, e in pairs(xsotanships) do
            if attack.checkEnemy(e, ignoredEntityIndex) then
                local p = attack.getPriority(e)
                local dist = distance2(e.translationf, currentPos)
                if ((dist < nearest and priority <= p) or (priority < p)) then -- get a new target
                    nearest = dist
                    attack.target = e
                    priority = p
                    hasTargetChanged = true
                end
            end
        end
    end

    return valid(attack.target)
end

function attack.getPriority(entity)
    if not valid(entity) then return -1 end
    local priority = 0

    -- vanilla priorities
    if entity.isShip then priority = _G["cc"].Config.basePriorities.ship
    elseif entity.isStation then priority = _G["cc"].Config.basePriorities.station
    elseif entity.isFighter then priority = _G["cc"].Config.basePriorities.fighter
    elseif entity:hasScript("story/wormholeguardian.lua") then priority = _G["cc"].Config.basePriorities.guardian
    else priority = -1 end -- do not attack other entities

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
function attack.checkEnemy(e, ignored)
    if not valid(e) then return false end
    if ignored and e.index.number == ignored.number then return false end
    local faction = Faction()
    local b = false
    if e.factionIndex and faction:getRelations(e.factionIndex) <= attack.hostileThreshold then -- low faction
        b = true
    elseif attack.isXsotan(e.factionIndex) then -- xsotan ship
        b = true
    end
    if (e:getValue("civil") ~= nil or e:hasScript("civilship.lua") == true) and not _G["cc"].settings[attack.prefix.."spareCivilsSetting"] then
        b = false
    end

    if e.isStation and not _G["cc"].settings[attack.prefix.."attackStations"] then
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
    if valid(attack.target) then data.target = attack.target.index.string end
    data.order = attack.order
    data.disabled = attack.disabled
    return data
end

function attack.restore(dataIn)
    attack.squads = dataIn.squads
    if dataIn.target then attack.target =  Entity(Uuid(dataIn.target)) end
    attack.order = dataIn.order
    attack.disabled = dataIn.disabled or false
end
