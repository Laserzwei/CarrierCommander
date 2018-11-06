Install instructions
Place the contents of the "mods" folder into your /steam/.../Avorion/mods/ foldePlace the contents of /data/ in /Avorion/data/.
This will overwrite:

  /scripts/entity/init.lua
  /scripts/entity/shipfounder.lua

In case of mod conflicts:

(With shipfounder.lua)
Go to /Avorion/data/scripts/entity/shipfounder.lua and open it in your favourite text editor(e.g. Notepad++).
In line 140 (close to the end) replace the line
ship:addScript("entity/claimalliance.lua")
with
ship:addScriptOnce("entity/claimalliance.lua")


(With init.lua)
Instead of overwriting init.lua, you can instead add:

if entity.isShip then
    if entity.allianceOwned then
        entity:addScriptOnce("mods/CarrierCommander/scripts/entity/CarrierCommander.lua")
    end
    if entity.playerOwned then
        entity:addScriptOnce("mods/CarrierCommander/scripts/entity/CarrierCommander.lua")
    end
end

at the end of the file.
