if not cc then print("[CC-Minecommand]", "Something went wrong CC mainscript not found") return end

package.path = package.path .. ";data/scripts/lib/?.lua"
include ("faction")
include ("utility")
include ("callable")
local docker = include ("data/scripts/lib/dockingLib")
local printer = include ("data/scripts/lib/printlib")
printer.identifier = "[CC-Minecommand] "
printlog = printer.printlog
print = printer.print


-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace mine
mine = {}
docker.integrate(mine)

--data
mine.prefix = "mine"
mine.squads = {}                 --[squadIndex] = squadIndex           --squads to manage
mine.controlledFighters = {}     --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
mine.state = -1
mine.stateArgs = {}
mine.action = -1
mine.actionArgs = {}
mine.hasRawLasers = false
mine.miningMaterial = nil

local ordernames = {
    [FighterOrders.Attack] = "Attack",
    [FighterOrders.Defend] = "Defend",
    [FighterOrders.Return] = "Return",
    [FighterOrders.Harvest] = "Harvest",
    [FighterOrders.FlyToLocation] = "FlyToLocation",
    [FighterOrders.Board] = "Board"
}

function mine.initializationFinished()
    if onServer() then
        if mine.state ~= "disabled" then
            mine.selectNewAndMine()
        end
    else
        invokeServerFunction("sendState") -- makes sure the current state is available on client
    end
end

-- set final orders for all controlled squads
function mine.disable()
    if valid(mine.target) then
        mine.target:unregisterCallback("onDestroyed", "onTargetDestroyed")
    end
    mine.target = nil
    local cc = _G["cc"]
    local order = cc.settings.mineStopOrder
    mine.squads = cc.getClaimedSquads(mine.prefix)
    for _,squad in pairs(mine.squads) do
        FighterController():setSquadOrders(squad, order, Entity().index)
    end

    mine.applyState("disabled")
    if order ~= FighterOrders.Return then
        printlog("Mine Terminate")
        mine.callTerminate()
    else
        local total, landing = docker.dockingFighters(mine.prefix, mine.squads)
        -- TODO add mine.applyState(FighterOrders.Return, total, tablelength(landing), Entity().name)
        if total <= 0 then
            printlog("Mine [D] Terminate")
            mine.callTerminate()
        end
    end
end

function mine.callTerminate()
    local cc = _G["cc"]
    cc.unclaimSquads(mine.prefix, mine.squads)
    mine.applyState(-1)
    local path = cc.commands[mine.prefix].path..".lua"
    local state = Entity():invokeFunction(path, "terminatus")
    if state == 3 then
        -- TODO Remove once windows pathing is fixed
        local repathed = string.gsub(path, "/", "\\")
        local state = Entity():invokeFunction(repathed, "terminatus")
    end
end

function mine.terminatus()
    terminate()
end

function mine.selectNewAndMine()
    if mine.getSquadsToManage() then
        local mining = {mine.findMineableAsteroid()} -- mining[1] contains success, [2] is the subsequent state, [>2] are its args
        if mining[1] then
            mine.mine()
        else
            mine.setSquadsIdle()
            table.remove(mining, 1)
            mine.applyState(unpack(mining))
        end
    else
        mine.applyState("targetButNoFighter")
    end
end

function mine.mine()
    for _,squad in pairs(mine.squads) do
        FighterController():setSquadOrders(squad, FighterOrders.Attack, mine.target.index)
    end
    mine.applyState("Mining")
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

    mine.squads = _G["cc"].claimSquads(mine.prefix, squads)

    for _,squad in pairs(mine.squads) do
        mine.hasRawLasers = mine.hasRawLasers or hangar:getSquadHasRawMinersOrSalvagers(squad)
        if mine.miningMaterial == nil or hangar:getHighestMaterialInSquadMainCategory(squad).value > mine.miningMaterial then
            mine.miningMaterial = hangar:getHighestMaterialInSquadMainCategory(squad).value
        end
    end

    if next(mine.squads) then
        return true
    else
        return false
    end
end

-- check the sector for an asteroid that can be mined.
-- if there is one, assign mine.target
function mine.findMineableAsteroid()
    mine.target = nil
    local ship = Entity()
    local sector = Sector()
    local currentPos
    local cc = _G["cc"]

    if cc.settings["mineSquadNearest"] then
        local FighterController = FighterController()
        local num, pos = 0, vec3(0,0,0)
        for _,squad in pairs(mine.squads) do
            for _,fighter in pairs(FighterController():getDeployedFighters(squad)) do
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
    local higherMaterialLevel = nil
    local asteroids = {sector:getEntitiesByType(EntityType.Asteroid)}
    local nearest = math.huge

    for _, a in pairs(asteroids) do
        if cc.settings["mineAllSetting"] then -- Mining all Asteroids regardless of their resources
            local dist = distance2(a.translationf, currentPos)
            if dist < nearest then
                nearest = dist
                mine.target = a
            end
        else
            if a.isObviouslyMineable or hasMiningSystem then
                local resources = a:getMineableResources()
                if resources ~= nil and resources > 0 then
                    local material = a:getLowestMineableMaterial()
                    if material.value <= mine.miningMaterial + 1 then
                        local dist = distance2(a.translationf, currentPos)
                        if dist < nearest then
                            nearest = dist
                            mine.target = a
                        end
                    else
                        higherMaterialLevel = material
                    end
                end
            end
        end
    end

    if valid(mine.target) then
        Entity():invokeFunction("mineCommand.lua", "registerTarget")
        return true, ""
    else
        mine.target = nil
        if higherMaterialLevel then
            return false, "asteroidWithHigherMaterialPresent", Material(higherMaterialLevel + 1).name
        else
            return false, "noAsteroid"
        end
    end
end

-- Has to be invoked, when fired due to Events from CarrierCommander.lua
function mine.registerTarget()
    local registered = mine.target:registerCallback("onDestroyed", "onTargetDestroyed")
    return registered
end

function mine.setSquadsIdle()
    local order = _G["cc"].settings.mineStopOrder
    for _,squad in pairs(mine.squads) do
        FighterController():setSquadOrders(squad, order, Entity().index)
    end
end

function mine.onTargetDestroyed(index, lastDamageInflictor)
    printlog("Target destroyed", index.string, valid(mine.target))
    mine.selectNewAndMine()
end

-- only change Asteroid, when no other is available
function mine.onAsteroidCreated(asteroid)
    if not valid(mine.target) then
        mine.selectNewAndMine()
    end
end

function mine.onSquadOrdersChanged(squadIndex, order, targetId)
    if mine.squads[squadIndex] then
        printlog("Squad Order", squadIndex, ordernames[order], targetId.string, mine.state)
        -- we are waiting to get disabled and a different order was send to our last squad.
        -- Which makes waiting pointless. Our Job is done.
        if mine.state == "disabled" and order ~= _G["cc"].settings.mineStopOrder then
            if tablelength(mine.squads) <= 1 then
                _G["cc"].clearIndicator(mine.prefix)
                printlog("squad changed terminate", _G["cc"].settings.mineStopOrder)
                mine.callTerminate()
            else --
                _G["cc"].unclaimSquads(mine.prefix, {[squadIndex] = squadIndex})
            end

        else
        end
    end
end

function mine.onFighterAdded(squadIndex, fighterIndex, landed)
    --printlog("Fighter added", squadIndex, fighterIndex, landed)
    if mine.squads[squadIndex] then
        if landed then
            local missing, landingSquads = mine.dockingFighters(mine.prefix, mine.squads)
            if mine.state == "disabled" then
                if missing <= 0 then
                    printlog("Disabled and all fighters returned")
                    mine.callTerminate()
                else
                    mine.applyState(FighterOrders.Return, missing, tablelength(landingSquads), Entity().name)
                end
                return
            end
            if mine.state == FighterOrders.Return then
                mine.applyState(FighterOrders.Return, missing, tablelength(landingSquads), Entity().name)
                return
            else -- fighter landed, but there was no landing order.
                printlog("mhhh", squadIndex)
                mine.applyState(FighterOrders.Return, missing, tablelength(landingSquads), Entity().name)
                --_G["cc"].unclaimSquads(mine.prefix, {[squadIndex] = squadIndex})
                return
            end
            --printlog(string.format("[E]Waiting for %i Fighter(s) in %i Squad(s) to dock at %s", missing, tablelength(landingSquads), Entity().name))
        else
            -- New figter added to this squad. Check for resource capabilities
        end
    end
end

function mine.onFighterRemove(squadIndex, fighterIndex, started)
    --printlog("Fighter remove", squadIndex, fighterIndex, started)
end

function mine.onJump(shipIndex, x, y)
    if valid(mine.target) then
        printlog("onjump")
        mine.target:unregisterCallback("onDestroyed", "onTargetDestroyed")
        mine.target = nil
    end
end

function mine.onSectorEntered(shipIndex, x, y)
    printlog("Entered Sector: ", x, y)
    mine.selectNewAndMine()
end

function mine.onSettingChanged(setting, before, now)
    printlog("onSettingChanged", setting, before, now, _G["cc"].settings.mineStopOrder)
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
