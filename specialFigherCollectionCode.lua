
function startminingSquads()
    miningSquads = {}
    local unknownSquads = {}
    for _,squad in pairs({hangar:getSquads()}) do
        local fighterIndex
        local template = hangar:getFighter(squad,0)
        local category = hangar:getSquadMainWeaponCategory(squad)
        if template then-- started fighters don't have a template
            if template.type == 0 and category == WeaponCategory.Mining then -- check for attackfighters & mininglasers
                for i=0, hangar:getSquadFighters(squad)-1 do -- manually start fighters to catch their uuid's
                    local fighter, error = fighterController:startFighter(squad, nil)
                    if error == 0 then
                        fighterIndex = fighter.index.string
                    else
                    end
                end
                miningSquads[squad] = fighterIndex
                fighterController:setSquadOrders(squad, FighterOrders.Defend, Entity().index)
            end
        else
            if hangar:getSquadFreeSlots(squad) < 12 then
                unknownSquads[#unknownSquads+1] = squad
            end
        end
    end
    addUnknownSquads(unknownSquads)
    if not next(miningSquads) then print("no miners"); miningSquads = nil end
    return miningSquads
end

function addUnknownSquads(pSquads)
    if not next(pSquads) then return end
    local entity = Entity()
    local owner = getInteractingFactionByShip(entity.index)
    local fighters = {Sector():getEntitiesByFaction(owner.index)}
    for _, fighter in pairs(fighters) do
        local fighterAI = FighterAI(fighter.index)
        if fighterAI and fighterAI.mothershipId.number == entity.index.number then --part of our ship
            local indicesToDelete = {}
            for i,squad in pairs(pSquads) do
                if fighterAI.squad == squad then  -- is one of the unknownSquads
                    if hangar:getSquadMainWeaponCategory(squad) == WeaponCategory.Mining then
                        miningSquads[squad] = fighter.index.string
                    end
                    table.insert(indicesToDelete,i)
                end
            end

            for _,index in pairs(indicesToDelete) do --remove found squads
                pSquads[index] = nil
            end
            if not next(pSquads) then break end --found at least one member of every unkown Squad
        end
    end
end

--Assign a fighter to the asteroid.
function setOrders(forced)
    if not miningSquads then return end
    if not next(miningSquads) then return end
    if not fighterController then return end

    local squadOrder = -1
    local squadTarget = "-1"
    local squads = {}
    for squad,member in pairs(miningSquads) do
        local fighterAI = FighterAI(Uuid(member))
        if fighterAI then
            local order = fighterAI.orders
            local target = fighterAI.target
            if order == FighterOrders.Attack  then -- sorting player commands out

                if target.number == minableAsteroid.index.number then
                    --already mining our asteroid
                else
                    fighterController:setSquadOrders(squad, FighterOrders.Attack, minableAsteroid.index)
                    squadOrder = 5
                    squadTarget = minableAsteroid.index.string
                end
            else
                local orders = {}
                orders[FighterOrders.Attack] = "Attack"
                orders[FighterOrders.Defend] = "Defend"
                orders[FighterOrders.Return] = "Return"
                orders[FighterOrders.FlyToLocation] = "FlyToLocation"
                --print("otherwisely occupied", squad, orders[order])
                if forced then
                    fighterController:setSquadOrders(squad, FighterOrders.Attack, minableAsteroid.index)
                    squadOrder = 5
                    squadTarget = minableAsteroid.index.string
                end
            end
        else
            local o = settings.mineStopOrder or FighterOrders.Return
            fighterController:setSquadOrders(squad, o, Entity().index)
            squadOrder = o
            squadTarget = Entity().index.string
        end
        squads[squad] = squad
    end
    sendCurrentActionToMaster(squadOrder, squadTarget, squads)
end