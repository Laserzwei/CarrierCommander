if not cc then print("[CC-Minecommand]", "Something went wrong CC mainscript not found") return end

package.path = package.path .. ";data/scripts/lib/?.lua"
include ("faction")
include ("utility")
include ("callable")
local docker = include ("data/scripts/lib/dockingLib")

local printer = include ("data/scripts/lib/printlib")
local aprinter = printer("[CC-Minecommand] ", "Error")
local print = function (...) return aprinter:print(...) end
local printlog = function (...) return aprinter:printlog(...) end

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
        local sector = Sector()

        sector:registerCallback("onEntityCreated", "onEntityCreated")
        --sector:registerCallback("onEntityEntered", "onEntityEntered")
        local entity = Entity()
        --entity:registerCallback("onSquadAdded","onSquadAdded")
        --entity:registerCallback("onSquadRemove","onSquadRemove")
        entity:registerCallback("onSquadOrdersChanged","onSquadOrdersChanged")

        --entity:registerCallback("onFighterStarted","onFighterStarted")
        --entity:registerCallback("onFighterLanded","onFighterLanded")
        entity:registerCallback("onFighterAdded","onFighterAdded")
        entity:registerCallback("onFighterRemove","onFighterRemove")
        -- sector change
        entity:registerCallback("onJump", "onJump")
        entity:registerCallback("onSectorEntered", "onSectorEntered")

        if mine.state == "Disengaged" then
            mine.selectNewAndMine()
        elseif mine.state == "NoCargospace" then
            if Entity().freeCargoSpace < 10 then
                mine.getSquadsToManage()
                if mine.hasRawLasers == true then
                    printlog("Info","Raw mining/salvaging fighters are now properly detected. If you read this inform Laserzwei to update his Carrier Commander Mod.")
                else
                    printlog("Info","Raw mining/salvaging fighters are still not properly detected. Also re-enable your mining/salvaging command!")
                    Entity():registerCallback("onCargoChanged", "onCargoChanged")
                end
                --mine.selectNewAndMine() --uncomment when fixed
            else
                mine.selectNewAndMine()
            end
        else
            mine.selectNewAndMine()
        end
    else
        invokeServerFunction("sendState") -- makes sure the current state is available on client
    end
end

-- proxy for startup
function mine.sendState()
    Entity():invokeFunction("data/scripts/entity/CarrierCommander.lua", "sendState", mine.prefix)
end
callable(mine, "sendState")

function mine.applyState(state, stateArgs, action, actionArgs)
    if onServer() then
        print("Debug","Apply State: ", mine.state, state, unpack(stateArgs), "Apply Action: ", mine.action, action, unpack(actionArgs))
        Entity():invokeFunction("data/scripts/entity/CarrierCommander.lua", "changeState", mine.prefix, state, stateArgs or {}, action, actionArgs or {})
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
        printlog("Debug","Mine Terminate")
        mine.callTerminate()
    else
        local total, landing = docker.dockingFighters(mine.prefix, mine.squads)
        local action = FighterOrders.Return
        local actionArgs = {total, tablelength(landing), Entity().name}
        mine.applyState("Disengaged", {}, action, actionArgs)
        if total <= 0 then
            printlog("Debug","Mine [D] Terminate")
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
        printlog("Error","Fixed yet? - No!")
        local repathed = string.gsub(path, "/", "\\")
        local state = Entity():invokeFunction(repathed, "terminatus")
    else
        printlog("Warn","Fixed yet? - Maybe yes")
    end
end

function mine.selectNewAndMine()
    if mine.getSquadsToManage() then
        printlog("Debug","Has Raw?", mine.hasRawLasers)
        if mine.hasRawLasers == false or (mine.hasRawLasers == true and Entity().freeCargoSpace > 10) then
            local mining = {mine.findMineableAsteroid()} -- mining[1] contains success, [2] is the subsequent state, [3] are stateArgs, [4] is action, [5] actionState
            if mining[1] then
                if mine.hasRawLasers == true then
                    Entity():registerCallback("onCargoChanged", "onCargoChanged")
                    printlog("Debug","Enabled cargo watch")
                end
                mine.mine()
            else
                Entity():unregisterCallback("onCargoChanged", "onCargoChanged")
                mine.setSquadsIdle()
                table.remove(mining, 1) -- remove success, to only keep state & action and their Args
                mine.applyState(unpack(mining))
            end
        else
            if mine.hasRawLasers == true then
                Entity():registerCallback("onCargoChanged", "onCargoChanged")
                printlog("Debug","Enabled cargo watch2")
            else
                Entity():unregisterCallback("onCargoChanged", "onCargoChanged")
            end
            mine.setSquadsIdle()
            mine.applyState("NoCargospace", {}, "None", {})
        end
    else
        Entity():unregisterCallback("onCargoChanged", "onCargoChanged")
        mine.applyState("TargetButNoFighter", {}, "None", {})
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
        printlog("All", "Set raw", mine.hasRawLasers, hangar:getSquadHasRawMinersOrSalvagers(squad), squad, mine.miningMaterial)
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
    local oldtarget = valid(mine.target) and mine.target.index.number or 0
    mine.target = nil
    local ship = Entity()
    local sector = Sector()
    local currentPos

    -- if mothership has enough Cargo

    if cc.settings["mineSquadNearest"] then
        local FighterController = FighterController()
        local num, pos = 0, vec3(0,0,0)
        for _,squad in pairs(mine.squads) do
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
            if dist < nearest and oldtarget ~= a.index.number then
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
                        if dist < nearest and oldtarget ~= a.index.number then
                            nearest = dist
                            printlog("All","Selected Asteroid with material:", material.name, c)
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

function mine.onCargoChanged(objectIndex, delta, good)
    printlog("All","Cargo changed", objectIndex.string, delta, good.name, Entity().freeCargoSpace)
    if (mine.hasRawLasers == true and Entity().freeCargoSpace < 10) then
        if mine.state ~= "NoCargospace" then
            mine.setSquadsIdle()
            mine.applyState("NoCargospace", {}, "None", {})
        end
    --Continue mining, after cargo got removed
    elseif delta < 0 and (mine.hasRawLasers == true and Entity().freeCargoSpace > 10) then
        printlog("Debug","cargo removed?", delta)
        mine.selectNewAndMine()
    elseif mine.hasRawLasers == false then
        Entity():unregisterCallback("onCargoChanged", "onCargoChanged")
        mine.selectNewAndMine()
    end
end

function mine.onTargetDestroyed(index, lastDamageInflictor)
    printlog("Debug","Target destroyed", index.string, valid(mine.target), mine.target.type, mine.target.translationf:__tostring())
    mine.selectNewAndMine()
end

-- only change Asteroid, when no other is available
function mine.onEntityCreated(entityId)
    local entity = Entity(entityId)
    printlog("Debug", "onEntityCreated", entity.isAsteroid)
    if entity.isAsteroid then
        if not valid(mine.target) then
            mine.selectNewAndMine()
        end
    end
end

function mine.onSquadOrdersChanged(_, squadIndex, order, targetId)
    if mine.squads[squadIndex] then
        printlog("Debug","Squad Order", squadIndex, ordernames[order], targetId.string, mine.state)
        -- we are waiting to get Disengaged and a different order was send to our last squad.
        -- Which makes waiting pointless. Our Job is done.
        if mine.state == "Disengaged" and order ~= cc.settings.mineStopOrder then
            if tablelength(mine.squads) <= 1 then
                printlog("Debug","squad changed terminate", cc.settings.mineStopOrder)
                -- TODO make sure this gets to the client
                mine.callTerminate()
            else --
                cc.unclaimSquads(mine.prefix, {[squadIndex] = squadIndex})
            end
        elseif mine.state ~= "Disengaged" and targetId.string == "00000000-0000-0000-0000-000000000000" then -- vanilla orderchain command fucking things up
            mine.selectNewAndMine()
        end
    end
end

function mine.onFighterAdded(_, squadIndex, fighterIndex, landed)
    print("All","Fighter added", squadIndex, fighterIndex, landed)
    if mine.squads[squadIndex] then
        if landed then
            local state, stateArgs, action, actionArgs = mine.state, mine.stateArgs, mine.action, mine.actionArgs
            local missing, landingSquads = mine.dockingFighters(mine.prefix, mine.squads)
            if mine.state == "Disengaged" then
                if missing <= 0 then
                    printlog("Debug","Disengaged and all fighters returned")
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
            printlog("Debug","New fighter added", squadIndex, fighterIndex)
            if valid(mine.target) then mine.target:unregisterCallback("onDestroyed", "onDestroyed") end
            mine.target = nil
            mine.selectNewAndMine()
            -- New figter added to this squad. Check for resource capabilities
        end
    end
end

function mine.onFighterRemove(_, squadIndex, fighterIndex, started)
    if started then
        -- mhh
    else
        printlog("Debug","Fighter removed from squad", squadIndex, fighterIndex)
        if valid(mine.target) then mine.target:unregisterCallback("onDestroyed", "onDestroyed") end
        mine.target = nil
        mine.selectNewAndMine()
    end
end

function mine.onJump(shipIndex, x, y)
    if valid(mine.target) then
        printlog("Debug","onjump")
        mine.target:unregisterCallback("onDestroyed", "onTargetDestroyed")
        mine.target = nil
    end
end

function mine.onSectorEntered(shipIndex, x, y)
    printlog("Debug","Entered Sector: ", x, y)
    mine.selectNewAndMine()
end

function mine.onSettingChanged(setting, before, now)
    printlog("Error","onSettingChanged", setting, before, now, cc.settings.mineStopOrder)
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
