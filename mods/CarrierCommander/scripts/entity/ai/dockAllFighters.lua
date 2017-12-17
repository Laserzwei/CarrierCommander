package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")

--required Data
dockAll = {}
dockAll.prefix = nil
dockAll.active = false
dockAll.squads = {}                 --[1-12] = squadIndex           --squads to manage
dockAll.controlledFighters = {}     --[1-120] = fighterIndex        --List of all started fighters this command wants to controll/watch

--required UI
dockAll.needsButton = true
dockAll.inactiveButtonCaption = "Carrier - Dock All Fighters"
dockAll.activeButtonCaption = "Carrier - Docking"                 --Notice: the activeButtonCaption shows the caption WHILE the command is active
dockAll.activeTooltip = "Docking Fighters"
dockAll.inactiveTooltip = "Docker - Not doing anything."


function dockAll.dockAllFighters()
    local fighterController = FighterController(Entity().index)
    if not fighterController then
        print("Carrier - Salvage couldn't dock Fighters, Fightercontroller missing")
        return
    end

    for _,squad in pairs(dockAll.squads) do
        fighterController:setSquadOrders(squad, FighterOrders.Return, Entity().index)
    end
    for prefix,command in pairs(cc.commands) do
        if prefix ~= dockAll.prefix then    --docking command needs dockAll's squads
            command.squads = {}
        end
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
end

--<button> is clicked button-Object onClient and prefix onServer
function dockAll.activate(button)
    cc.commands[dockAll.prefix].active = false
    cc.numActiveCommands = cc.numActiveCommands - 1
    if onClient() then
        local pic = cc.commands[dockAll.prefix].statusPicture
        --pic.color = ColorRGB(0.3, 0.3, 0.3)
        pic.tooltip = cc.commands[dockAll.prefix].inactiveTooltip
        button.caption = cc.commands[dockAll.prefix].inactiveButtonCaption
        button.onPressedFunction = "buttonActivate"
        buttonDeactivate(cc.commands[dockAll.prefix].activationButton)
        return
    end
    -- space for stuff to do e.g. scanning all squads for suitable fighters/WeaponCategories etc.
end

--<button> is clicked button-Object onClient and prefix onServer
function dockAll.deactivate(button)
    cc.numActiveCommands = cc.numActiveCommands + 1
    if onClient() then
        for prefix,command in pairs(cc.commands) do
            if prefix ~= dockAll.prefix and command.active then
                if command.deactivate then buttonDeactivate(command.activationButton) end
            end
        end
        return
    end
    -- space for stuff to do e.g. landing your fighters
    -- When docking: Make sure to not reset template.squads
    local ai = ShipAI()
    ai:setIdle()

    dockAll.getSquadsToManage()
    dockAll.dockAllFighters()
    cc.applyCurrentAction(dockAll.prefix, FighterOrders.Return, Entity().name, dockAll.squads)
end

return dockAll
