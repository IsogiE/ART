local GlobalAddonName, ART = ...
local ELib, L = ART.lib, ART.L
local AceComm = LibStub:GetLibrary("AceComm-3.0")

-- Create the module for AddonChecker
local module = ART:New("AddonChecker", "Addon Checker")

-- Predefined list of addons to check (X-axis)
local addonList = {
    "NorthernSkyMedia",          -- Folder name for Northern Sky Media
    "SharedMedia_Causese",       -- Folder name for SharedMedia Causese
    "LibOpenRaid",               -- Folder name for LibOpenRaid
}

-- Store players and addon check results
local playerList = {}
local playerAddonStatus = {}

-- Function to strip realm names from player names
local function StripRealmName(playerName)
    return playerName:match("([^%-]+)") or playerName
end

-- Function to check if addons are loaded using the new API
local function CheckAddons()
    local missingAddons = {}

    for _, addonName in ipairs(addonList) do
        local loadedOrLoading, loaded = C_AddOns.IsAddOnLoaded(addonName)
        if not loadedOrLoading and not loaded then
            table.insert(missingAddons, addonName)
        end
    end

    return missingAddons
end

-- Broadcast request to check addons
local function BroadcastAddonCheckRequest(channel)
    local message = "CHECK_ADDONS"
    
    -- Check the person pressing the button (self-check) before sending the message
    local missingAddons = CheckAddons()
    playerAddonStatus[UnitName("player")] = missingAddons

    if channel == "RAID" then
        AceComm:SendCommMessage("ART_AddonChecker", message, "RAID")
    end

    -- After sending the check request, update the table
    module.options:UpdateTable(false) -- Don't show icons until response is received
end

-- Handle incoming messages
local function OnCommReceived(prefix, message, distribution, sender)
    if prefix == "ART_AddonChecker" then
        if message == "CHECK_ADDONS" then
            -- Delay the addon check response slightly to avoid conflicts
            C_Timer.After(1, function()
                local missingAddons = CheckAddons()
                local responseMessage = table.concat(missingAddons, ",") or "none"
                AceComm:SendCommMessage("ART_AddonChecker", "ADDON_RESPONSE:" .. responseMessage, "WHISPER", sender)
            end)

        elseif message:find("^ADDON_RESPONSE:") then
            local response = message:sub(16)  -- Extract the missing addons
            local missingAddons = {}

            if response ~= "none" then
                for addon in string.gmatch(response, "([^,]+)") do
                    table.insert(missingAddons, addon)
                end
            end

            playerAddonStatus[sender] = missingAddons  -- Store result
            module.options:UpdateTable(true)  -- Show icons after receiving response
        end
    end
end

-- Register the comm event
AceComm:RegisterComm("ART_AddonChecker", OnCommReceived)

-- Declare addonOffsets as part of module.options so that it's accessible across functions
module.options.addonOffsets = {}

-- Function to refresh the player list (now scoped inside module.options)
function module.options:RefreshPlayerList()
    playerList = {}
    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            table.insert(playerList, name)
        end
    end

    -- Clear all statuses and do not show icons until "Check Raid Addons" is pressed
    playerAddonStatus = {}
    module.options:UpdateTable(false)  -- Pass false to hide icons
end

function module.options:Load()
    self:CreateTilte()

    -- Create table frame using ELib
    self.table = ELib:ScrollFrame(self):Point("TOPLEFT", 10, -120):Size(660, 450)

    -- Create scrollable content frame inside the scroll frame
    self.table.content = CreateFrame("Frame", nil, self.table)
    self.table.content:SetSize(660, 450)
    self.table:SetScrollChild(self.table.content)

    -- Addon labels on X-axis (moved 200px to the right for more space)
    local xOffset = 200  -- Start further right to avoid overlap with player names
    self.addonOffsets = {}  -- Initialize the addonOffsets table

    for _, addonName in ipairs(addonList) do
        ELib:Text(self.table.content, addonName, 12):Point("TOPLEFT", xOffset, 0)
        table.insert(self.addonOffsets, xOffset)  -- Save the xOffset for this addon
        xOffset = xOffset + 150  -- Increase spacing between addon names
    end

    -- Player rows will be dynamically generated

    -- Create a button to trigger the addon check (RAID)
    self.checkRaidButton = ELib:Button(self, "Check Raid Addons"):Size(150, 20):Point("BOTTOMLEFT", 10, 25)
    self.checkRaidButton:OnClick(function()
        BroadcastAddonCheckRequest("RAID")
    end)

    -- Initially refresh player list when loading UI
    self:RefreshPlayerList()
end

-- Function to dynamically update the player list and check table
function module.options:UpdateTable(showIcons)
    -- Ensure the table is initialized before using it
    if not self.table then
        return
    end

    -- Clear previous rows
    for _, child in ipairs({self.table.content:GetChildren()}) do
        child:Hide()
    end

    -- Display players and their addon status
    local yOffset = -40
    for _, playerName in ipairs(playerList) do
        local missingAddons = playerAddonStatus[playerName] or {}

        -- Create row for each player
        local row = CreateFrame("Frame", nil, self.table.content)
        row:SetSize(660, 20)
        row:SetPoint("TOPLEFT", 10, yOffset)
        yOffset = yOffset - 25

        -- Player name (without realm)
        local strippedName = StripRealmName(playerName)
        ELib:Text(row, strippedName, 12):Point("LEFT", 5, 0)

        -- Addon checks (use the stored xOffsets to ensure alignment with addon labels)
        for index, addonName in ipairs(addonList) do
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("LEFT", self.addonOffsets[index], 0)  -- Use the xOffset stored earlier
            icon:SetSize(14, 14)

            -- Display ReadyCheck icons only if `showIcons` is true and response has been received
            if showIcons then
                if tContains(missingAddons, addonName) then
                    icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
                else
                    icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
                end
            else
                icon:SetTexture(nil)  -- No icons until check is performed
            end
        end

        row:Show()
    end

    -- Update the scrollable content height
    self:UpdateScrollFrame(yOffset)
end

function module.options:UpdateScrollFrame(yOffset)
    -- Calculate the total content height (with a small buffer)
    local minHeight = self.table:GetHeight()
    local buffer = 10  -- Adding a buffer to prevent the last row from getting cut off
    local contentHeight = math.abs(yOffset) + buffer

    -- Ensure the content frame is at least as tall as the scroll frame itself
    contentHeight = math.max(contentHeight, minHeight)

    -- Update the content frame's height and refresh the scroll bar
    self.table.content:SetHeight(contentHeight)
    self.table:UpdateScrollChildRect()

    -- Set the scroll bar values
    local scrollBar = self.table.ScrollBar
    scrollBar:SetMinMaxValues(0, math.max(0, contentHeight - minHeight))

    -- Handle scroll bar visibility: disable if content height <= scroll frame height
    if contentHeight <= minHeight then
        scrollBar:Hide()
    else
        scrollBar:Show()
    end
end

-- Register events to automatically refresh the player list on group changes
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
    module.options:RefreshPlayerList()
end)

-- Register the ADDON_LOADED event to initialize the addon
function module.main:ADDON_LOADED()
end
