

local dockAllCallbacks = {}
hidden.addCommand("dockAll", "Dock all Fighters", "data/scripts/entity/ccBasics/dockAllFighters", dockAllCallbacks)

local salvageCallbacks = {}
hidden.addCommand("salvage", "Salvage Command", "data/scripts/entity/ccBasics/salvageCommand", salvageCallbacks)

local mineCallbacks = {"onAsteroidCreated", "onSquadOrdersChanged", "onFighterAdded", "onJump", "onSectorEntered", "onSettingChanged"}
hidden.addCommand("mine", "Mine Command", "data/scripts/entity/ccBasics/mineCommand", mineCallbacks)

local attackCallbacks = {"onFlyableCreated", "onEntityEntered"}
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


-- onEntityEntered(shipIndex)

-- onSquadAdded(squadIndex)
-- onSquadRemove(squadIndex)
-- onSquadOrdersChanged(squadIndex, orders, targetId)

-- onFighterStarted(squadIndex, fighterId)
-- onFighterLanded(squadIndex, fighterId)
-- onFighterAdded(squadIndex, fighterIndex, landed)
-- onFighterRemove(squadIndex, fighterIndex, started)

-- onJump(shipIndex, x, y)
-- onSectorEntered(shipIndex, x, y)

-- onSettingChanged(setting, before, now)

-- Avoid putting Scripts in /data/scripts/entity/ai/...
