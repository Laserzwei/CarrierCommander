# Carrier Commander
Continuation of the Carrier Command Mod

### Install instructions
Install Shipscriptloader from: https://www.avorion.net/forum/index.php/topic,3918.0.html .
Go to https://www.avorion.net/forum/index.php/topic,4268.0.html , log in and download the appropriate Version of CC.

Place the contents of the "mods" folder into your /steam/.../Avorion/mods/ folder.

Open file `Avorion/mods/ShipScriptLoader/config/ShipScriptLoader.lua`
Before the last line containing `return Config` add this:
```LUA
Config.Add("mods/CarrierCommander/scripts/entity/CarrierCommander.lua")
```

If the icon does not show up:
Replace the Schipscriptloader-code in `data/scripts/server/server.lua` with:
```LUA
local s, b = pcall(require, 'mods/ShipScriptLoader/scripts/server/server')
if s then
    if b.onPlayerLogIn then
        local a = onPlayerLogIn
        onPlayerLogIn = function(c) a(c); b.onPlayerLogIn(c); end
    end
else
    print("failed to load ShipScriptLoader", b)
end
```
and check your Logs in %appdata%/avorion/... .

additionally place the contents of /data/ in /Avorion/data/
