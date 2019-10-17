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

mine.looterlist = {}
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
        if mine.state ~= "Disengaged" then
            mine.selectNewAndMine()
            --mine.scoopLoot(Entity().translationf)
        end
    else
        invokeServerFunction("sendState") -- makes sure the current state is available on client
    end
end

function mine.applyState(state, stateArgs, action, actionArgs)
    if onServer() then
        printlog("Apply State: ", mine.state, state, unpack(stateArgs))
        printlog("Apply Action: ", mine.action, action, unpack(actionArgs))
        mine.state = state
        mine.stateArgs = stateArgs or {}
        mine.action = action
        mine.actionArgs = actionArgs or {}
        mine.sendState()
    end
end

-- No passable arguments, so no invalid states can be sneaked in
function mine.sendState()
    broadcastInvokeClientFunction("receiveMineState", mine.state, mine.stateArgs, mine.action, mine.actionArgs)
end
callable(mine, "sendState")

function cc.receiveMineState(...)
    --print("cc receiveMineState")
    mine.receiveMineState(...)
end

function mine.receiveMineState(state, stateArgs, action, actionArgs)
    if onClient() then
        printlog("Received state: ", mine.state, state, unpack(stateArgs), mine.action, action, unpack(actionArgs))
        mine.state = state
        mine.stateArgs = stateArgs
        mine.action = action
        mine.actionArgs = actionArgs
        if cc.uiInitialized then
            local text = mine.createStatusMessage()
            local color = cc.l.actionToColorMap[state]
            cc.changeIndicator("mine", text, color)
        end
    end
end

function mine.createStatusMessage()
    local text = string.format(cc.l.actionTostringMap[mine.state], unpack(mine.stateArgs))
    text = text .. "\n" .. string.format(cc.l.actionTostringMap[mine.action], unpack(mine.actionArgs))
    return text
end

-- set final orders for all controlled squads
function mine.disable()
    if valid(mine.target) then
        mine.target:unregisterCallback("onDestroyed", "onTargetDestroyed")
    end
    mine.target = nil
    local order = cc.settings.mineStopOrder
    mine.squads = cc.getClaimedSquads(mine.prefix)
    for _,squad in pairs(mine.squads) do
        FighterController():setSquadOrders(squad, order, Entity().index)
    end

    if order ~= FighterOrders.Return then
        mine.applyState("Disengaged", {}, "None", {})
        printlog("Mine Terminate")
        mine.callTerminate()
    else
        local total, landing = docker.dockingFighters(mine.prefix, mine.squads)
        local action = FighterOrders.Return
        local actionArgs = {total, tablelength(landing), Entity().name}
        mine.applyState("Disengaged", {}, action, actionArgs)
        if total <= 0 then
            printlog("Mine [D] Terminate")
            mine.callTerminate()
        end
    end
end

function mine.callTerminate()
    cc.unclaimSquads(mine.prefix, mine.squads)
    cc.clearIndicator(mine.prefix)
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
        if (mine.hasRawLasers == true and Entity().freeCargoSpace > 1) or mine.hasRawLasers == false then
            local mining = {mine.findMineableAsteroid()} -- mining[1] contains success, [2] is the subsequent state, [3] are stateArgs, [4] is action, [5] actionState
            if mining[1] then
                mine.mine()
            else
                mine.setSquadsIdle()
                table.remove(mining, 1) -- remove success, to only keep state & action and their Args
                mine.applyState(unpack(mining))
            end
        else
            mine.applyState("TargetButNoFighter", {}, "None", {})
        end
    else
        mine.applyState("NoCargospace", {}, "None", {})
    end
end

function mine.mine()
    for _,squad in pairs(mine.squads) do
        FighterController():setSquadOrders(squad, FighterOrders.Attack, mine.target.index)
    end
    mine.applyState("Fine", {}, "Mining", {})
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

    mine.squads = cc.claimSquads(mine.prefix, squads)
    mine.hasRawLasers = false
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
    local state, stateArgs, action, actionArgs
    mine.target = nil
    local ship = Entity()
    local sector = Sector()
    local currentPos

    -- if mothership has enough Cargo

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
                            --print("Selected Asteroid with material:", material.name, c)
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
        state, stateArgs = "Fine", {}
        action, actionArgs = "Mining", {}
        return true, state, stateArgs, action, actionArgs
    else
        mine.target = nil
        if higherMaterialLevel then
            state, stateArgs = "AsteroidWithHigherMaterialPresent", {higherMaterialLevel.name}
            action, actionArgs = "Idle", {}
            return false, state, stateArgs, action, actionArgs
        else
            state, stateArgs = "NoAsteroid", {}
            action, actionArgs = "Idle", {}
            return false, state, stateArgs, action, actionArgs
        end
    end
end

-- Has to be invoked, when fired due to Events from CarrierCommander.lua
function mine.registerTarget()
    local registered = mine.target:registerCallback("onDestroyed", "onTargetDestroyed")
    return registered
end

function mine.setSquadsIdle()
    local order = cc.settings.mineStopOrder
    for _,squad in pairs(mine.squads) do
        FighterController():setSquadOrders(squad, order, Entity().index)
    end
end

function mine.scoopLoot(position)
    local possibleLoot = {Sector():getEntitiesByType(EntityType.Loot)}
    local ship = Entity()
    local loots, c = {}, 1

    for _, loot in pairs(possibleLoot) do
        if loot:isCollectable(ship) and distance(loot.translationf, position) < 40000 then
            loots[c] = loot
            mine.looterlist[loot.index.string] = false
            c = c + 1
        end
    end
    print("found #loot", #loots, #possibleLoot)

    local allFighters = {}
    local x = 1
    local a,s = next(mine.squads)

    for _,squad in pairs(mine.squads) do
        for _,f in pairs({FighterController():getDeployedFighters(squad)}) do
            allFighters[#allFighters+1] = f
        end
    end
    print("found #fighters", #allFighters)

    local maxToSend = math.min(#loots, #allFighters)
    for i=1, maxToSend do
        mine.looterlist[loots[i].index.string] = allFighters[i].index.string
        local ai = FighterAI(allFighters[i].index)
        allFighters[i]:registerCallback("onLootCollected", "onLootCollected")
        ai.clearFeedbackEachTick = false
        ai.ignoreMothershipOrders = true
        ai:setOrders(FighterOrders.Harvest, loots[i].index)
    end
    printTable(mine.looterlist)
end

function mine.onTargetDestroyed(index, lastDamageInflictor)
    print("Etype:", EntityType.Asteroid)
    printlog("Target destroyed", index.string, valid(mine.target), mine.target.type, mine.target.translationf:__tostring())
    mine.scoopLoot(mine.target.translationf)
    -- TODO scoop up loot in sphere around (2km). create one list
    -- send every fighter off to a different piece of loot of that list
    -- list [loot-uuid] = fighter-ID/false map, when loot gets "onLootDestroyed", to recognise it.
    -- finally on scooped up all loot (list empty)
    --mine.selectNewAndMine()
end

function mine.onLootCollected(collector, lootIndex)
    print("Fighter collected", lootIndex.string, collector.index.string)
    mine.looterlist[lootIndex] = nil
    for k,v in pairs(mine.looterlist) do
        if v == false then
            mine.looterlist[k] = collector.index.string
            local ai = FighterAI(collector.index)
            ai.clearFeedbackEachTick = false
            ai.ignoreMothershipOrders = true
            ai:setOrders(FighterOrders.Harvest, Uuid(k))
        end
    end
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
        -- we are waiting to get Disengaged and a different order was send to our last squad.
        -- Which makes waiting pointless. Our Job is done.
        if mine.state == "Disengaged" and order ~= cc.settings.mineStopOrder then
            if tablelength(mine.squads) <= 1 then
                printlog("squad changed terminate", cc.settings.mineStopOrder)
                mine.callTerminate()
            else --
                cc.unclaimSquads(mine.prefix, {[squadIndex] = squadIndex})
            end
        end
    end
end

function mine.onFighterAdded(squadIndex, fighterIndex, landed)
    --printlog("Fighter added", squadIndex, fighterIndex, landed)
    if mine.squads[squadIndex] then
        if landed then
            local state, stateArgs, action, actionArgs = mine.state, mine.stateArgs, mine.action, mine.actionArgs
            local missing, landingSquads = mine.dockingFighters(mine.prefix, mine.squads)
            if mine.state == "Disengaged" then
                if missing <= 0 then
                    printlog("Disengaged and all fighters returned")
                    mine.callTerminate()
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
            mine.applyState(state, stateArgs, action, actionArgs)
        else
            printlog("New fighter added", squadIndex, fighterIndex)
            if valid(mine.target) then mine.target:unregisterCallback("onDestroyed", "onDestroyed") end
            mine.target = nil
            mine.selectNewAndMine()
            -- New figter added to this squad. Check for resource capabilities
        end
    end
end

function mine.onFighterRemove(squadIndex, fighterIndex, started)
    if started then
        -- mhh
    else
        printlog("Fighter removed from squad", squadIndex, fighterIndex)
        if valid(mine.target) then mine.target:unregisterCallback("onDestroyed", "onDestroyed") end
        mine.target = nil
        mine.selectNewAndMine()
    end
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
    printlog("onSettingChanged", setting, before, now, cc.settings.mineStopOrder)
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
