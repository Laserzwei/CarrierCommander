if onServer() then

local entity = Entity()
if entity.isShip or entity.isStation then
    if entity.allianceOwned or entity.playerOwned then
        if not entity:hasScript("CarrierCommander.lua") then
            entity:addScriptOnce("data/scripts/entity/CarrierCommander.lua")
        end
    end
end
end
