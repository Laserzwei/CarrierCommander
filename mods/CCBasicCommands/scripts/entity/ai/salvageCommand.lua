
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")
local docker = require ("mods.CarrierCommander.scripts.lib.dockingLib")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace salvage
salvage = {}
docker.integrate(salvage)

--data
salvage.prefix = "salvage"
salvage.squads = {}                  --[squadIndex] = squadIndex           --squads to manage
salvage.controlledFighters = {}      --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
salvage.disabled = false

local checkAfterInit = true

function salvage.initialize()
    if onServer() then
        --salvage.updateServer(0)
    else
        salvage.applyStatus("idle")
    end
end

function salvage.getUpdateInterval()
    if not valid(salvage.target) and salvage.disabled == false then return 15 end

    return 1
end

function salvage.updateServer(timestep)
    if salvage.disabled == false then
        if not valid(salvage.target) then
            if salvage.getSquadsToManage() then
                if salvage.findWreckage() then
                    broadcastInvokeClientFunction("applyStatus", 6)
                    salvage.salvage()
                else
                    salvage.setSquadsIdle()
                    if salvage.order == FighterOrders.Return then

                        local total, numSquads = salvage.dockingFighters(salvage.prefix, salvage.squads)
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
        salvage.setSquadsIdle()
        if salvage.order == FighterOrders.Return then
            salvage.squads = _G["cc"].claimSquads(salvage.prefix, salvage.squads)

            local total, numSquads = salvage.dockingFighters(salvage.prefix, salvage.squads)

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

function salvage.applyStatus(status, ...)
    if onClient() then
        if  _G["cc"].uiInitialized then
            local args = {...}

            local pic = _G["cc"].commands[salvage.prefix].statusPicture

            pic.color = _G["cc"].l.actionToColorMap[status]
            pic.tooltip = string.format(_G["cc"].l.actionTostringMap[status], unpack(args))
        end
    else
        print("why?")
    end
end

-- set final orders for all controlled squads
function salvage.disable()
    salvage.disabled = true
    salvage.target = nil
    salvage.order = _G["cc"].settings.salvageStopOrder or FighterOrders.Return
    local fighterController = FighterController(Entity().index)
    salvage.squads = _G["cc"].getClaimedSquads(salvage.prefix)
    for _,squad in pairs(salvage.squads) do
        fighterController:setSquadOrders(squad, salvage.order, Entity().index)
    end

    if salvage.order ~= FighterOrders.Return then
        _G["cc"].unclaimSquads(salvage.prefix, salvage.squads)
        broadcastInvokeClientFunction("applyStatus", -1)
        terminate()
    end
end

function salvage.salvage()
    local fighterController = FighterController(Entity().index)
    for _,squad in pairs(salvage.squads) do
        fighterController:setSquadOrders(squad, FighterOrders.Attack, salvage.target.index)
    end
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
    salvage.squads = _G["cc"].claimSquads(salvage.prefix, squads)
    if next(salvage.squads) then
        return true
    else
        return false
    end
end

-- check the sector for an wreckage that can be salvaged.
-- if there is one, assign target
function salvage.findWreckage()
    local ship = Entity()
    local numID = ship.index.number
    local sector = Sector()
    local currentPos

    if _G["cc"].settings["salvageSquadNearest"] then
        local fighters = {Sector():getEntitiesByType(EntityType.Fighter)}
        local num, pos = 0, vec3(0,0,0)
        for _,fighter in pairs(fighters) do
            local fAI = FighterAI(fighter)
            if fAI.mothershipId.number == numID and salvage.squads[fAI.squad] then
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

    local wreckages = {sector:getEntitiesByType(EntityType.Wreckage)}
    local nearest = math.huge
    --Go after closest wreckage first
    for _, w in pairs(wreckages) do
        local resources = salvage.sum({w:getMineableResources()})

        if resources ~= nil and resources > 5 and not w.isAsteroid then
            local dist = distance2(w.translationf, currentPos)
            if dist < nearest then
                nearest = dist
                salvage.target = w
            end
        end
    end
    return valid(salvage.target)
end

function salvage.setSquadsIdle()
    local fighterController = FighterController(Entity().index)
    salvage.order = _G["cc"].settings.salvageStopOrder or FighterOrders.Return
    for _,squad in pairs(salvage.squads) do
        fighterController:setSquadOrders(squad, salvage.order, Entity().index)
    end
end

function salvage.secure()
    local data = {}
    data.squads= salvage.squads
    data.order = salvage.order
    data.disabled = salvage.disabled
    return data
end

function salvage.restore(dataIn)
    salvage.squads = dataIn.squads
    salvage.order = dataIn.order
    salvage.disabled = dataIn.disabled or false
end

function salvage.sum(list)
    local amt = 0
    for _,k in pairs(list) do
        amt = amt + k
    end
    return amt
end
