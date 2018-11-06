if not onServer() then return end

local entity = Entity()

if entity:hasComponent(ComponentType.DockingPositions) then
    entity:addScriptOnce("entity/regrowdocks.lua")
end

if entity.allianceOwned then
    entity:removeScript("entity/claimalliance.lua")
    entity:addScriptOnce("entity/claimalliance.lua")
end

if entity.isShip or entity.isStation then
    if entity.allianceOwned then
        entity:addScriptOnce("mods/CarrierCommander/scripts/entity/CarrierCommander.lua")
    end
    if entity.playerOwned then
        entity:addScriptOnce("mods/CarrierCommander/scripts/entity/CarrierCommander.lua")
    end
end
