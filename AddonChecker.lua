local GlobalAddonName, MRT = ...
local ELib, L = MRT.lib, MRT.L
local AceComm = LibStub:GetLibrary("AceComm-3.0")

local module = MRT:New("AddonChecker", "Addon Checker")

local addonList = {
    "NorthernSkyMedia",  
    "SharedMedia_Causese",       
    "LibOpenRaid",               
}

local playerList = {}
local playerAddonStatus = {}

local function StripRealmName(playerName)
    return playerName:match("([^%-]+)") or playerName
end

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

local function BroadcastAddonCheckRequest(channel)
    local message = "CHECK_ADDONS"
    
    local missingAddons = CheckAddons()
    playerAddonStatus[UnitName("player")] = missingAddons

    if channel == "RAID" then
        AceComm:SendCommMessage("ART_AddonChecker", message, "RAID")
    end

    module.options:UpdateTable(false) 
end

local function OnCommReceived(prefix, message, distribution, sender)
    if prefix == "ART_AddonChecker" then
        if message == "CHECK_ADDONS" then
            C_Timer.After(1, function()
                local missingAddons = CheckAddons()
                local responseMessage = table.concat(missingAddons, ",") or "none"
                AceComm:SendCommMessage("ART_AddonChecker", "ADDON_RESPONSE:" .. responseMessage, "WHISPER", sender)
            end)

        elseif message:find("^ADDON_RESPONSE:") then
            local response = message:sub(16) 
            local missingAddons = {}

            if response ~= "none" then
                for addon in string.gmatch(response, "([^,]+)") do
                    table.insert(missingAddons, addon)
                end
            end

            playerAddonStatus[sender] = missingAddons  
            module.options:UpdateTable(true) 
        end
    end
end


AceComm:RegisterComm("ART_AddonChecker", OnCommReceived)

module.options.addonOffsets = {}

function module.options:RefreshPlayerList()
    playerList = {}
    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            table.insert(playerList, name)
        end
    end

    playerAddonStatus = {}
    module.options:UpdateTable(false)  
end

function module.options:Load()
    self:CreateTilte()

    self.table = ELib:ScrollFrame(self):Point("TOPLEFT", 10, -120):Size(660, 450)

    self.table.content = CreateFrame("Frame", nil, self.table)
    self.table.content:SetSize(660, 450)
    self.table:SetScrollChild(self.table.content)

    local xOffset = 200 
    self.addonOffsets = {} 

    for _, addonName in ipairs(addonList) do
        ELib:Text(self.table.content, addonName, 12):Point("TOPLEFT", xOffset, 0)
        table.insert(self.addonOffsets, xOffset) 
        xOffset = xOffset + 150 
    end

    self.checkRaidButton = ELib:Button(self, "Check Raid Addons"):Size(150, 20):Point("BOTTOMLEFT", 10, 25)
    self.checkRaidButton:OnClick(function()
        BroadcastAddonCheckRequest("RAID")
    end)


    self:RefreshPlayerList()
end

function module.options:UpdateTable(showIcons)
    if not self.table then
        return
    end

    for _, child in ipairs({self.table.content:GetChildren()}) do
        child:Hide()
    end

    local yOffset = -40
    for _, playerName in ipairs(playerList) do
        local missingAddons = playerAddonStatus[playerName] or {}

        local row = CreateFrame("Frame", nil, self.table.content)
        row:SetSize(660, 20)
        row:SetPoint("TOPLEFT", 10, yOffset)
        yOffset = yOffset - 25

        local strippedName = StripRealmName(playerName)
        ELib:Text(row, strippedName, 12):Point("LEFT", 5, 0)

        for index, addonName in ipairs(addonList) do
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("LEFT", self.addonOffsets[index], 0) 
            icon:SetSize(14, 14)

            if showIcons then
                if tContains(missingAddons, addonName) then
                    icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
                else
                    icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
                end
            else
                icon:SetTexture(nil) 
            end
        end

        row:Show()
    end

    self:UpdateScrollFrame(yOffset)
end

function module.options:UpdateScrollFrame(yOffset)
    local minHeight = self.table:GetHeight()
    local buffer = 10  
    local contentHeight = math.abs(yOffset) + buffer

    contentHeight = math.max(contentHeight, minHeight)

    self.table.content:SetHeight(contentHeight)
    self.table:UpdateScrollChildRect()

    local scrollBar = self.table.ScrollBar
    scrollBar:SetMinMaxValues(0, math.max(0, contentHeight - minHeight))

    if contentHeight <= minHeight then
        scrollBar:Hide()
    else
        scrollBar:Show()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
    module.options:RefreshPlayerList()
end)

function module.main:ADDON_LOADED()
end
