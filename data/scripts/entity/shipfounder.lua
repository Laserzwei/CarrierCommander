package.path = package.path .. ";data/scripts/lib/?.lua"
require ("defaultscripts")
require ("stringutility")
require ("utility")
require ("callable")

local nameTextBox = nil

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)
    local self = Entity()
    local player = Player(playerIndex)

    if self.factionIndex ~= player.index then return false end

    local craft = player.craft
    if craft == nil then return false end

    if self.index == craft.index then
        return true
    end

    return false, "Fly the craft to found a ship."%_t
end

function getIcon()
    return "data/textures/icons/flying-flag.png"
end

-- create all required UI elements for the client side
function initUI()

    local res = getResolution()
    local size = vec2(350, 155)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    window.caption = "Found Ship (500 Iron)"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Found Ship"%_t);

    local hmsplit = UIHorizontalMultiSplitter(Rect(size), 10, 10, 3)

    local label = window:createLabel(hmsplit:partition(0).lower, "Enter the name of your new ship:"%_t, 14);
    label.size = vec2(size.x - 20, 40)
    label.centered = true
    label.wordBreak = true

    nameTextBox = window:createTextBox(hmsplit:partition(1), "")
    nameTextBox.maxCharacters = 35
    nameTextBox:forbidInvalidFilenameChars()

    allianceCheckBox = window:createCheckBox(hmsplit:partition(2), "Alliance Ship"%_t, "")
    allianceCheckBox.active = false
    allianceCheckBox.captionLeft = false

    -- button at the bottom
    local button = window:createButton(hmsplit:partition(3), "OK"%_t, "onFoundButtonPress");
    button.textSize = 14
end

function onFoundButtonPress()
    name = nameTextBox.text
    invokeServerFunction("found", name, allianceCheckBox.checked)
end


local function foundShip(faction, player, name)

    local settings = GameSettings()
    if settings.maximumPlayerShips > 0 and faction.numShips >= settings.maximumPlayerShips then
        player:sendChatMessage("Server"%_t, 1, "Maximum ship limit per faction (%s) of this server reached!"%_t, settings.maximumPlayerShips)
        return
    end

    if faction:ownsShip(name) then
        player:sendChatMessage("Server"%_t, 1, "You already have a ship called '%s'."%_t, name)
        return
    end

    local ok, msg, args = faction:canPay(0, 500)
    if not ok then
        player:sendChatMessage("Server"%_t, 1, msg, unpack(args))
        return
    end

    faction:pay("Paid %2% iron to found a ship."%_T, 0, 500)

    local self = Entity()

    local plan = BlockPlan()
    local material = Material()
    plan:addBlock(vec3(0, 0, 0), vec3(2, 2, 2), -1, -1, material.blockColor, material, Matrix(), BlockType.Hull)

    local ship = Sector():createShip(faction, name, plan, self.position);

    -- add base scripts
    AddDefaultShipScripts(ship)
    ship:addScriptOnce("insurance.lua")

    player.craft = ship

    return ship
end

function onShowWindow()

    if Alliance() then
        allianceCheckBox.active = true
    else
        allianceCheckBox.checked = false
        allianceCheckBox.active = false
    end
end

function found(name, forAlliance)

    if anynils(name, forAlliance) then return end

    if Faction().index ~= callingPlayer then return end
    local player = Player(callingPlayer)

    if forAlliance then
        local alliance = player.alliance

        if not alliance then
            player:sendChatMessage("Server"%_t, 1, "You're not in an alliance."%_t)
            return
        end

        if not alliance:hasPrivilege(callingPlayer, AlliancePrivilege.FoundShips) then
            player:sendChatMessage("Server"%_t, 1, "You don't have permissions to found ships for your alliance."%_t)
            return
        end

        local ship = foundShip(alliance, player, name)

        if ship then
            ship:addScriptOnce("entity/claimalliance.lua")
        end
    else
        foundShip(player, player, name)
    end

end
callable(nil, "found")
