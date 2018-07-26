
local docking = {}

function docking.dockingFighters(prefix, squads)
    local total, numSquads = 0, 0
    for _,squad in pairs(squads) do

        local hangar = Hangar(Entity().index)
        local missingFighters = (12 -hangar:getSquadFreeSlots(squad)) -  hangar:getSquadFighters(squad)
        print(squad, total, numSquads)
        if missingFighters > 0 then
            total = total + missingFighters
            numSquads = numSquads + 1
        else
            print("unclaim", squad)
            _G["cc"].unclaimSquads(prefix, {squad})
        end
    end
    return total, numSquads
end

return docking
