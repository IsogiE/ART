local VersionCheckerAddonName, ART = ...

local module = ART:New("VersionCheck", "Version Check")
local ELib, L = ART.lib, ART.L

local AceComm = LibStub("AceComm-3.0")

local VART = nil
local versionCheckTimer = nil 

-- Retrieve the version from the .toc
local version = C_AddOns.GetAddOnMetadata(VersionCheckerAddonName, "Version")

local function OnAddonLoaded(addonName)
    if addonName == VersionCheckerAddonName then
        VART = _G.VART

        VART.VersionCheck = VART.VersionCheck or {}
        VART.VersionCheck.responses = {}

        ART_VersionCheckDB = ART_VersionCheckDB or {}
        ART_VersionCheckDB.version = version

        VART.VersionCheck.version = ART_VersionCheckDB.version
    end
end

local function compareVersions(v1, v2)
    local v1Parts = {strsplit(".", v1)}
    local v2Parts = {strsplit(".", v2)}
    for i = 1, math.max(#v1Parts, #v2Parts) do
        local v1Part = tonumber(v1Parts[i]) or 0
        local v2Part = tonumber(v2Parts[i]) or 0
        if v1Part > v2Part then
            return 1
        elseif v1Part < v2Part then
            return -1
        end
    end
    return 0
end

function module:SendVersionCheck()
    if not VART.VersionCheck.version then
        return
    end

    VART.VersionCheck.responses = {}
    local message = "VERSION_CHECK:" .. VART.VersionCheck.version

    -- Usually will use raid, but party is easier for debugging 
    local channel = IsInRaid() and "RAID" or "PARTY"
    AceComm:SendCommMessage("ADVANCEVERSION", message, channel)

    -- Timeout for safety while checking for addon installations
    versionCheckTimer = C_Timer.NewTimer(3, function() module:CheckForNonResponders() end)
end

function module:SendVersionResponse(target, senderVersion)
    if not VART.VersionCheck.version then
        return
    end

    local message = "VERSION_RESPONSE:" .. VART.VersionCheck.version
    AceComm:SendCommMessage("ADVANCEVERSION", message, "WHISPER", target)

    -- checking for oudated versions and remind users to update if outdated
    if compareVersions(VART.VersionCheck.version, senderVersion) < 0 then
        StaticPopupDialogs["VERSION_CHECK_UPDATE"] = {
            text = "You are using an outdated version of the addon. Please update to the latest version.",
            button1 = "OK",
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
        }
        StaticPopup_Show("VERSION_CHECK_UPDATE")
    end
end

function module:OnCommReceived(prefix, message, distribution, sender)
    if prefix == "ADVANCEVERSION" then
        local command, version = strsplit(":", message)
        local playerName = Ambiguate(sender, "mail")  
        if command == "VERSION_CHECK" then
            VART.VersionCheck.responses[playerName] = version
            module:SendVersionResponse(playerName, version) 
        elseif command == "VERSION_RESPONSE" then
            VART.VersionCheck.responses[playerName] = version
            module:ShowResults()
        end
    end
end

function module:CheckForNonResponders()
    local groupType = IsInRaid() and "RAID" or "PARTY"
    local numGroupMembers = GetNumGroupMembers()

    for i = 1, numGroupMembers do
        local unit = groupType .. i
        local playerName = GetUnitName(unit, true)
        if playerName then
            playerName = Ambiguate(playerName, "mail") 
            if not VART.VersionCheck.responses[playerName] then
                VART.VersionCheck.responses[playerName] = "Addon not installed"
            end
        end
    end

    module:ShowResults()
end

function module:ShowResults()
    local highestVersion = VART.VersionCheck.version
    for _, version in pairs(VART.VersionCheck.responses) do
        if compareVersions(version, highestVersion) > 0 then
            highestVersion = version
        end
    end

    local result = ""
    for player, version in pairs(VART.VersionCheck.responses) do
        local color
        if version == "Addon not installed" then
            color = "|cff808080" 
        else
            color = compareVersions(version, highestVersion) == 0 and "|cff00ff00" or "|cffff0000" 
        end
        local displayName = Ambiguate(player, "short")  
        result = result .. color .. displayName .. ": " .. version .. "|r\n"
    end
    if self.options and self.options.resultFrame and self.options.resultFrame.text then
        self.options.resultFrame.text:SetText(result)
    end
end

-- Once again acecomm is the goat
AceComm:RegisterComm("ADVANCEVERSION", function(...) module:OnCommReceived(...) end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    end
end)

-- Trigger the version check 
function module:CheckVersions()
    module:SendVersionCheck()
end

function module.options:Load()
    self:CreateTilte()

    self.checkVersionsButton = ELib:Button(self, "Check Versions"):Size(150, 20):Point("TOPLEFT", 10, -25)
    self.checkVersionsButton:OnClick(function()
        module:CheckVersions()
    end)

    self.resultFrame = ELib:ScrollFrame(self):Size(660, 450):Point("TOPLEFT", 10, -50)
    self.resultFrame.text = ELib:Text(self.resultFrame, "", 12):Point("TOPLEFT", 5, -5):Point("TOPRIGHT", -5, -5)

    self.resultFrame:SetScript("OnShow", function()
        VART.VersionCheck.responses = {}
        self.resultFrame.text:SetText("") 
    end)

    self.resultFrame:SetScript("OnHide", function()
        if versionCheckTimer then
            versionCheckTimer:Cancel()
            versionCheckTimer = nil
        end
    end)
end