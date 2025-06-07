package.path = package.path .. ";data/scripts/lib/?.lua"
include("faction")
include("utility")
local docker = include("data/scripts/lib/dockingLib")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace mine
mine = {}
docker.integrate(mine)

-- data
mine.prefix = "mine"
mine.squads = {} -- [squadIndex] = squadIndex           --squads to manage
mine.controlledFighters = {} -- [1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
mine.disabled = false

function mine.initialize()
    if onServer() then
    else
        invokeServerFunction("initcall")
    end
end

function mine.initcall()
    mine.updateServer(1)
end
callable(mine, "initcall")

function mine.getUpdateInterval()
    if not valid(mine.target) and mine.disabled == false then
        return 15
    end
    if valid(mine.target) and mine.disabled == false then
        return 5
    end
    return 1
end

function mine.updateServer(timestep)
    if mine.disabled == false then
        if not valid(mine.target) then
            if mine.getSquadsToManage() then
                if mine.findMinableAsteroid() then
                    broadcastInvokeClientFunction("applyStatus", 5)
                    mine.mine()
                else
                    mine.setSquadsIdle()
                    if mine.order == FighterOrders.Return then

                        local total, numSquads = mine.dockingFighters(mine.prefix, mine.squads)
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

        end
    else
        mine.setSquadsIdle()
        if mine.order == FighterOrders.Return then
            mine.squads = _G["cc"].claimSquads(mine.prefix, mine.squads)

            local total, numSquads = mine.dockingFighters(mine.prefix, mine.squads)

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

function mine.applyStatus(status, ...)
    if onClient() then
        if _G["cc"].uiInitialized then
            local args = {...}

            local pic = _G["cc"].commands[mine.prefix].statusPicture

            pic.color = _G["cc"].l.actionToColorMap[status]
            pic.tooltip = string.format(_G["cc"].l.actionTostringMap[status], unpack(args))
        end
    else
        print("why?")
    end
end

-- set final orders for all controlled squads
function mine.disable()
    mine.disabled = true
    mine.target = nil
    mine.order = _G["cc"].settings.mineStopOrder or FighterOrders.Return
    local fighterController = FighterController(Entity().index)
    mine.squads = _G["cc"].getClaimedSquads(mine.prefix)
    for _, squad in pairs(mine.squads) do
        fighterController:setSquadOrders(squad, mine.order, Entity().index)
    end

    if mine.order ~= FighterOrders.Return then
        _G["cc"].unclaimSquads(mine.prefix, mine.squads)
        broadcastInvokeClientFunction("applyStatus", -1)
        terminate()
    end
end

function mine.mine()
    local fighterController = FighterController(Entity().index)
    for _, squad in pairs(mine.squads) do
        fighterController:setSquadOrders(squad, FighterOrders.Attack, mine.target.index)
    end
end

function mine.getSquadsToManage()
    local hangar = Hangar(Entity().index)
    if not hangar or hangar.space <= 0 then
        return
    end

    local squads = {}
    for _, squad in pairs({hangar:getSquads()}) do
        if hangar:getSquadMainWeaponCategory(squad) == WeaponCategory.Mining then
            squads[squad] = squad
        end
    end
    mine.squads = _G["cc"].claimSquads(mine.prefix, squads)
    if next(mine.squads) then
        return true
    else
        return false
    end
end

-- check the sector for an asteroid that can be mined.
-- if there is one, assign minableAsteroid
function mine.findMinableAsteroid()
    local operationalPos = getOperationalPosition()
    local mineAll = _G["cc"].settings["mineAllSetting"]
    if mineAll == true then
        mine.target = getNearestAsteroid(operationalPos)
    else
        mine.target = getNearestMineralAsteroid(operationalPos)
    end

    return valid(mine.target)
end

-- Helper functions

function getOperationalPosition()
    local ship = Entity()
    local numID = ship.index.number
    local currentPos

    if _G["cc"].settings["mineSquadNearest"] then
        local fighters = {Sector():getEntitiesByType(EntityType.Fighter)}
        local num, pos = 0, vec3(0, 0, 0)
        for _, fighter in pairs(fighters) do
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

    return currentPos
end

function getNearestAsteroid(operationalPos)
    local nearest = math.huge
    local nearestAsteroid
    mineable = {Sector():getEntitiesByType(EntityType.Asteroid)}

    for _, a in pairs(mineable) do
        if valid(a)
            and not isDockedToAnything(a) -- Asteroid shall not be docked to anything
            and not a:getValue("valuable_object") then -- No special objects (Mainly claimable Asteroids)
            local dist = distance2(a.translationf, operationalPos)
            if dist < nearest then
                nearest = dist
                nearestAsteroid = a
            end
        end
    end

    return nearestAsteroid
end

function getNearestMineralAsteroid(operationalPos)
    local ship = Entity()
    local hasMiningSystem = ship:hasScript("systems/miningsystem.lua")
    local nearest = math.huge
    local nearestAsteroid
    mineable = {Sector():getEntitiesByComponent(ComponentType.MineableMaterial)} -- Includes wreckages

    for _, a in pairs(mineable) do
        if valid(a)
            and a.type == EntityType.Asteroid  -- Only look for asteroids
            and not isDockedToAnything(a) -- Asteroid shall not be docked to anything
            and (a.isObviouslyMineable or hasMiningSystem) -- Accept asteroids with visible Minerals, or with Mining System installed also those with hidden minerals
            and not a:getValue("valuable_object") then -- No special objects (Mainly claimable Asteroids)
            local resources = a:getMineableResources()
            if (resources ~= nil and resources > 0) then
                local dist = distance2(a.translationf, operationalPos)
                if dist < nearest then
                    nearest = dist
                    nearestAsteroid = a
                end
            end
        end
    end

    return nearestAsteroid
end

function isDockedToAnything(asteroid)
    local clamps = DockingClamps(asteroid)
    return clamps and ({clamps:getDockedEntities()}).length > 0
end

function mine.setSquadsIdle()
    local fighterController = FighterController(Entity().index)
    mine.order = _G["cc"].settings.mineStopOrder or FighterOrders.Return
    for _, squad in pairs(mine.squads) do
        fighterController:setSquadOrders(squad, mine.order, Entity().index)
    end
end

function mine.secure()
    local data = {}
    data.squads = mine.squads
    data.order = mine.order
    data.disabled = mine.disabled
    return data
end

function mine.restore(dataIn)
    mine.squads = dataIn.squads
    mine.order = dataIn.order
    mine.disabled = dataIn.disabled or false
end
