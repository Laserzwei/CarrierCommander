
local docking = {}

function docking.dockingFighters(prefix, squads)
    local total, numSquads = 0, 0
    for _,squad in pairs(squads) do

        local hangar = Hangar(Entity().index)
        local missingFighters = (12 -hangar:getSquadFreeSlots(squad)) -  hangar:getSquadFighters(squad)
        if missingFighters > 0 then
            total = total + missingFighters
            numSquads = numSquads + 1
        else
            _G["cc"].unclaimSquads(prefix, {squad})
        end
    end
    return total, numSquads
end


function docking.integrate(ns)
    ns.dockingFighters = docking.dockingFighters
end

return docking
