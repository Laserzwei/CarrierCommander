
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("faction")
include ("utility")
local docker = include ("data/scripts/lib/dockingLib")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace mine
mine = {}
docker.integrate(mine)

--data
mine.prefix = "mine"
mine.squads = {}                 --[squadIndex] = squadIndex           --squads to manage
mine.controlledFighters = {}     --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
mine.settingsCommands = {mineStopOrder = "setSquadsIdle", mineAllSetting = "removeThis", mineSquadNearest = "removeThis"}
mine.state = -1

function mine.removeThis()
    print(Entity().name, "Remove This!")
end

function mine.initialize()
    deferredCallback(5, "postInitialize")
end

function mine.postInitialize()
    if onServer() then
        mine.selectNewAndMine()
    else
        mine.applyStatus("idle")
    end
end

function mine.updateServer(timestep)

end

function mine.applyStatus(status, ...)
    if onServer() then
        mine.state = status
        broadcastInvokeClientFunction("applyStatus", status, ...)
    else
        mine.state = status
        --print("apply", string.format(_G["cc"].l.actionTostringMap[status], unpack(args or {})))
        if _G["cc"].uiInitialized then
            local args = {...}

            local pic = _G["cc"].commands[mine.prefix].statusPicture

            pic.color = _G["cc"].l.actionToColorMap[status]
            pic.tooltip = string.format(_G["cc"].l.actionTostringMap[status], unpack(args))
        end
    end
end

-- set final orders for all controlled squads
function mine.disable()
    mine.target = nil
    mine.order = _G["cc"].settings.mineStopOrder or FighterOrders.Return
    local fighterController = FighterController(Entity().index)
    mine.squads = _G["cc"].getClaimedSquads(mine.prefix)
    for _,squad in pairs(mine.squads) do
        fighterController:setSquadOrders(squad, mine.order, Entity().index)
    end
    print("Disable")
    if mine.order ~= FighterOrders.Return then
        _G["cc"].unclaimSquads(mine.prefix, mine.squads)
        broadcastInvokeClientFunction("applyStatus", -1)
        print(Entity().name, "Mine Terminate")
        terminate()
    end
end

function mine.selectNewAndMine()
    if mine.getSquadsToManage() then
        if mine.findMineableAsteroid() then
            mine.mine()
            print(Entity().name, "Mining")
        else
            mine.setSquadsIdle()
            print(Entity().name, "no asteroids found")
            broadcastInvokeClientFunction("applyStatus", "noAsteroid")
        end
    else
        broadcastInvokeClientFunction("applyStatus", "targetButNoFighter")
    end
end

function mine.mine()
    local fighterController = FighterController(Entity().index)
    for _,squad in pairs(mine.squads) do
        fighterController:setSquadOrders(squad, FighterOrders.Attack, mine.target.index)
    end
    broadcastInvokeClientFunction("applyStatus", "Mining")
end

function mine.getSquadsToManage()
    local hangar = Hangar(Entity().index)
    if not hangar or hangar.space <= 0 then return end

    local squads = {}
    for _,squad in pairs({hangar:getSquads()}) do
        if hangar:getSquadMainWeaponCategory(squad) == WeaponCategory.Mining then
            squads[squad] = squad
        end
    end
    print("Size A", tablelength(mine.squads), tablelength(squads))
    mine.squads = _G["cc"].claimSquads(mine.prefix, squads)
    print("Size B", tablelength(mine.squads))
    if next(mine.squads) then
        return true
    else
        return false
    end
end

-- check the sector for an asteroid that can be mined.
-- if there is one, assign minableAsteroid
function mine.findMineableAsteroid()
    local ship = Entity()
    local numID = ship.index.number
    local sector = Sector()
    local currentPos

    if _G["cc"].settings["mineSquadNearest"] then
        local fighters = {Sector():getEntitiesByType(EntityType.Fighter)}
        local num, pos = 0, vec3(0,0,0)
        for _,fighter in pairs(fighters) do
            local fAI = FighterAI(fighter)
            if fAI.mothershipId.number == numID and mine.squads[fAI.squad] then
                num = num + 1
                pos = pos + fighter.translationf
            end
        end
        if num == 0 then
            currentPos = ship.translationf
        else
            currentPos = pos / num
        end
    else
        currentPos = ship.translationf
    end

    local hasMiningSystem = ship:hasScript("systems/miningsystem.lua")
    local asteroids = {sector:getEntitiesByType(EntityType.Asteroid)}
    local nearest = math.huge

    for _, a in pairs(asteroids) do
        local resources = a:getMineableResources()
        if ((a.isObviouslyMineable or hasMiningSystem) and
           (resources ~= nil and resources > 0)) or
            _G["cc"].settings["mineAllSetting"] then
            local dist = distance2(a.translationf, currentPos)
            if dist < nearest then
                nearest = dist
                mine.target = a
            end
        end
    end

    if valid(mine.target) then
        mine.target:registerCallback("onDestroyed", "onTargetDestroyed")
        return true
    else
        mine.target = nil
        return false
    end
end

function mine.setSquadsIdle()
    local fighterController = FighterController(Entity().index)
    mine.order = _G["cc"].settings.mineStopOrder or FighterOrders.Return
    print("Size C", tablelength(mine.squads))
    for _,squad in pairs(mine.squads) do
        fighterController:setSquadOrders(squad, mine.order, Entity().index)
    end
end

function mine.onTargetDestroyed(index, lastDamageInflictor)
    print(Entity().name, "Target destroyed", index.string, valid(mine.target))
    mine.selectNewAndMine()
end

-- only change Asteroid, when no other is available
function mine.onAsteroidCreated(entity)
    if not valid(mine.target) then
        mine.selectNewAndMine()
    end
end

function mine.onSquadOrdersChanged(squadIndex, orders, targetId)
    if mine.squads[squadIndex] then
        print(Entity().name, "Squad Order", squadIndex, orders, targetId.string)
    end
end

function mine.onFighterAdded(squadIndex, fighterIndex, landed)
    print(Entity().name, "Fighter added", squadIndex, fighterIndex, landed)
    if landed then
        local missing, numsquads = mine.dockingFighters(mine.prefix, mine.squads)
        if mine.state ~= "landing" then

        end
        print(string.format("[E]Waiting for %i Fighter(s) in %i Squad(s) to dock at %s", missing, numsquads, Entity().name))
    end
end

function mine.onFighterRemove(squadIndex, fighterIndex, started)
    print(Entity().name, "Fighter remove", squadIndex, fighterIndex, started)
end

function mine.onJump(shipIndex, x, y)
    if valid(mine.target) then
        mine.target:unregisterCallback("onDestroyed", "onTargetDestroyed")
        mine.target = nil
    end
end

function mine.onSectorEntered(shipIndex, x, y)
    print(Entity().name, "Entered Sector: ", x, y)
    mine.selectNewAndMine()
end

function mine.onSettingChanged(setting, before, now)
    print("onSettingChanged", setting, before, now, _G["cc"].settings.mineStopOrder)
    if mine.settingsCommands[setting] then
        mine[mine.settingsCommands[setting]]()
    end
end

function mine.secure()
    local data = {}
    data.squads= mine.squads
    data.order = mine.order
    data.state = mine.state
    return data
end

function mine.restore(dataIn)
    mine.squads = dataIn.squads
    mine.order = dataIn.order
    mine.state = mine.state
end
