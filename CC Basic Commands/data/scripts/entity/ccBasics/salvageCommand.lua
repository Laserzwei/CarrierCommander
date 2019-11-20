if not cc then print("[CC-Salvagecommand]", "Something went wrong CC mainscript not found") return end

package.path = package.path .. ";data/scripts/lib/?.lua"
include ("faction")
include ("utility")
include ("callable")
local docker = include ("data/scripts/lib/dockingLib")

local printer = include ("data/scripts/lib/printlib")
local aprinter = printer("[CC-Salvagecommand] ", "Error")
local print = function (...) return aprinter:print(...) end
local printlog = function (...) return aprinter:printlog(...) end

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace salvage
salvage = {}
docker.integrate(salvage)

--data
salvage.prefix = "salvage"
salvage.squads = {}                 --[squadIndex] = squadIndex           --squads to manage
salvage.controlledFighters = {}     --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
salvage.state = -1
salvage.stateArgs = {}
salvage.action = -1
salvage.actionArgs = {}

salvage.hasRawLasers = false
salvage.miningMaterial = nil

local ordernames = {
    [FighterOrders.Attack] = "Attack",
    [FighterOrders.Defend] = "Defend",
    [FighterOrders.Return] = "Return",
    [FighterOrders.Harvest] = "Harvest",
    [FighterOrders.FlyToLocation] = "FlyToLocation",
    [FighterOrders.Board] = "Board"
}
function salvage.initializationFinished()
    if onServer() then
        if salvage.state == "Disengaged" then
            salvage.selectNewAndSalvage()
        elseif salvage.state == "NoCargospace" then
            if Entity().freeCargoSpace < 10 then
                salvage.getSquadsToManage()
                if salvage.hasRawLasers == true then
                    printlog("Info","Raw mining/salvaging fighters are now properly detected. If you read this inform Laserzwei to update his Carrier Commander Mod.")
                else
                    printlog("Info","Raw mining/salvaging fighters are still not properly detected. Also re-enable your mining/salvaging command!")
                    Entity():registerCallback("onCargoChanged", "onCargoChanged")
                end
                --salvage.selectNewAndSalvage() --uncomment when fixed
            else
                salvage.selectNewAndSalvage()
            end
        else
            salvage.selectNewAndSalvage()
        end
    else
        invokeServerFunction("sendState") -- makes sure the current state is available on client
    end
end

function salvage.applyState(state, stateArgs, action, actionArgs)
    if onServer() then
        printlog("Info","Apply State: ", salvage.state, state, unpack(stateArgs))
        printlog("Info","Apply Action: ", salvage.action, action, unpack(actionArgs))
        salvage.state = state
        salvage.stateArgs = stateArgs or {}
        salvage.action = action
        salvage.actionArgs = actionArgs or {}
        salvage.sendState()
    end
end

-- No passable arguments, so no invalid states can be sneaked in
function salvage.sendState()
    broadcastInvokeClientFunction("receiveSalvageState", salvage.state, salvage.stateArgs, salvage.action, salvage.actionArgs)
end
callable(salvage, "sendState")

function cc.receiveSalvageState(...)
    printlog("All","cc receiveSalvageState")
    salvage.receiveSalvageState(...)
end

function salvage.receiveSalvageState(state, stateArgs, action, actionArgs)
    if onClient() then
        printlog("All","Received state: ", salvage.state, state, unpack(stateArgs), salvage.action, action, unpack(actionArgs))
        salvage.state = state
        salvage.stateArgs = stateArgs
        salvage.action = action
        salvage.actionArgs = actionArgs
        if cc.uiInitialized then
            local text = salvage.createStatusMessage()
            local color = cc.l.actionToColorMap[state]
            cc.changeIndicator("salvage", text, color)
        end
    end
end

function salvage.createStatusMessage()
    local text = string.format(cc.l.actionTostringMap[salvage.state], unpack(salvage.stateArgs))
    text = text .. "\n" .. string.format(cc.l.actionTostringMap[salvage.action], unpack(salvage.actionArgs))
    return text
end

-- set final orders for all controlled squads
function salvage.disable()
    if valid(salvage.target) then
        salvage.target:unregisterCallback("onDestroyed", "onTargetDestroyed")
    end
    salvage.target = nil
    local order = cc.settings.salvageStopOrder
    salvage.squads = cc.getClaimedSquads(salvage.prefix)
    for _,squad in pairs(salvage.squads) do
        FighterController():setSquadOrders(squad, order, Entity().index)
    end

    if order ~= FighterOrders.Return then
        salvage.applyState("Disengaged", {}, "None", {})
        printlog("Debug","salvage Terminate")
        salvage.callTerminate()
    else
        local total, landing = docker.dockingFighters(salvage.prefix, salvage.squads)
        local action = FighterOrders.Return
        local actionArgs = {total, tablelength(landing), Entity().name}
        salvage.applyState("Disengaged", {}, action, actionArgs)
        if total <= 0 then
            printlog("Debug","salvage [D] Terminate")
            salvage.callTerminate()
        end
    end
end

function salvage.callTerminate()
    cc.unclaimSquads(salvage.prefix, salvage.squads)
    cc.clearIndicator(salvage.prefix)
    local path = cc.commands[salvage.prefix].path..".lua"
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

function salvage.terminatus()
    terminate()
end

function salvage.selectNewAndSalvage()
    if salvage.getSquadsToManage() then
        printlog("Debug","Has Raw?", salvage.hasRawLasers)
        if salvage.hasRawLasers == false or (salvage.hasRawLasers == true and Entity().freeCargoSpace > 10) then
            local salvaging = {salvage.findWreckage()} -- salvaging[1] contains success, [2] is the subsequent state, [3] are stateArgs, [4] is action, [5] actionState
            if salvaging[1] then
                if salvage.hasRawLasers == true then
                    Entity():registerCallback("onCargoChanged", "onCargoChanged")
                    printlog("Debug","Enabled cargo watch")
                end
                salvage.salvage()
            else
                Entity():unregisterCallback("onCargoChanged", "onCargoChanged")
                salvage.setSquadsIdle()
                table.remove(salvaging, 1) -- remove success, to only keep state & action and their Args
                salvage.applyState(unpack(salvaging))
            end
        else
            if salvage.hasRawLasers == true then
                Entity():registerCallback("onCargoChanged", "onCargoChanged")
                printlog("Debug","Enabled cargo watch2")
            else
                Entity():unregisterCallback("onCargoChanged", "onCargoChanged")
            end
            salvage.setSquadsIdle()
            salvage.applyState("NoCargospace", {}, "None", {})
        end
    else
        Entity():unregisterCallback("onCargoChanged", "onCargoChanged")
        salvage.applyState("TargetButNoFighter", {}, "None", {})
    end
end

function salvage.salvage()
    for _,squad in pairs(salvage.squads) do
        FighterController():setSquadOrders(squad, FighterOrders.Attack, salvage.target.index)
    end
    salvage.applyState("Fine", {}, "Salvaging", {})
end

function salvage.getSquadsToManage()
    local hangar = Hangar(Entity().index)
    if not hangar or hangar.space <= 0 then return end

    local squads = {}
    for _,squad in pairs({hangar:getSquads()}) do
        if hangar:getSquadMainWeaponCategory(squad) == WeaponCategory.Salvaging then
            squads[squad] = squad
        end
    end

    salvage.squads = cc.claimSquads(salvage.prefix, squads)
    salvage.hasRawLasers = false
    for _,squad in pairs(salvage.squads) do
        printlog("All", "Set raw", salvage.hasRawLasers, hangar:getSquadHasRawMinersOrSalvagers(squad), squad, salvage.miningMaterial)
        salvage.hasRawLasers = salvage.hasRawLasers or hangar:getSquadHasRawMinersOrSalvagers(squad)
        if salvage.miningMaterial == nil or hangar:getHighestMaterialInSquadMainCategory(squad).value > salvage.miningMaterial then
            salvage.miningMaterial = hangar:getHighestMaterialInSquadMainCategory(squad).value
        end
    end

    if next(salvage.squads) then
        return true
    else
        return false
    end
end

-- check the sector for an wreckage that can be salvaged.
-- if there is one, assign salvage.target
function salvage.findWreckage()
    local state, stateArgs, action, actionArgs
    local oldtarget = valid(salvage.target) and salvage.target.index.number or 0
    salvage.target = nil
    local ship = Entity()
    local sector = Sector()
    local currentPos

    -- if mothership has enough Cargo

    if cc.settings["salvageSquadNearest"] then
        local FighterController = FighterController()
        local num, pos = 0, vec3(0,0,0)
        for _,squad in pairs(salvage.squads) do
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

    local higherMaterialLevel = nil
    local wreckages = {sector:getEntitiesByType(EntityType.Wreckage)}
    local nearest = math.huge

    for _, w in pairs(wreckages) do
        local resources = {w:getMineableResources()}
        if #resources > 0 and salvage.sum(resources) >= 5 then
            local material = w:getLowestMineableMaterial()
            if material.value <= salvage.miningMaterial + 1 then
                local dist = distance2(w.translationf, currentPos)
                if dist < nearest and oldtarget ~= w.index.number then
                    nearest = dist
                    salvage.target = w
                end
            else
                higherMaterialLevel = material
            end
        end
    end

    if valid(salvage.target) then
        Entity():invokeFunction("salvageCommand.lua", "registerTarget")
        state, stateArgs = "Fine", {}
        action, actionArgs = "Salvaging", {}
        return true, state, stateArgs, action, actionArgs
    else
        salvage.target = nil
        if higherMaterialLevel then
            state, stateArgs = "WreckageWithHigherMaterialPresent", {higherMaterialLevel.name}
            action, actionArgs = "Idle", {}
            return false, state, stateArgs, action, actionArgs
        else
            state, stateArgs = "NoWreckage", {}
            action, actionArgs = "Idle", {}
            return false, state, stateArgs, action, actionArgs
        end
    end
end

-- Has to be invoked, when fired due to Events from CarrierCommander.lua
function salvage.registerTarget()
    local registered = salvage.target:registerCallback("onDestroyed", "onTargetDestroyed")
    return registered
end

function salvage.setSquadsIdle()
    local order = cc.settings.salvageStopOrder
    for _,squad in pairs(salvage.squads) do
        FighterController():setSquadOrders(squad, order, Entity().index)
    end
end

function salvage.onCargoChanged(objectIndex, delta, good)
    printlog("All","Cargo changed", objectIndex.string, delta, good.name, Entity().freeCargoSpace)
    if (salvage.hasRawLasers == true and Entity().freeCargoSpace < 10) then
        if salvage.state ~= "NoCargospace" then
            salvage.setSquadsIdle()
            salvage.applyState("NoCargospace", {}, "None", {})
        end
    --Continue mining, after cargo got removed
    elseif delta < 0 and (salvage.hasRawLasers == true and Entity().freeCargoSpace > 10) then
        printlog("Debug","cargo removed?", delta)
        salvage.selectNewAndSalvage()
    elseif salvage.hasRawLasers == false then
        Entity():unregisterCallback("onCargoChanged", "onCargoChanged")
        salvage.selectNewAndSalvage()
    end
end

function salvage.onTargetDestroyed(index, lastDamageInflictor)
    printlog("Debug","Target destroyed", index.string, valid(salvage.target), salvage.target.type, salvage.target.translationf:__tostring())
    salvage.selectNewAndSalvage()
end

-- only change Asteroid, when no other is available
function salvage.onWreckageCreated(wreckage)
    if not valid(salvage.target) then
        salvage.selectNewAndSalvage()
    end
end

function salvage.onSquadOrdersChanged(squadIndex, order, targetId)
    if salvage.squads[squadIndex] then
        printlog("Debug","Squad Order", squadIndex, ordernames[order], targetId.string, salvage.state)
        -- we are waiting to get Disengaged and a different order was send to our last squad.
        -- Which makes waiting pointless. Our Job is done.
        if salvage.state == "Disengaged" and order ~= cc.settings.salvageStopOrder then
            if tablelength(salvage.squads) <= 1 then
                printlog("Debug","squad changed terminate", cc.settings.salvageStopOrder)
                salvage.callTerminate()
            else --
                cc.unclaimSquads(salvage.prefix, {[squadIndex] = squadIndex})
            end
        elseif salvage.state ~= "Disengaged" and targetId.string == "00000000-0000-0000-0000-000000000000" then -- vanilla orderchain command fucking things up
            salvage.selectNewAndSalvage()
        end
    end
end

function salvage.onFighterAdded(squadIndex, fighterIndex, landed)
    printlog("All","Fighter added", squadIndex, fighterIndex, landed)
    if salvage.squads[squadIndex] then
        if landed then
            local state, stateArgs, action, actionArgs = salvage.state, salvage.stateArgs, salvage.action, salvage.actionArgs
            local missing, landingSquads = salvage.dockingFighters(salvage.prefix, salvage.squads)
            if salvage.state == "Disengaged" then
                if missing <= 0 then
                    printlog("Debug","Disengaged and all fighters returned")
                    salvage.callTerminate()
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
            salvage.applyState(state, stateArgs, action, actionArgs)
        else
            printlog("Debug","New fighter added", squadIndex, fighterIndex)
            if valid(salvage.target) then salvage.target:unregisterCallback("onDestroyed", "onDestroyed") end
            salvage.target = nil
            salvage.selectNewAndSalvage()
            -- New figter added to this squad. Check for resource capabilities
        end
    end
end

function salvage.onFighterRemove(squadIndex, fighterIndex, started)
    if started then
        -- mhh
    else
        printlog("Debug","Fighter removed from squad", squadIndex, fighterIndex)
        if valid(salvage.target) then salvage.target:unregisterCallback("onDestroyed", "onDestroyed") end
        salvage.target = nil
        salvage.selectNewAndSalvage()
    end
end

function salvage.onJump(shipIndex, x, y)
    if valid(salvage.target) then
        printlog("Debug","onjump")
        salvage.target:unregisterCallback("onDestroyed", "onTargetDestroyed")
        salvage.target = nil
    end
end

function salvage.onSectorEntered(shipIndex, x, y)
    printlog("Debug","Entered Sector: ", x, y)
    salvage.selectNewAndSalvage()
end

function salvage.onSettingChanged(setting, before, now)
    printlog("Debug","onSettingChanged", setting, before, now, cc.settings.salvageStopOrder)
end

function salvage.secure()
    local data = {}
    data.squads= salvage.squads
    data.order = salvage.order
    data.state = salvage.state
    data.stateArgs = salvage.stateArgs
    return data
end

function salvage.restore(dataIn)
    salvage.squads = dataIn.squads
    salvage.order = dataIn.order
    salvage.state = dataIn.state
    salvage.stateArgs = dataIn.stateArgs
end

function salvage.sum(list)
    local amt = 0
    for _,k in pairs(list) do
        amt = amt + k
    end
    return amt
end
