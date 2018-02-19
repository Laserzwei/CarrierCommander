local Config = {}

Config.Author = "Nexus, Dirtyredz, Hammelpilaw, Maxx4u, Laserzwei, Cwhizard"
Config.ModName = "CarrierCommander"
Config.version = {
    major=0, minor=10, patch = 0,
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


Config.basePriorities = {
    ship = 20,
    guardian = 15,
    station = 10,
    fighter = 5,
}
Config.additionalPriorities = { --Only for modded additions. Modders: When creating a new Boss then use Entity():setValue("customBoss", someValidValue), to mark it. The Attack script will then activley search for those marked enemies and assign the priority set in the config

    --customBoss = 25
}

return Config
