
package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")
local docker = require ("mods.CarrierCommander.scripts.lib.dockingLib")

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace dockAll
dockAll = {}

--data
dockAll.prefix = "dockAll"
dockAll.squads = {}                 --[1-12] = squadIndex           --squads to manage
dockAll.controlledFighters = {}     --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch
dockAll.disabled = false

function dockAll.initialize()
    if onServer() then
        print("active")
        dockAll.getSquadsToManage()
        dockAll.dockAllFighters()
    end
end

function dockAll.getUpdateInterval()
    return 1
end

function dockAll.updateServer(timestep)
    local total, numSquads = docker.dockingFighters(dockAll.prefix, dockAll.squads)
    print("sel to dock", total, numSquads)
    if numSquads <= 0 then
        broadcastInvokeClientFunction("applyStatus", -1)
        terminate()
    else
        broadcastInvokeClientFunction("applyStatus", FighterOrders.Return, total, numSquads, Entity().name)
    end
end

function dockAll.dockAllFighters()
    local fighterController = FighterController(Entity().index)
    if not fighterController then
        print("Carrier - dockAll couldn't dock Fighters, Fightercontroller missing")
        return
    end
    local possibleCommands = _G["cc"].Config.carrierScripts
    for _,c in pairs(possibleCommands) do
        --Entity():removeScript(c.path..".lua")
    end
    for _,squad in pairs(dockAll.squads) do
        fighterController:setSquadOrders(squad, FighterOrders.Return, Entity().index)
    end
end

function dockAll.getSquadsToManage()
    local hangar = Hangar(Entity().index)
    if not hangar then return end
    local squads = {}
    for _, squad in pairs({hangar:getSquads()}) do
        squads[squad] = squad
    end
    dockAll.squads = squads
    --unclaim all squads from other scripts
    local commands = _G["cc"].commands
    for prefix,_ in pairs(commands) do
        _G["cc"].unclaimSquads(prefix, squads)
    end
    --claim squads for our own
    _G["cc"].claimSquads(dockAll.prefix, squads)
end

function dockAll.disable()
    print("disable called")
    broadcastInvokeClientFunction("disable")
    broadcastInvokeClientFunction("applyStatus", -1)
    terminate()
end

function dockAll.applyStatus(status, ...)
    if onClient() then
        print("apply", status, ...)
        if  _G["cc"].uiInitialized then
            local args = {...}

            local pic = _G["cc"].commands["dockAll"].statusPicture

            pic.color = _G["cc"].l.actionToColorMap[status]
            pic.tooltip = string.format(_G["cc"].l.actionTostringMap[status], unpack(args))
            if status == -1 then _G["cc"].commands[dockAll.prefix].activationButton.onPressedFunction = "buttonActivate" end
        end
    else
        print("why?")
    end
end
