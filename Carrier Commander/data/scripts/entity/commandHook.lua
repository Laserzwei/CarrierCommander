-- Available Callbacks --

----   onEntityCreate    ----
-- onFlyableCreated(entity)
-- onAsteroidCreated(entity)
-- onWreckageCreated(entity)
-- onLootCreated(entity)
-- onOtherCreated(entity) <<< not implemented

-- onSettingChanged(setting, before, now)

-- Avoid putting Scripts in /entity/ai/...

local commands = {}
local hidden = {}
-- The namespaceName has to be unique and the actual name of the commands' namespace
function hidden.addCommand(namespaceName, name, path)
    commands[namespaceName] = {name = name, path = path}
end

return commands
