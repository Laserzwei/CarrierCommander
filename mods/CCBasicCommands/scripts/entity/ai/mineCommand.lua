
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")
local docker = require ("mods.CarrierCommander.scripts.lib.dockingLib")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace mine
mine = {}
docker.integrate(mine)

--data
mine.prefix = "mine"
mine.squads = {}                 --[squadIndex] = squadIndex           --squads to manage
mine.controlledFighters = {}     --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
mine.disabled = false

local checkAfterInit = true

function mine.initialize()
    if onServer() then

    else
        mine.applyStatus("idle")
    end
end

function mine.getUpdateInterval()
    if not valid(mine.target) and mine.disabled == false then return 15 end
    if valid(mine.target) and mine.disabled == false then return 5 end
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
        if  _G["cc"].uiInitialized then
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
    for _,squad in pairs(mine.squads) do
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
    for _,squad in pairs(mine.squads) do
        fighterController:setSquadOrders(squad, FighterOrders.Attack, mine.target.index)
    end
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
    if next(mine.squads) then
        return true
    else
        return false
    end
end

-- check the sector for an asteroid that can be mined.
-- if there is one, assign minableAsteroid
function mine.findMinableAsteroid()
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

    local asteroids = {sector:getEntitiesByType(EntityType.Asteroid)}
    local nearest = math.huge
    --Go after the asteroid closest to the one just finished (Nearest Neighbor)
    for _, a in pairs(asteroids) do
        local resources = a:getMineableResources()
        if ((resources ~= nil and resources > 0) or _G["cc"].settings["mineAllSetting"]) then
            local dist = distance2(a.translationf, currentPos)
            if dist < nearest then
                nearest = dist
                mine.target = a
            end
        end
    end

    return valid(mine.target)
end

function mine.setSquadsIdle()
    local fighterController = FighterController(Entity().index)
    mine.order = _G["cc"].settings.mineStopOrder or FighterOrders.Return
    for _,squad in pairs(mine.squads) do
        fighterController:setSquadOrders(squad, mine.order, Entity().index)
    end
end

function mine.secure()
    local data = {}
    data.squads= mine.squads
    data.order = mine.order
    data.disabled = mine.disabled
    return data
end

function mine.restore(dataIn)
    mine.squads = dataIn.squads
    mine.order = dataIn.order
    mine.disabled = dataIn.disabled or false
end
