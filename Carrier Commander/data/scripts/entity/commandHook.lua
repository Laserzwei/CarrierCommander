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

-- Avoid putting Scripts in /entity/ai/...

local commands = {}
local hidden = {}
-- The namespaceName has to be unique and the actual name of the commands' namespace
function hidden.addCommand(namespaceName, name, path, callbacks)
    commands[namespaceName] = {name = name, path = path, callbacks = callbacks}
end

return commands
