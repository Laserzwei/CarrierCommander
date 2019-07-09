local docking = {}
function docking.dockingFighters(prefix, squads)
    local total, landingSquads = 0, {}
    local hangar = Hangar(Entity().index)
    for _,squad in pairs(squads) do
        local missingFighters = (12-hangar:getSquadFreeSlots(squad)) - hangar:getSquadFighters(squad)
        if missingFighters > 0 then
            total = total + missingFighters
            landingSquads[squad] = squad
        else
            --_G["cc"].unclaimSquads(prefix, {squad})
        end
    end
    return total, landingSquads
end


function docking.integrate(ns)
    ns.dockingFighters = docking.dockingFighters
end

return docking
