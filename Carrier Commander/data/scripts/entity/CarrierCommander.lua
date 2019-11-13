package.path = package.path .. ";data/scripts/lib/?.lua"

include ("stringutility")
include ("utility")
include ("callable")
include ("faction")

local printer = include ("data/scripts/lib/printlib")
local aprinter = printer("[CC-Core] ", "Error")
local print = function (...) return aprinter:print(...) end
local printlog = function (...) return aprinter:printlog(...) end

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace cc
cc = {}

function cc.createCallbackList(commands)
    local list = {}
    for namespace, command in pairs(commands) do
        for _,callback in pairs(command.callbacks or {}) do
            if list[callback] then
                table.insert(list[callback], namespace)
            else
                list[callback] = {namespace}
            end
        end
    end
    return list
end

--data
cc.Config = include("data/config/CarrierCommanderConfig") -- server settings
cc.l = include("data/scripts/lib/lists") -- contains selectableOrderNames, uiElementToSettingMap, actionTostringMap, tooltipadditions
cc.commands = include("data/scripts/entity/commandHook") -- All commands register here
cc.callbackList = cc.createCallbackList(cc.commands) -- [callback] = {[num] = namespace}

cc.settings = {} --playersettings
cc.claimedSquads = {}   -- <SquadIndex> = "scriptnamespace"

-- Interaction permissions
cc.interactionpermissions = {AlliancePrivilege.ManageShips, AlliancePrivilege.FlyCrafts, AlliancePrivilege.ModifyCrafts}

--UI
local numButtons = 0
cc.buttons = {}  --[buttonId] = commandPrefix
cc.pictures = {}  --[pictureId] = commandPrefix
local sortedPrefixes = {}

--UI config_tab
cc.configPos = 0
cc.configSize = 0

cc.uiInitialized = false

function cc.initialize()
    if onServer() then
        --don't run carrier Commands on a drone!
        if Entity().isDrone then terminate()  return end
    end
end

function cc.initializationFinished()
    if onClient() then
        printlog("Info", "request settings")
        cc.requestSettingsFromServer()
    else
        cc.registerCallbackss()
    end
end

function cc.registerCallbackss()

    cc.registerSectorCallbacks(Sector():getCoordinates())
    --squads
    local entity = Entity()
    entity:registerCallback("onSquadAdded","onSquadAdded")
    entity:registerCallback("onSquadRemove","onSquadRemove")
    entity:registerCallback("onSquadOrdersChanged","onSquadOrdersChanged")

    entity:registerCallback("onFighterStarted","onFighterStarted")
    entity:registerCallback("onFighterLanded","onFighterLanded")
    entity:registerCallback("onFighterAdded","onFighterAdded")
    entity:registerCallback("onFighterRemove","onFighterRemove")
    -- sector change
    entity:registerCallback("onJump", "onJump")
    entity:registerCallback("onSectorEntered", "onSectorEntered")
end

function cc.registerSectorCallbacks(x, y)
    local sector = Sector()

    sector:registerCallback("onEntityCreate", "onEntityCreate")
    sector:registerCallback("onEntityEntered", "onEntityEntered")
end

function cc.unregisterSectorCallbacks(x,y)
    local sector = Sector()

    --sector:unregisterCallback("onEntityCreate", "onEntityCreate")
    --sector:unregisterCallback("onEntityEntered", "onEntityEntered")
end

function cc.eventCall(event, ...)
    if not cc.callbackList[event] then return end   -- a.k.a. : No command registered that callback
    for i, namespace in ipairs(cc.callbackList[event]) do
        printlog(Info", ""Event", namespace,  _G[namespace] ~= nil, event, ...)
        if _G[namespace] then   -- namespace is only available when the command is active
            --if _G[namespace][event] then    -- It's simply assumed that the modauthors, who added the event-callbackhook also implmented it
                _G[namespace][event](...)
            --end
        end
    end
end

function cc.onEntityCreate(entityId)
    local entity = Entity(entityId)
    if entity.isFlyable then    -- Stations, Drone, Ship, Fighter
        printlog("Info", Entity().name, "Flyable Created", entity.isStation, entity.isDrone, entity.isShip, entity.isFighter)
        cc.eventCall("onFlyableCreated", entity)
    elseif entity.isAsteroid then
        printlog("Info", Entity().name, "Asteroid created", entity.typename)
        cc.eventCall("onAsteroidCreated", entity)
    elseif entity.isWreckage then
        printlog("Info", Entity().name, "Wreckage created", entity.typename)
        cc.eventCall("onWreckageCreated", entity)
    elseif entity.isLoot then
        printlog("Info", Entity().name, "Loot created", entity.typename)
        cc.eventCall("onLootCreated", entity)
    else
        printlog("Info", Entity().name, "* created", entity.typename, entity.isTurret, entity.isAnomaly, entity.isUnknown, entity.isOther, entity.isWormHole)
        --cc.eventCall("otherCreated", entity)
    end
end

function cc.onEntityEntered(shipIndex)
    printlog("Info", Entity().name, "Entity Entered: ", Entity(shipIndex).name)
    cc.eventCall("onEntityEntered", shipIndex)
end

function cc.onSquadAdded(entityId, squadIndex)-- gets also called on squadRename
    printlog("Info", Entity().name, "Squad Changed, added or renamed", squadIndex)
    cc.eventCall("onSquadAdded", squadIndex)
end

function cc.onSquadRemove(entityId, squadIndex)
    printlog("Info", Entity().name, "Squad Changed, remove", squadIndex)
    cc.eventCall("onSquadRemove", squadIndex)
end

function cc.onSquadOrdersChanged(entityId, squadIndex, orders, targetId)
    printlog("Info", Entity().name, "Squad Order changed", squadIndex, orders, targetId, valid(Entity(targetId)) and Entity(targetId).name or "-E")
    cc.eventCall("onSquadOrdersChanged", squadIndex, orders, targetId)
end

function cc.onFighterStarted(entityId, squadIndex, fighterId)
    printlog("Info", Entity().name, Entity(entityId).name, "[AI] fighter started squad", squadIndex)
    cc.eventCall("onFighterStarted", squadIndex, fighterId)
end

function cc.onFighterLanded(entityId, squadIndex, fighterId)
    printlog("Info", Entity().name, "fighter landed squad", squadIndex, Entity(fighterId).name)
    cc.eventCall("onFighterLanded", squadIndex, fighterId)
end

function cc.onFighterAdded(entityId, squadIndex, fighterIndex, landed)
    printlog("Info", Entity().name, "fighter added to squad", squadIndex, fighterIndex, landed)
    cc.eventCall("onFighterAdded", squadIndex, fighterIndex, landed)
end

function cc.onFighterRemove(entityId, squadIndex, fighterIndex, started) --entityTemplate is not accessable, even though it's supposed to be called BEFORE the fighter gets removed
    printlog("Info", Entity().name, "fighter removed from squad", squadIndex, fighterIndex, started)
    cc.eventCall("onFighterRemove", squadIndex, fighterIndex, started)
end

--gets called before sector change
function cc.onJump(shipIndex, x, y)
    printlog("Info", Entity().name, "on Jump", x, y)
    cc.unregisterSectorCallbacks(Sector():getCoordinates())
    cc.eventCall("onJump", shipIndex, x, y)
end
--gets called after sector change
function cc.onSectorEntered(shipIndex, x, y)
    printlog("Info", Entity().name, "on Sector entered", x, y)
    cc.registerSectorCallbacks(Sector():getCoordinates())
    cc.eventCall("onSectorEntered", shipIndex, x, y)
end

function cc.onSettingChanged(setting, before, now)
    printlog("Info", Entity().name, setting, before, now)
    cc.eventCall("onSettingChanged", setting, before, now)
end

function cc.getIcon(seed, rarity)
    return "data/textures/icons/fighter.png"
end

function ButtonRect(w, h)
    local width = w or 280
    local height = h or 35

    local space = math.floor((cc.window.size.y - 80) / (height + 10))
    local row = math.floor(numButtons % space)
    local col = math.floor(numButtons / space)

    local lower = vec2((width + 10) * col, (height + 10) * row)
    local upper = lower + vec2(width, height)

    numButtons = numButtons + 1
    return Rect(lower, upper)
end

function iconRect(r)
    local row = r or (numButtons-1)
    local y = (35 + 10) * row + 4
    local lower = vec2(280, y) + vec2(10,0)
    local upper = lower + vec2(24,24)
    return Rect(lower, upper)
end

function cc.interactionPossible(playerIndex, option)
    local ship = Entity()
    if not Entity().isDrone and checkEntityInteractionPermissions(ship, unpack(cc.interactionpermissions)) then
        return true
    end
    return false
end

-- create all required UI elements for the client side
function cc.initUI()
    local res = getResolution()
    local size = vec2(335, 140 + (tablelength(cc.commands)*35))

    local menu = ScriptUI()
    cc.window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    cc.window.caption = "Carrier Orders"%_t
    cc.window.showCloseButton = 1
    cc.window.moveable = 1

    menu:registerWindow(cc.window, "Carrier Orders"%_t)
    local tabbedWindow = cc.window:createTabbedWindow(Rect(vec2(10, 10), size - 10))
    local tab = tabbedWindow:createTab("Entity", "data/textures/icons/fighter.png", "Commands"%_t)

    numButtons = 0

    for k in pairs(cc.commands) do table.insert(sortedPrefixes, k) end
    table.sort(sortedPrefixes)
    for _,prefix in ipairs(sortedPrefixes) do
        local command = cc.commands[prefix]
        local button = tab:createButton(ButtonRect(), command.name..(" [A]"), "buttonActivate")
        button.textSize = 18
        button.maxTextSize = 18
        local pic = tab:createPicture(iconRect(), "data/textures/icons/fighter.png")
        pic.isIcon = true
        pic.tooltip = cc.l.actionTostringMap[-1]
        pic.color = cc.l.actionToColorMap[-1]
        command.statusPicture = pic
        command.activationButton = button
        cc.buttons[button.index] = prefix
    end

    --"==========================================================================================="
    --"==================================  CONFIG TAB ============================================"
    --"==========================================================================================="
    local tab = tabbedWindow:createTab("Settings", "data/textures/icons/cog.png", "Settings"%_t)
    local pos = vec2(10,11)

    local scrollframe = tab:createScrollFrame(Rect(vec2(0,0), tab.size))
    scrollframe.scrollSpeed = 35
    --init config
    for _,prefix in ipairs(sortedPrefixes) do
        local c = include(cc.commands[prefix].path.."_config")
        if c.initConfigUI then
            local seperator = scrollframe:createLine(pos+vec2(-9,17), (pos+vec2(scrollframe.size.x-31,17)))
            seperator.color = ColorRGB(0.5, 0.5, 0.5)
            pos = pos + vec2(0,35)
            pos = c.initConfigUI(scrollframe, pos, scrollframe.size)
        end
    end

    -- hidden seperator
    scrollframe:createLabel(pos, "", 15)

    cc.uiInitialized = true
    cc.requestSettingsFromServer()
end

function cc.onShowWindow()
    for prefix, command in pairs(cc.commands) do
        local commandScript = _G[prefix]
        if commandScript then
            local pic = command.statusPicture
            pic.color = cc.l.actionToColorMap[commandScript.state]
            pic.tooltip = commandScript.createStatusMessage()
        end
    end
end

function cc.addOrdersToCombo(comboBox)
    comboBox:clear()
    for i,v in pairs(cc.l.selectableOrderNames) do
        comboBox:addEntry(i,v)
    end
end

--request, delivery and application of settings for client
function cc.requestSettingsFromServer()
    invokeServerFunction("sendSettingsToClient")
end

function cc.sendSettingsToClient()
    if cc.Config.forceUnsupervisedTargeting then
        cc.settings["vanillaAttackPattern"] = true
    end
    invokeClientFunction(Player(callingPlayer), "receiveSettings", cc.settings)
end
callable(cc, "sendSettingsToClient")

--change single setting value
function cc.changeServerSettings(setting, value)
    if onServer() then
        local oldvalue = cc.settings[setting]
        cc.settings[setting] = value
        cc.onSettingChanged(setting, oldvalue, value)
    end
end
callable(cc, "changeServerSettings")

function cc.receiveSettings(pSettings)
    if onClient() then
        cc.settings = pSettings
        if cc.uiInitialized then
            cc.client_applySettings()
            cc.updateButtons()
        end
    end
end

function cc.client_applySettings()
    for uiElemIndex, setting in pairs(cc.l.uiElementToSettingMap) do
        if valid(ValueComboBox(uiElemIndex)) then
            ValueComboBox(uiElemIndex):setSelectedValueNoCallback(cc.settings[setting.name] or setting.default)
        end
        if valid(CheckBox(uiElemIndex)) then
            CheckBox(uiElemIndex):setCheckedNoCallback(cc.settings[setting.name] or setting.default)
        end
        if valid(Slider(uiElemIndex)) then
            Slider(uiElemIndex):setValueNoCallback(cc.settings[setting.name] or setting.default)
        end
    end
end

function cc.updateButtons()
    for _, command in pairs(cc.commands) do
        if Entity():hasScript(command.path) then
            command.activationButton.caption = command.name.." [D]"
            command.activationButton.onPressedFunction = "buttonDeactivate"
        end
    end
end

-- checks for every requested Squad, if it has been claimed by another script
-- and returns all squads claimed by the requesting script
function cc.claimSquads(prefix, squads)
    squads = squads or {}
    for _,squad in pairs(squads) do
        if not cc.claimedSquads[squad] then
            cc.claimedSquads[squad] = prefix
        end
    end
    return cc.getClaimedSquads(prefix)
end

function cc.getClaimedSquads(prefix)
    local claimedSquads = {}
    for squad, pref in pairs(cc.claimedSquads) do
        if pref == prefix then
            claimedSquads[squad] = squad
        end
    end
    return claimedSquads
end

function cc.unclaimSquads(prefix, squads)
    for _,squad in pairs(squads) do
        if cc.claimedSquads[squad] == prefix then
            cc.claimedSquads[squad] = nil
            if _G[prefix] then _G[prefix].squads[squad] = nil end
        end
    end
end

if onClient() then
function cc.changeIndicator(prefix, text, color)
    if cc.uiInitialized then
        local pic = cc.commands[prefix].statusPicture
        pic.color = color
        pic.tooltip = text
    end
end
end

-- Gets called from a command to reset the statusPicture after it terminated.
function cc.clearIndicator(prefix)
    if onServer() then
        broadcastInvokeClientFunction("clearIndicator", prefix)
        return
    end
    -- Client
    if cc.uiInitialized then
        local pic = cc.commands[prefix].statusPicture
        pic.color = cc.l.actionToColorMap[-1]
        pic.tooltip = cc.l.actionTostringMap[-1]
        local button = cc.commands[prefix].activationButton
        button.caption = cc.commands[prefix].name.." [A]"
        button.onPressedFunction = "buttonActivate"
    end
end

function cc.buttonActivate(button)
    if onClient() then
        local prefix = cc.buttons[button.index]
        invokeServerFunction("buttonActivate", prefix)
        button.caption = cc.commands[prefix].name.." [D]"
        button.onPressedFunction = "buttonDeactivate"
    else
        Entity():addScriptOnce(cc.commands[button].path)
        Entity():invokeFunction(cc.commands[button].path..".lua", "initializationFinished")
    end
end
callable(cc, "buttonActivate")

function cc.buttonDeactivate(button)
    if onClient() then
        local prefix = cc.buttons[button.index]

        invokeServerFunction("buttonDeactivate", prefix)
        local pic = cc.commands[prefix].statusPicture
        pic.color = cc.l.actionToColorMap[-1]
        pic.tooltip = cc.l.actionTostringMap[-1]
        button.caption = cc.commands[prefix].name.." [A]"
        button.onPressedFunction = "buttonActivate"
    else
        local command = _G[button]
        if command then
            print("send disable", cc.commands[button].path..".lua")
            command.disable()
        end
    end
end
callable(cc, "buttonDeactivate")

--SETTINGS
function cc.onCheckBoxChecked(checkbox)
    cc.settings[cc.l.uiElementToSettingMap[checkbox.index].name] = checkbox.checked
    printlog("Info", Entity().name, "checkbox checked:", cc.l.uiElementToSettingMap[checkbox.index], checkbox.checked)
    invokeServerFunction("changeServerSettings", cc.l.uiElementToSettingMap[checkbox.index].name, checkbox.checked)
end

function cc.onComboBoxSelected(comboBox)
    cc.settings[cc.l.uiElementToSettingMap[comboBox.index].name] = comboBox.selectedValue
    printlog("Info", Entity().name,"comboBox Select", cc.l.uiElementToSettingMap[slider.index], comboBox.selectedValue, comboBox.selectedEntry)
    invokeServerFunction("changeServerSettings", cc.l.uiElementToSettingMap[comboBox.index].name, comboBox.selectedValue)
end

function cc.onSliderValueChanged(slider)
    cc.settings[cc.l.uiElementToSettingMap[slider.index].name] = slider.value
    printlog("Info", Entity().name, "Slider changed:", cc.l.uiElementToSettingMap[slider.index], slider.value)
    invokeServerFunction("changeServerSettings", cc.l.uiElementToSettingMap[slider.index].name, slider.value)
end

--Data securing
function cc.restore(dataIn)    --might be called onSectorEntered
    cc.settings = dataIn.settings or {}
    cc.claimedSquads = dataIn.claimedSquads or cc.claimedSquads
end

function cc.secure()
    local data = {}
    data.settings = cc.settings
    data.claimedSquads = cc.claimedSquads
    return data
end
