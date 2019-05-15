
local commands = {}
local hidden = {}
-- The namespaceName has to be unique and the actual name of the commands' namespace
function hidden.addCommand(namespaceName, name, path)
    commands[namespaceName] = {name = name, path = path}
end

return commands
