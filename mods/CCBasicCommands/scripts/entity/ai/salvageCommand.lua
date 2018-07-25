
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace salvage
salvage = {}

--data
salvage.prefix = "salvage"
salvage.squads = {}                  --[squadIndex] = squadIndex           --squads to manage
salvage.controlledFighters = {}      --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
salvage.disabled = false

local checkAfterInit = true

function salvage.initialize()
    if onServer() then

    else
        salvage.applyStatus("idle")
    end
end

function salvage.getUpdateInterval()
    if not valid(salvage.target) then return 15 end

    return 1
end

function salvage.updateServer(timestep)
    print("tar", valid(salvage.target))
    if not valid(salvage.target) then
        if salvage.getSquadsToManage() then
            if salvage.findWreckage() then
                broadcastInvokeClientFunction("applyStatus", 6)
                salvage.salvage()
            else
                salvage.setSquadsIdle()
                if salvage.order == FighterOrders.Return then

                    local total, numSquads = salvage.dockingFighters()
                    if numSquads <= 0 then
                        broadcastInvokeClientFunction("applyStatus", "idle")
                    else
                        broadcastInvokeClientFunction("applyStatus", FighterOrders.Return, total, numSquads, Entity().name)
                    end
                end
            end
        else
            broadcastInvokeClientFunction("applyStatus", "targetButNoFighter")
        end
    else

    end
    if salvage.disabled == true then
        if salvage.order == FighterOrders.Return then
            salvage.squads = _G["cc"].claimSquads(salvage.prefix, squads)

            local total, numSquads = salvage.dockingFighters()

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

function salvage.dockingFighters()
    local total, numSquads = 0, 0
    for _,squad in pairs(salvage.squads) do
        local hangar = Hangar(Entity().index)
        local missingFighters = (12 -hangar:getSquadFreeSlots(squad)) -  hangar:getSquadFighters(squad)

        if missingFighters > 0 then
            total = total + missingFighters
            numSquads = numSquads + 1
        else
            _G["cc"].unclaimSquads(salvage.prefix, {squad})
        end
    end
    return total, numSquads
end

function salvage.updateClient(timestep)
    if checkAfterInit and _G["cc"].uiInitialized then
        checkAfterInit = false
        print("oh no")
        _G["cc"].commands[salvage.prefix].activationButton.onPressedFunction = "buttonDeactivate"
    end
end

function salvage.applyStatus(status, ...)
    if onClient() then
        print(status, ...)
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
    salvage.target = Entity()
    salvage.order = _G["cc"].settings.salvageStopOrder or FighterOrders.Return
    local fighterController = FighterController(Entity().index)
    salvage.squads = _G["cc"].getClaimedSquads(salvage.prefix)
    for _,squad in pairs(salvage.squads) do
        fighterController:setSquadOrders(squad, salvage.order, salvage.target.index)
    end

    if salvage.order ~= FighterOrders.Return then
        _G["cc"].unclaimSquads(salvage.squads)
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
    if not hangar or hangar.space <= 0 then print("noHangar") return end

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
    local sector = Sector()
    local currentPos

    --Cwhizard's Nearest-Neighbor
    if cc.settings[salvage.prefix.."salvageNN"] then
        currentPos = salvage.target.translationf or ship.translationf
    else
        currentPos = ship.translationf
    end
    --Cwhizard

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
    if salvage.target then data.target = salvage.target.index.string end
    data.order = salvage.order
    data.disabled = salvage.disabled
    return data
end

function salvage.restore(dataIn)
    salvage.squads = dataIn.squads
    if dataIn.target then salvage.target =  Entity(Uuid(dataIn.target)) end
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