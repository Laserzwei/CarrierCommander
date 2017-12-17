package.path = package.path .. ";data/scripts/lib/?.lua"
require ("faction")
require ("utility")
template = {}

--required Data
template = {}
template.prefix = nil
template.active = false
template.squads = {}                  --[squadIndex] = squadIndex       --squads to manage
template.controlledFighters = {}      --[1-120] = fighterIndex          --List of all started fighters this template wants to controll/watch
--data

--required UI
template.needsButton = true
template.inactiveButtonCaption = "Carrier - Start template"
template.activeButtonCaption = "Carrier - Stop template"                 --Notice: the activeButtonCaption shows the caption WHILE the template is active
template.activeTooltip = "templating around"
template.inactiveTooltip = "not templating"


--called when CarrierCommander initialize() gets called (client and Serversided)
function template.init()

end

--All Events are Serversided!

--[[scrollframe is the UIElement you add to, pos is your current starting position, size is the size of scrollframe
    here you can add all your configoptions.
    Use cc.l.uiElementToSettingMap[yourUIElement.index] = template.prefix.."someSettingName" to save and
    cc.settings[template.prefix.."someSettingName"] to get your setting
    Available by default:
    local yourUIElement = scrollframe:createValueComboBox(Rect(pos,pos+vec2(200,25)), "onComboBoxSelected")
    local yourUIElement = scrollframe:createCheckBox(Rect(pos,pos+vec2(size.x-35, 25)), "Some description", "onCheckBoxChecked")
    local yourUIElement = scrollframe:createSlider(Rect(pos,pos+vec2(size.x-35, 25)), 0, 1.0, 100, "Caption", "onSliderValueChanged")
]]
function template.initConfigUI(scrollframe, pos, size)

end

-- updateServer() from Vanilla, gets called from CarrierCommand every gametick, dont set
function template.updateServer(timestep)
    if template.active then

    end
end

-- called after all Fighter in the sector are scanned and sorted into cc.thisCarrierStartedFighters/cc.ownedStartedFighters
-- gets called BEFORE onSectorChanged() is fired
function template.getAllMyFightersCalled()
    if template.active then

    end
end

-- squad order changed
function template.squadOrdersChanged(entityId, squadIndex, orders, targetId)
    if template.active then

    end
end

--fighter starts from hangar
function template.fighterStarted(entityId, squadIndex, fighterId)
    if template.active then

    end
end

--fighter lands in hangar
function template.fighterLanded(entityId, squadIndex, fighterId)
    if template.active then

    end
end

--fighter joins hangar (landed/bought/changed squad/moved from other ship)
function template.fighterAdded(entityId, squadIndex, fighterIndex, landed)
    if template.active then

    end
end

--fighter leaves hangar(started/changed squad/moved to other ship/destroyed)
function template.fighterRemove(entityId, squadIndex, fighterIndex, started) --entityTemplate is not accessable, even though it's supposed to be called BEFORE the fighter gets removed
    if template.active then

    end
end

--squad created/renamed
function template.squadAdded(entityId, index)-- gets also called on squadRename
    if template.active then

    end
end

--squad deleted
function template.squadRemove(entityId, index)
    if template.active then

    end
end

--entered sector's x and y
function template.onSectorChanged(x, y)
    if template.active then

    end
end

--Ships, Stations, Fighters, playerDrones
function template.flyableCreated(entity)
    if template.active then

    end
end

function template.asteroidCreated(entity)
    if template.active then

    end
end

function template.wreckageCreated(entity)
    if template.active then

    end
end
-- loot includes Modules, Turrets and Resource drops
function template.lootCreated(entity)
    if template.active then

    end
end

--<button> is clicked button-Object onClient and prefix onServer
function template.activate(button)
    if onClient() then
        cc.l.tooltipadditions[template.prefix] = "+ templating around"
        cc.setAutoAssignTooltip(cc.autoAssignButton.onPressedFunction == "StopAutoAssign")

        return
    end
    -- space for stuff to do e.g. scanning all squads for suitable fighters/WeaponCategories etc.
    template.squads = {}
end

--<button> is clicked button-Object onClient and prefix onServer
function template.deactivate(button)
    if onClient() then
        cc.l.tooltipadditions[template.prefix] = "- Stopped template Command"
        cc.setAutoAssignTooltip(cc.autoAssignButton.onPressedFunction == "StopAutoAssign")
        return
    end
    -- space for stuff to do e.g. landing your fighters/emptying: template.squads = {} / template.startedFighters = {}
    -- When docking: Make sure to not reset template.squads
end

--[[other usefulnes:
- Customizing the statusIcon.
Note: The Icon will only show docking, if template.squads still has the squads, that it ordered to dock
Put in template.init():
cc.l.actionTostringMap["customAction"] = "Templating %i ship, \nthe %s!"     --Uses lua string.format(), any string possible
cc.l.actionToColorMap["customAction"] = ColorRGB(0.1, 0.1, 1)     --strong blue

Then when your custum action happens(on a Ship named "TemplateShip") call:
cc.applyCurrentAction(template.prefix, "customAction", 1, Entity().name)
Your Icon will be lit in blue with the tooltip:
"Templating 1 ship,
 the TemplateShip!"
Some default actions and colors are stored in /scripts/lib/lists.lua

- Modifiying the Assign-All tooltip:
cc.l.tooltipadditions[template.prefix] = "+ templating around"
cc.setAutoAssignTooltip(cc.autoAssignButton.onPressedFunction == "StopAutoAssign")

Get Number of Fighters in Squad "squad", excludingstarted fighters:
local numFighters = hangar:getSquadFighters(squad)

Get Number of Fighters in Squad "squad", regardless if started or in hangar:
local numFighters = 12 - hangar:getSquadFreeSlots(squad)

Get number of Fighters in Squad "squad" that are started:
local numFighters = (12 - hangar:getSquadFreeSlots(squad)) - hangar:getSquadFighters(squad)

Activate dummyCommand in /mods/CarrierCommander/config/CarrierCommanderConfig.lua to see all the events printed to the console, as well as cyclic docking and undocking
