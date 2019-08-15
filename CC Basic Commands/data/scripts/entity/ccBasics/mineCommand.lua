
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("faction")
include ("utility")
include ("callable")
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
mine.stateArgs = {}

function mine.removeThis()
    print(Entity().name, "Remove This!")
end

function mine.initializationFinished()
    if onServer() then
        mine.selectNewAndMine()
    else
        mine.applyState("idle")
    end
end

function mine.applyState(state, ...)
    if onServer() then
        mine.state = state
        mine.stateArgs = {...}
        mine.sendState()
    end
end

function mine.sendState()
    broadcastInvokeClientFunction("receiveState", mine.state, mine.stateArgs)
end
callable(mine, "sendState")

function mine.receiveState(state, stateArgs)
    if onClient() then
        if mine.state == "disabled" and state ~= "enable" then
            print("No apply", mine.state, state)
            return
        end
        mine.state = state
        mine.stateArgs = stateArgs
        local cc = _G["cc"]
        --print("apply", string.format(cc.l.actionTostringMap[state], unpack(args or {})))
        if cc.uiInitialized then
            local pic = cc.commands[mine.prefix].statePicture

            pic.color = cc.l.actionToColorMap[state]
            pic.tooltip = string.format(cc.l.actionTostringMap[state], unpack(mine.stateArgs))
        end
    end
end

-- set final orders for all controlled squads
function mine.disable()
    if valid(mine.target) then
        mine.target:unregisterCallback("onDestroyed", "onTargetDestroyed")
    end
    mine.target = nil
    local cc = _G["cc"]
    local order = cc.settings.mineStopOrder or FighterOrders.Return
    local fighterController = FighterController(Entity().index)
    mine.squads = cc.getClaimedSquads(mine.prefix)
    for _,squad in pairs(mine.squads) do
        fighterController:setSquadOrders(squad, order, Entity().index)
    end
    print("Disable")
    mine.applyState("disabled")
    if order ~= FighterOrders.Return then
        cc.unclaimSquads(mine.prefix, mine.squads)
        mine.sendState(-1)
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
            broadcastInvokeClientFunction("applyState", "noAsteroid")
        end
    else
        broadcastInvokeClientFunction("applyState", "targetButNoFighter")
    end
end

function mine.mine()
    local fighterController = FighterController(Entity().index)
    for _,squad in pairs(mine.squads) do
        fighterController:setSquadOrders(squad, FighterOrders.Attack, mine.target.index)
    end
    broadcastInvokeClientFunction("applyState", "Mining")
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
    local cc = _G["cc"]

    if cc.settings["mineSquadNearest"] then
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
            cc.settings["mineAllSetting"] then
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
    local order = _G["cc"].settings.mineStopOrder or FighterOrders.Return
    print("Size C", tablelength(mine.squads))
    for _,squad in pairs(mine.squads) do
        fighterController:setSquadOrders(squad, order, Entity().index)
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
        print(Entity().name, "Squad Order", squadIndex, orders, targetId.string, mine.state)
        if mine.state ~= "disabled" then

        else
        end
    end
end

function mine.onFighterAdded(squadIndex, fighterIndex, landed)
    print(Entity().name, "Fighter added", squadIndex, fighterIndex, landed)
    if mine.squads[squadIndex] then
        if landed then
            local missing, landingSquads = mine.dockingFighters(mine.prefix, mine.squads)
            if mine.state ~= "landing" and mine.state ~= "disabled" then  -- fighter landed, but there was no landing order
                print("contra unclaimed", squadIndex)
                _G["cc"].unclaimSquads(mine.prefix, {[squadIndex] = squadIndex})
            end

            if mine.state == "disabled" and missing == 0 then
                _G["cc"].unclaimSquads(mine.prefix, mine.squads)
                print("term after land")
                terminate()
            end
            print(string.format("[E]Waiting for %i Fighter(s) in %i Squad(s) to dock at %s", missing, tablelength(landingSquads), Entity().name))
        else
            -- New figter added to this squad. Check for resource capabilities
        end
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
    data.stateArgs = mine.stateArgs
    return data
end

function mine.restore(dataIn)
    mine.squads = dataIn.squads
    mine.order = dataIn.order
    mine.state = dataIn.state
    mine.stateArgs = dataIn.stateArgs
end
