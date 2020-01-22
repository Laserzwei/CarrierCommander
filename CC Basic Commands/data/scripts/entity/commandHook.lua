

local dockAllCallbacks = {}
hidden.addCommand("dockAll", "Dock all Fighters", "data/scripts/entity/ccBasics/dockAllFighters", dockAllCallbacks)

local salvageCallbacks = {"onWreckageCreated", "onSquadOrdersChanged", "onFighterAdded", "onJump", "onSectorEntered", "onSettingChanged"}
hidden.addCommand("salvage", "Salvage Command", "data/scripts/entity/ccBasics/salvageCommand", salvageCallbacks)

local mineCallbacks = {"onAsteroidCreated", "onSquadOrdersChanged", "onFighterAdded", "onJump", "onSectorEntered", "onSettingChanged"}
hidden.addCommand("mine", "Mine Command", "data/scripts/entity/ccBasics/mineCommand", mineCallbacks)

local attackCallbacks = {"onFlyableCreated", "onEntityEntered", "onSquadOrdersChanged", "onFighterAdded", "onJump", "onSectorEntered", "onSettingChanged"}
hidden.addCommand("attack", "Attack Command", "data/scripts/entity/ccBasics/attackCommand", attackCallbacks)

local repairCallbacks = {}
hidden.addCommand("repair", "Repair Command", "data/scripts/entity/ccBasics/repairCommand", repairCallbacks)




-- hidden.addCommand(namespaceName, name, path, callbacks) -- The namespaceName has to be unique and the actual name of the commands' namespace

-- Available Callbacks --

----   onEntityCreate    ----
-- onFlyableCreated(entity)
-- onAsteroidCreated(entity)
-- onWreckageCreated(entity)
-- onLootCreated(entity)
-- onOtherCreated(entity) <<< not implemented

-- onSettingChanged(setting, before, now)

-- Avoid putting Scripts in /data/scripts/entity/ai/...
