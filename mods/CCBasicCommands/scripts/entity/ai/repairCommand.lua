
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")
local docker = require ("mods.CarrierCommander.scripts.lib.dockingLib")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace repair
repair = {}
docker.integrate(repair)

--data
repair.prefix = "repair"
repair.squads = {}                 --[squadIndex] = squadIndex           --squads to manage
repair.disabled = false

function repair.initialize()
    if onServer() then

    else
        _G["cc"].l.actionTostringMap["repair"] = "Repairing ship %s"
        _G["cc"].l.actionToColorMap["repair"] = ColorRGB(0.1, 0.8, 0.1)
        repair.applyStatus("idle")
    end
end

function repair.getUpdateInterval()
    if not valid(repair.target) and repair.disabled == false then return 15 end
    return 1
end

function repair.updateServer(timestep)
    if repair.disabled == false then
        if not valid(repair.target) then
            if repair.getSquadsToManage() then
                if repair.findRepairTarget() then
                    broadcastInvokeClientFunction("applyStatus", "repair", repair.target.name)
                    repair.repair()
                else
                    repair.setSquadsIdle()
                    if repair.order == FighterOrders.Return then

                        local total, numSquads = repair.dockingFighters(repair.prefix, repair.squads)
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
            if repair.target.durability >= repair.target.maxDurability then
                repair.target = nil
                repair.updateServer(timestep)
            end
        end
    else
        repair.setSquadsIdle()
        if repair.order == FighterOrders.Return then
            repair.squads = _G["cc"].claimSquads(repair.prefix, repair.squads)

            local total, numSquads = repair.dockingFighters(repair.prefix, repair.squads)

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

function repair.applyStatus(status, ...)
    if onClient() then
        if  _G["cc"].uiInitialized then
            local args = {...}

            local pic = _G["cc"].commands[repair.prefix].statusPicture

            pic.color = _G["cc"].l.actionToColorMap[status]
            pic.tooltip = string.format(_G["cc"].l.actionTostringMap[status], unpack(args))
        end
    else
        print("why?")
    end
end

-- set final orders for all controlled squads
function repair.disable()
    repair.disabled = true
    repair.target = nil
    repair.order = _G["cc"].settings.repairStopOrder or FighterOrders.Return
    local fighterController = FighterController(Entity().index)
    repair.squads = _G["cc"].getClaimedSquads(repair.prefix)
    for _,squad in pairs(repair.squads) do
        fighterController:setSquadOrders(squad, repair.order, Entity().index)
    end

    if repair.order ~= FighterOrders.Return then
        _G["cc"].unclaimSquads(repair.prefix, repair.squads)
        broadcastInvokeClientFunction("applyStatus", -1)
        terminate()
    end
end

function repair.repair()
    local fighterController = FighterController(Entity().index)
    for _,squad in pairs(repair.squads) do
        fighterController:setSquadOrders(squad, FighterOrders.Attack, repair.target.index)
    end
end

function repair.getSquadsToManage()
    local hangar = Hangar(Entity().index)
    if not hangar or hangar.space <= 0 then return end

    local squads = {}
    for _,squad in pairs({hangar:getSquads()}) do
        if hangar:getSquadMainWeaponCategory(squad) == WeaponCategory.Heal then
            squads[squad] = squad
        end
    end
    repair.squads = _G["cc"].claimSquads(repair.prefix, squads)
    if next(repair.squads) then
        return true
    else
        return false
    end
end

-- check the sector for ships that need repairs.
-- if there is one, assign minableAsteroid
function repair.findRepairTarget()
    local ship = Entity()
    local sector = Sector()

    local hpSetting = _G["cc"].settings["repairLowHPSetting"]
    local repairFriendlies = _G["cc"].settings["repairFriendlySetting"]
    local currentPos = ship.translationf
    local shipFaction = ship.factionIndex

    local entities = {Sector():getEntitiesByType(EntityType.Ship)}
    local nearest = math.huge
    local lowestHp = math.huge
    local xsotan = Galaxy():findFaction("The Xsotan"%_T)--TODO check for other nationalities

    for _, e in pairs(entities) do
        if e.durability and e.maxDurability and e.factionIndex ~= xsotan.index then
            local hp = e.durability/e.maxDurability
            local dist = distance2(e.translationf, currentPos)
            if hp < 1 then
                if repairFriendlies then
                    if shipFaction == e.factionIndex or Faction(shipFaction):getRelations(e.factionIndex) > -5000 then
                        if hpSetting then
                            if hp < lowestHp then
                                lowestHp = hp
                                repair.target = e
                            end
                        else
                            if dist < nearest and e.durability < e.maxDurability then
                                nearest = dist
                                repair.target = e
                            end
                        end
                    end
                else
                    if shipFaction == e.factionIndex or (Player(shipFaction) and Player(shipFaction).alliance and Player(shipFaction).alliance.index == e.factionIndex) then
                        if hpSetting then
                            if hp < lowestHp then
                                lowestHp = hp
                                repair.target = e
                            end
                        else
                            if dist < nearest and e.durability < e.maxDurability then
                                nearest = dist
                                repair.target = e
                            end
                        end
                    end
                end
            end
        end
    end
    return valid(repair.target)
end

function repair.setSquadsIdle()
    local fighterController = FighterController(Entity().index)
    repair.order = _G["cc"].settings.repairStopOrder or FighterOrders.Return
    for _,squad in pairs(repair.squads) do
        fighterController:setSquadOrders(squad, repair.order, Entity().index)
    end
end

function repair.secure()
    local data = {}
    data.squads= repair.squads
    data.order = repair.order
    data.disabled = repair.disabled
    return data
end

function repair.restore(dataIn)
    repair.squads = dataIn.squads
    repair.order = dataIn.order
    repair.disabled = dataIn.disabled or false
end
