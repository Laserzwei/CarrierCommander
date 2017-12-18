package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";mods/CarrierCommander/?.lua"

require ("stringutility")
require ("utility")
local sectorChange
cc = {}
cc.Config = require("config/CarrierCommanderConfig") --server settings, carrierScripts
cc.l = require("scripts/lib/lists") --contains selectableOrderNames, uiElementToSettingMap, actionTostringMap, tooltipadditions
cc.settings = {} --playersettings
cc.commands = {}
--loading modules
local pluginKeys = {}
for k in pairs(cc.Config.carrierScripts) do table.insert(pluginKeys, k) end
table.sort(pluginKeys)
for _,prefix in ipairs(pluginKeys) do
    if not cc.commands[prefix] then
        local path = cc.Config.carrierScripts[prefix].path .."?.lua"
        local name = cc.Config.carrierScripts[prefix].name
        package.path = package.path .. ";".. path
        cc.commands[prefix] = require (name)
        cc.commands[prefix].prefix = prefix
        --print("Loaded Fightermodule  ", prefix)
    else
        print("Prefix", prefix,"already used!")
    end
end
local sectorX, sectorY
--data
cc.thisCarrierStartedFighters = {}      -- [squadIndex] = {[1-n] = fitghterUuid}
cc.ownedStartedFighters = {}            -- [carrierIndex] = {[squadIndex] = {[1-n] = fitghterUuid}}
cc.numActiveCommands = 0
local isRegistered = false
cc.squadsDocking = {}

--UI
local numButtons = 0
cc.buttons = {}  --[buttonId] = commandPrefix
cc.pictures = {}  --[pictureId] = commandPrefix

for prefix,_ in pairs(cc.commands) do cc.l.tooltipadditions[prefix] = "" end

cc.uiInitialized = false

local waitTime, waited = 5, false     --super angry I have to use this
function initialize()
    if onServer() then
    --don't run carrier Commands on a drone!
    if Entity().isDrone then terminate()  return end

    end
    for prefix, command in pairs(cc.commands) do
        if command.init then command.init() end
    end
end

function registerSectorCallbacks()
    if isRegistered then return end
    local sector = Sector()
    sectorX, sectorY = sector:getCoordinates()
    --orders
    sector:registerCallback("onSquadOrdersChanged","squadOrdersChanged")
    --Fighter start and land
    sector:registerCallback("onFighterStarted","fighterStarted")
    sector:registerCallback("onFighterLanded","fighterLanded")
    -- Hangar management
    --fighters
    sector:registerCallback("onFighterAdded","fighterAdded")
    sector:registerCallback("onFighterRemove","fighterRemove")
    --squads
    Entity():registerCallback("onSquadAdded","squadAdded")
    Entity():registerCallback("onSquadRemove","squadRemove")

    isRegistered = true
end

function unregisterSectorCallbacks(x,y)
    if sectorX == nil or sectorY == nil or not isRegistered then return end
    if next(cc.squadsDocking) then return end   -- don't unregister when we still expect fighters to dock
    local sector = Sector(x,y)
    --orders
    --sector:unregisterCallback("onSquadOrdersChanged","squadOrdersChanged")    --needed for docking
    --Fighter start and land
    sector:unregisterCallback("onFighterStarted","fighterStarted")
    --sector:unregisterCallback("onFighterLanded","fighterLanded")              --needed for docking
    -- Hangar management
    --fighters
    sector:unregisterCallback("onFighterAdded","fighterAdded")
    sector:unregisterCallback("onFighterRemove","fighterRemove")
    --squads
    Entity():unregisterCallback("onSquadAdded","squadAdded")
    Entity():unregisterCallback("onSquadRemove","squadRemove")

    sector:unregisterCallback("onEntityCreate", "entityCreate")

    isRegistered = false
end

function getAllMyFighters()
    local carrier = Entity()
    local hangar = Hangar(carrier.index)
    if hangar then
        local owner = carrier.factionIndex
        for _, fighter in pairs({Sector():getEntitiesByFaction(owner)}) do
            if fighter.isFighter then
                local ai = FighterAI(fighter.index)
                if ai then
                    local carrierIndex = ai.mothershipId.string
                    local squad = ai.squad
                    if not carrierIndex then print("Invalid Carrier") end
                    cc.ownedStartedFighters[carrierIndex] = cc.ownedStartedFighters[carrierIndex] or {}
                    local squadList = cc.ownedStartedFighters[carrierIndex][squad] or {}
                    squadList[fighter.index.string] = 1
                    cc.ownedStartedFighters[carrierIndex][squad] = squadList
                    if carrierIndex == carrier.index.string then
                        cc.thisCarrierStartedFighters[squad] = squadList
                    end
                else
                    print("Fighter with no AI", fighter.index.string)
                end
            end
        end
    end
    getAllMyFightersCalled()    --telling every Module that fighters are now accessable
end

function getAllMyFightersCalled()
    Sector():registerCallback("onEntityCreate", "entityCreate") --post init, so we don't get every asteroid, when the sector is loaded
    for prefix, command in pairs(cc.commands) do
        if command.getAllMyFightersCalled then command.getAllMyFightersCalled() end
    end
end

function squadOrdersChanged(entityId, squadIndex, orders, targetId)
    if Entity().index.number == entityId.number then
        if cc.squadsDocking[squadIndex] and orders ~= FighterOrders.Return then
            local pref = getPrefOfSquad(squadIndex)
            docking(pref, squadIndex, true)
        elseif orders == FighterOrders.Return then
            local pref = getPrefOfSquad(squadIndex)
            docking(pref, squadIndex)
        end
        for prefix, command in pairs(cc.commands) do
            if command.squadOrdersChanged then command.squadOrdersChanged(entityId, squadIndex, orders, targetId) end
        end
    end
end

function fighterStarted(entityId, squadIndex, fighterId)
    if Entity(entityId).factionIndex == Entity().factionIndex then
        cc.ownedStartedFighters[entityId.string] = cc.ownedStartedFighters[entityId.string] or {}
        local squadList = cc.ownedStartedFighters[entityId.string][squadIndex] or {}
        squadList[fighterId.string] = 1
        cc.ownedStartedFighters[entityId.string][squadIndex] = squadList
        if Entity().index.number == entityId.number then
            cc.thisCarrierStartedFighters[squadIndex] = squadList

            for prefix, command in pairs(cc.commands) do
                if command.fighterStarted then command.fighterStarted(entityId, squadIndex, fighterId) end
            end
        end
    end
end

function fighterLanded(entityId, squadIndex, fighterId)
    if Entity(entityId).factionIndex == Entity().factionIndex then

        if cc.ownedStartedFighters[entityId.string]
        and cc.ownedStartedFighters[entityId.string][squadIndex]
        and cc.ownedStartedFighters[entityId.string][squadIndex][fighterId.string] then
            cc.ownedStartedFighters[entityId.string][squadIndex][fighterId.string] = nil
        end

        if Entity().index.number == entityId.number then
            if cc.thisCarrierStartedFighters[squadIndex]
            and cc.thisCarrierStartedFighters[squadIndex][fighterId.string] then
                cc.thisCarrierStartedFighters[squadIndex][fighterId.string] = nil
            end
            local pref = getPrefOfSquad(squadIndex)
            docking(pref, squadIndex)
            for prefix, command in pairs(cc.commands) do
                if command.fighterLanded then command.fighterLanded(entityId, squadIndex, fighterId) end
            end
        end
    end
end

function fighterAdded(entityId, squadIndex, fighterIndex, landed)
    if Entity().index.number == entityId.number then
        for prefix, command in pairs(cc.commands) do
            if command.fighterAdded then command.fighterAdded(entityId, squadIndex, fighterIndex, landed) end
        end
    end
end

function fighterRemove(entityId, squadIndex, fighterIndex, started) --entityTemplate is not accessable, even though it's supposed to be called BEFORE the fighter gets removed
    if Entity().index.number == entityId.number then
        for prefix, command in pairs(cc.commands) do
            if command.fighterRemove then command.fighterRemove(entityId, squadIndex, fighterIndex, started) end
        end
    end
end

function squadAdded(entityId, index)-- gets also called on squadRename
    if Entity().index.number == entityId.number then
        for prefix, command in pairs(cc.commands) do
            if command.squadAdded then command.squadAdded(entityId, index) end
        end
    end
end

function squadRemove(entityId, index)
    if Entity().index.number == entityId.number then
        for prefix, command in pairs(cc.commands) do
            if command.squadRemove then command.squadRemove(entityId, index) end
        end
    end
end

function onSectorChanged(x, y)
    for prefix, command in pairs(cc.commands) do
        if command.onSectorChanged then command.onSectorChanged(x, y) end
    end
end

function entityCreate(entityId)
    local entity = Entity(entityId)

    if entity.isFlyable then    -- Stations, Drone, Ship, Fighter
        --print("Flyable Created", entity.isStation, entity.isDrone, entity.isShip, entity.isFighter)
        for prefix, command in pairs(cc.commands) do
            if command.flyableCreated then command.flyableCreated(entity) end
        end
    elseif entity.isAsteroid then
        --print("Asteroid created", entity.typename)
        for prefix, command in pairs(cc.commands) do
            if command.asteroidCreated then command.asteroidCreated(entity) end
        end
    elseif entity.isWreckage then
        --print("Wreckage created", entity.typename)
        for prefix, command in pairs(cc.commands) do
            if command.wreckageCreated then command.wreckageCreated(entity) end
        end
    elseif entity.isLoot then
        --print("Loot created", entity.typename)
        for prefix, command in pairs(cc.commands) do
            if command.lootCreated then command.lootCreated(entity) end
        end
    else
        --print("* created", entity.typename, entity.isTurret, entity.isAnomaly, entity.isUnknown, entity.isOther, entity.isWormHole)
    end
end

function getIcon(seed, rarity)
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

function interactionPossible(playerIndex, option)
    local factionIndex = Entity().factionIndex
    if factionIndex == playerIndex or factionIndex == Player().allianceIndex then
        return true
    end
    return false
end

-- create all required UI elements for the client side
function initUI()
    local res = getResolution()
    local size = vec2(335, 180 + (tablelength(cc.commands)*35))

    local menu = ScriptUI()
    --local cc.window = menu:createcc.window(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5)) --Why is the 'local' part breaking the menu when tabs are used?
    cc.window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))

    cc.window.caption = "Fighter Orders"
    cc.window.showCloseButton = 1
    cc.window.moveable = 1
    --cc.window.icon = "data/textures/icons/fighter.png" --Sad, does not work =( I want to change it from the puzzle piece icon to something else

    menu:registerWindow(cc.window, "Carrier Orders")
    local tabbedWindow = cc.window:createTabbedWindow(Rect(vec2(10, 10), size - 10))
    local tab = tabbedWindow:createTab("Entity", "data/textures/icons/fighter.png", "Ship Commands")

    numButtons = 0
    local sortedPrefixes = {}
    for k in pairs(cc.Config.carrierScripts) do table.insert(sortedPrefixes, k) end
    table.sort(sortedPrefixes)
    for _,prefix in ipairs(sortedPrefixes) do
        local command = cc.commands[prefix]
        if command.needsButton then
            local button = tab:createButton(ButtonRect(), command.inactiveButtonCaption, "buttonActivate")
            button.textSize = 18
            button.maxTextSize = 18
            local pic = tab:createPicture(iconRect(), "data/textures/icons/fighter.png")
            pic.isIcon = true
            pic.tooltip = "Not doing anything."
            pic.color = ColorRGB(0.3, 0.3, 0.3)
            cc.buttons[button.index] = prefix
            command.activationButton = button
            command.statusPicture = pic
        end
    end

    cc.autoAssignButton = tab:createButton(ButtonRect(), "Carrier - Auto Assign", "autoAssign")
    cc.autoAssignButton.textSize = 18
    cc.autoAssignButton.maxTextSize = 18
    cc.autoAssignPicture = tab:createPicture(iconRect(), "data/textures/icons/fighter.png")
    cc.autoAssignPicture.isIcon = true
    cc.autoAssignPicture.tooltip = "Not doing anything."
    cc.autoAssignPicture.color = ColorRGB(0.3, 0.3, 0.3)
    "==========================================================================================="
    "==================================  CONFIG TAB ============================================"
    "==========================================================================================="
    local tab = tabbedWindow:createTab("Settings", "data/textures/icons/cog.png", "Settings")
    local pos = vec2(10,11)

    local scrollframe = tab:createScrollFrame(Rect(vec2(0,0), tab.size))
    scrollframe.scrollSpeed = 35
    --init config
    for _,prefix in ipairs(sortedPrefixes) do
        local command = cc.commands[prefix]
        if command.initConfigUI then
            local seperator = scrollframe:createLine(pos+vec2(-9,17), (pos+vec2(scrollframe.size.x-31,17)))
            seperator.color = ColorRGB(0.5, 0.5, 0.5)
            pos = pos + vec2(0,35)
            pos = command.initConfigUI(scrollframe, pos, scrollframe.size)
        end
    end

    -- hidden seperator
    scrollframe:createLabel(pos, "", 15)

    cc.uiInitialized = true
    requestSettingsFromServer()
end

function updateServer(timestep)
    if waitTime > 5 and not waited then
        waited = true
        getAllMyFighters()
    elseif not waited then
        waitTime = waitTime + timestep
    end
    for prefix, command in pairs(cc.commands) do
        if command.updateServer then command.updateServer(timestep) end
    end
end

function cc.addOrdersToCombo(comboBox)
    comboBox:clear()
    for i,v in pairs(cc.l.selectableOrderNames) do
        comboBox:addEntry(i,v)
    end
end

--request, delivery and application of settings for client
function requestSettingsFromServer()
    invokeServerFunction("sendSettingsToClient")
end

function sendSettingsToClient()
    local activeCommands = {}
    for prefix, command in pairs(cc.commands) do
        if command.active then
            activeCommands[prefix] = true
        end
    end
    if sectorChange then
        local x,y = Sector():getCoordinates()
        if x ~= sectorX or y ~= sectorY then
            unregisterSectorCallbacks(sectorX, sectorY)
            registerSectorCallbacks()
            getAllMyFighters()
            onSectorChanged(Sector():getCoordinates())
        else
            print("What the fuck does it want now?")
        end
    end
    broadcastInvokeClientFunction("receiveSettings", cc.settings, activeCommands, sectorChange)
    if not sectorChange then
        sectorChange = true
    end
end

function receiveSettings(pSettings, activeCommands, pSectorChange)
    if onClient() then
        cc.settings = pSettings
        client_applySettings()
        if pSectorChange then
            --onSectorChanged(Sector():getCoordinates())
        end
        for prefix,_ in pairs(activeCommands) do
            --activate UI
            buttonActivate(cc.commands[prefix].activationButton)
        end
    end
end

function getPrefOfSquad(squad)
    local prefixes = {}
    for pref,command in pairs(cc.commands) do
        if command.squads then
            if command.squads[squad] then
                prefixes[#prefixes+1] = pref
            end
        end
    end
    return unpack(prefixes)
end

function docking(prefix, squad, removeSquad)
    if not squad then print(Entity().name, "no squad", prefix, removeSquad) return end

    if removeSquad then
        cc.squadsDocking[squad] = nil
    else
        if not cc.squadsDocking[squad] and prefix then
            cc.squadsDocking[squad] = prefix
        end
    end

    local fightersByPrefix = {}
    for squad,pref in pairs(cc.squadsDocking) do    -- counting how many fighters are missing per squad
        local hangar = Hangar(Entity().index)
        fightersByPrefix[pref] = fightersByPrefix[pref] or {}
        local missingFighters = (12 -hangar:getSquadFreeSlots(squad)) -  hangar:getSquadFighters(squad)
        fightersByPrefix[pref].numSquads = fightersByPrefix[pref].numSquads
        if missingFighters > 0 then
            fightersByPrefix[pref].numFighters = missingFighters + (fightersByPrefix[pref].numFighters or 0)
            fightersByPrefix[pref].numSquads = (fightersByPrefix[pref].numSquads or 0) + 1
        else    -- discard squads where all fighters are docked
            cc.squadsDocking[squad] = nil
            cc.commands[pref].squads[squad] = nil
        end
    end

    if onServer() then
        broadcastInvokeClientFunction("docking", prefix, squad, removeSquad)
        return
    end

    for pre, d in pairs(fightersByPrefix) do
        local cmd = cc.commands[pre]

        if cc.uiInitialized and cmd.statusPicture then
            if d.numFighters and d.numFighters > 0 then
                cmd.statusPicture.tooltip = string.format(cc.l.actionTostringMap[FighterOrders.Return], d.numFighters, d.numSquads, Entity().name)
                if not cmd.active then cmd.statusPicture.color = cc.l.actionToColorMap[FighterOrders.Return] end
            else
                if not cmd.active then
                    cmd.statusPicture.color = cc.l.actionToColorMap[-1]
                    cmd.statusPicture.tooltip = cmd.inactiveTooltip
                else
                    if next(cmd.squads) then
                        cmd.statusPicture.color = list.actionToColorMap[FighterOrders.Attack]
                        cmd.statusPicture.tooltip = cmd.activeTooltip
                    else
                        cmd.statusPicture.color = cc.l.actionToColorMap["idle"]
                        cmd.statusPicture.tooltip = cc.l.actionTostringMap["idle"]
                    end
                end
            end
        end
    end
end

function client_applySettings()
    for uiElemIndex, key in pairs(cc.l.uiElementToSettingMap) do
        if valid(ValueComboBox(uiElemIndex)) then
            ValueComboBox(uiElemIndex):setSelectedValueNoCallback(cc.settings[key])
        end
        if valid(CheckBox(uiElemIndex)) then
            CheckBox(uiElemIndex):setCheckedNoCallback(cc.settings[key])
        end
        if valid(Slider(uiElemIndex)) then
             Slider(uiElemIndex):setValueNoCallback(cc.settings[key])
        end
    end
end
--change single setting value
function changeServerSettings(key, value)
    if onServer() then
        cc.settings[key] = value
    end
end

function applyCurrentAction(prefix, action, ...)
     cc.applyCurrentAction(prefix, action, ...)
 end
-- sets the icon and text for the specified prefix
function cc.applyCurrentAction(prefix, action, ...)
    local command = cc.commands[prefix]
    if not command then print(prefix,"is invalid command") return end
    if onServer() then
        broadcastInvokeClientFunction("applyCurrentAction", prefix, action, ...)
        return
    end
    if cc.uiInitialized and command.statusPicture then
        if action == FighterOrders.Return then
            -- handled by events
        else
            local args = {...}
            command.statusPicture.tooltip = string.format(cc.l.actionTostringMap[action], unpack(args))
            command.statusPicture.color = cc.l.actionToColorMap[action]

        end
    end
end

function buttonActivate(button)
    cc.numActiveCommands = cc.numActiveCommands + 1
    if onClient() then
        local prefix = cc.buttons[button.index]
        invokeServerFunction("buttonActivate", prefix)
        local pic = cc.commands[prefix].statusPicture
        pic.color = ColorRGB(0.1, 0.8, 0.1)
        pic.tooltip = cc.commands[prefix].activeTooltip
        button.caption = cc.commands[prefix].activeButtonCaption
        button.onPressedFunction = "buttonDeactivate"
        cc.commands[prefix].active = true
        cc.commands[prefix].activate(button)
        return
    end


    --print (Entity().name,"Carrier Command "..button.." Activated")
    cc.commands[button].active = true
    cc.commands[button].activate(button)
    if cc.numActiveCommands >= 1 then
        registerSectorCallbacks()
    end
end

function buttonDeactivate(button)
    cc.numActiveCommands = cc.numActiveCommands - 1
    if cc.numActiveCommands < 0 then cc.numActiveCommands = 0 end
    if onClient() then
        local prefix = cc.buttons[button.index]

        invokeServerFunction("buttonDeactivate", prefix)
        local pic = cc.commands[prefix].statusPicture
        pic.color = ColorRGB(0.3, 0.3, 0.3)
        pic.tooltip = cc.commands[prefix].inactiveTooltip
        button.caption = cc.commands[prefix].inactiveButtonCaption
        button.onPressedFunction = "buttonActivate"
        cc.commands[prefix].active = false
        cc.commands[prefix].deactivate(button)
        return
    end

    --print (Entity().name,"Carrier Command "..button.." Stopped")
    cc.commands[button].active = false
    cc.commands[button].deactivate(button)
    if cc.numActiveCommands == 0 then
        unregisterSectorCallbacks(Sector():getCoordinates())
    else

    end
end

function autoAssign()
    if onClient() then
        invokeServerFunction("autoAssign")
        cc.autoAssignPicture.color = ColorRGB(0.1, 0.8, 0.1)
        cc.setAutoAssignTooltip(true)
        cc.autoAssignButton.caption = "Carrier - Stop Assigning"
        cc.autoAssignButton.onPressedFunction = "StopAutoAssign"
        for prefix,command in pairs(cc.commands) do
            if prefix ~= "dockAll" then
                if command.activate then buttonActivate(command.activationButton) end
            end
        end
        return
    end
end

function StopAutoAssign()
    if onClient() then
        invokeServerFunction("StopAutoAssign")
        cc.autoAssignPicture.color = ColorRGB(0.3, 0.3, 0.3)
        cc.setAutoAssignTooltip(false)
        cc.autoAssignButton.caption = "Carrier - Auto Assign"
        cc.autoAssignButton.onPressedFunction = "autoAssign"
        for prefix,command in pairs(cc.commands) do
            if command.deactivate and prefix ~= "dockAll" then buttonDeactivate(command.activationButton) end
        end
        return
    end
end

function cc.setAutoAssignTooltip(active)
    if active then
        local text = "Managing your fighterfleet."
        for _,str in pairs(cc.l.tooltipadditions) do
            if str ~= "" then
                text = text.."\n"..str
            end
        end
        local numError = 0
        for prefix, command in pairs(cc.commands) do
            if command.active == false and prefix ~= "dockAll" then
                numError = numError + 1
            end
        end

        if numError >= 1 then
            cc.autoAssignPicture.color = ColorRGB(0.5, 0.5, 0.0)
        else
            cc.autoAssignPicture.color = ColorRGB(0.1, 0.8, 0.1)
        end
        if numError >= tablelength(cc.commands)-1 then
            cc.autoAssignPicture.color = ColorRGB(0.8, 0.1, 0.0)
        end
        cc.autoAssignPicture.tooltip = text
    else
        cc.autoAssignPicture.tooltip = "Not doing anything."
    end
end

--SETTINGS
function onCheckBoxChecked(checkbox)
    cc.settings[cc.l.uiElementToSettingMap[checkbox.index]] = checkbox.checked
    --print(Entity().name, "checkbox checked:", cc.l.uiElementToSettingMap[checkbox.index], checkbox.checked)
    invokeServerFunction("changeServerSettings", cc.l.uiElementToSettingMap[checkbox.index], checkbox.checked)
end

function onComboBoxSelected(comboBox)
    cc.settings[cc.l.uiElementToSettingMap[comboBox.index]] = comboBox.selectedValue
    --print(Entity().name,"comboBox Select", cc.l.uiElementToSettingMap[slider.index], comboBox.selectedValue, comboBox.selectedEntry)
    invokeServerFunction("changeServerSettings", cc.l.uiElementToSettingMap[comboBox.index], comboBox.selectedValue)
end

function onSliderValueChanged(slider)
    cc.settings[cc.l.uiElementToSettingMap[slider.index]] = slider.value
    --print(Entity().name, "Slider changed:", cc.l.uiElementToSettingMap[slider.index], slider.value)
    invokeServerFunction("changeServerSettings", cc.l.uiElementToSettingMap[slider.index], slider.value)
end

--Data securing
function restore(dataIn)    --might be called onSectorEntered
    cc.settings = dataIn.settings or {}
    local activeList = dataIn.activeList or {}
    for _,prefix in pairs(activeList) do
        if cc.commands[prefix] and not cc.commands[prefix].active then
            cc.commands[prefix].active = true
            --buttonActivate(prefix)
        end
    end
    for prefix, command in pairs(cc.commands) do
        if dataIn[prefix] then
            command.restoreList = dataIn[prefix]
        end
    end
end

function secure()
      local DataToReturn = {}
    DataToReturn.settings = cc.settings
    local activeList = {}
    for prefix, command in pairs(cc.commands) do
        if command.active == true then
            activeList[#activeList+1] = prefix
        end
        if command.secureList then
            DataToReturn[prefix] = command.secureList
        end
    end
    DataToReturn.activeList = activeList
      return DataToReturn
end
