local Config = {}

Config.Author = "Nexus, Dirtyredz, Hammelpilaw, Maxx4u, Laserzwei"
Config.ModName = "CarrierCommander"
Config.version = {
    major=0, minor=9, patch = 0,
    string = function()
        return  Config.version.major .. '.' ..
                Config.version.minor .. '.' ..
                Config.version.patch
    end
}

--new commands go here, <unique prefix> = {name = <filneme without .lua>, <path> = relative path from the /mods/-folder }
Config.carrierScripts = {
    salvage = {name="salvageCommand", path = "mods/CarrierCommander/scripts/entity/ai/"},
    mine = {name="mineCommand", path = "mods/CarrierCommander/scripts/entity/ai/"},
    attack = {name="aggressiveCommand", path = "mods/CarrierCommander/scripts/entity/ai/"},
    dockAll = {name="dockAllFighters", path = "mods/CarrierCommander/scripts/entity/ai/"},
    --dummyCommand = {name="dummyCommand", path = "mods/dummyCarrierCommands/scripts/entity/ai/"}
}


Config.Settings = {}

Config.Settings.Aggressive = {
    attackStations = true,        -- Defines if stations should be attacked. Possible values: true, false; Default: true
    attackFighters = true,        -- Defines if fighters should be attacked. Possible values: true, false; Default: true

    priorities = {
        ship = 20,
        guardian = 15,
        station = 10,
        fighter = 5,
    }
}

return Config
