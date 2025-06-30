local VersionCheckerModule = {}
VersionCheckerModule.title = "Version Checker"

local AceComm = LibStub("AceComm-3.0")

VACT = VACT or {}
local VACT = VACT

VACT.VersionCheck = VACT.VersionCheck or {}
VACT.VersionCheck.responses = {}

local versionCheckTimer = nil
local checkContext = nil

local PREFIX = "ADVANCEVERSION"
local CMD_CHECK = "VERSION_CHECK"
local CMD_RESPONSE = "VERSION_RESPONSE"

local STATUS_NO_ADDON = "Addon not installed"
local STATUS_OFFLINE = "Offline"

local function OnAddonLoaded(addonName)
    if addonName == "ACT" then
        ART_VersionCheckDB = ART_VersionCheckDB or {}
        local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
        ART_VersionCheckDB.version = version
        VACT.VersionCheck.version = ART_VersionCheckDB.version
    end
end

local function compareVersions(v1, v2)
    local function getVersionIterator(v)
        return string.gmatch(tostring(v), "([^.]+)")
    end

    local v1_iter = getVersionIterator(v1)
    local v2_iter = getVersionIterator(v2)

    while true do
        local v1_part_str = v1_iter()
        local v2_part_str = v2_iter()

        if not v1_part_str and not v2_part_str then
            return 0
        end

        local v1_part = tonumber(v1_part_str) or 0
        local v2_part = tonumber(v2_part_str) or 0

        if v1_part > v2_part then
            return 1
        elseif v1_part < v2_part then
            return -1
        end
    end
end

local function formatVersion(ver)
    ver = tostring(ver)
    if not ver:find("%.") and #ver == 2 then
        return ver:sub(1, 1) .. "." .. ver:sub(2, 2)
    end
    return ver
end

function VersionCheckerModule:SendVersionCheck()
    if not VACT.VersionCheck.version then
        return
    end

    VACT.VersionCheck.responses = {}
    local message = CMD_CHECK .. ":" .. VACT.VersionCheck.version

    if IsInRaid() then
        checkContext = "RAID"
    elseif IsInGroup() then
        checkContext = "PARTY"
    elseif IsInGuild() then
        checkContext = "GUILD"
    else
        checkContext = nil
    end

    if checkContext then
        AceComm:SendCommMessage(PREFIX, message, checkContext)
        if versionCheckTimer then
            versionCheckTimer:Cancel()
        end
        versionCheckTimer = C_Timer.NewTimer(5, function()
            self:CheckForNonResponders()
        end)
    end
end

function VersionCheckerModule:SendVersionResponse(target)
    if not VACT.VersionCheck.version then
        return
    end
    local message = CMD_RESPONSE .. ":" .. VACT.VersionCheck.version
    AceComm:SendCommMessage(PREFIX, message, "WHISPER", target)
end

function VersionCheckerModule:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= PREFIX then
        return
    end

    local command, data = strsplit(":", message)
    local playerName = sender
    local nickname = NicknameAPI:GetNicknameByCharacter(playerName)

    if command == CMD_CHECK then
        VACT.VersionCheck.responses[playerName] = {
            ver = data,
            nickname = nickname
        }
        self:SendVersionResponse(playerName)
    elseif command == CMD_RESPONSE then
        VACT.VersionCheck.responses[playerName] = {
            ver = data,
            nickname = nickname
        }
        self:ShowResults()
    end
end

function VersionCheckerModule:CheckForNonResponders()
    if not checkContext then
        return
    end

    local function addNonResponder(playerName, status)
        if not VACT.VersionCheck.responses[playerName] then
            local nickname = NicknameAPI:GetNicknameByCharacter(playerName)
            VACT.VersionCheck.responses[playerName] = {
                ver = status,
                nickname = nickname
            }
        end
    end

    if checkContext == "RAID" or checkContext == "PARTY" then
        local numGroupMembers = GetNumGroupMembers()
        for i = 1, numGroupMembers do
            local unit = string.lower(checkContext) .. i
            local playerName = GetUnitName(unit, true)
            if playerName then
                if UnitIsConnected(unit) then
                    addNonResponder(playerName, STATUS_NO_ADDON)
                else
                    addNonResponder(playerName, STATUS_OFFLINE)
                end
            end
        end
    elseif checkContext == "GUILD" then
        if C_GuildInfo and C_GuildInfo.GetNumGuildMembers then
            local numGuildMembers = C_GuildInfo.GetNumGuildMembers()
            for i = 1, numGuildMembers do
                local name, _, _, _, _, _, _, _, online, _, _, _, _, memberIsSelf = C_GuildInfo.GetGuildRosterInfo(i)
                if name and not memberIsSelf and online then
                    addNonResponder(name, STATUS_NO_ADDON)
                end
            end
        end
    end

    self:ShowResults()
end

function VersionCheckerModule:ShowResults()
    if not self.configPanel or not self.configPanel.resultText then
        return
    end

    local highestVersion = nil
    for _, data in pairs(VACT.VersionCheck.responses) do
        if data.ver ~= STATUS_NO_ADDON and data.ver ~= STATUS_OFFLINE then
            if not highestVersion or compareVersions(data.ver, highestVersion) > 0 then
                highestVersion = data.ver
            end
        end
    end

    local results = {}
    for player, data in pairs(VACT.VersionCheck.responses) do
        local displayName = data.nickname or Ambiguate(player, "short")
        local ver = data.ver
        local color, displayText

        if ver == STATUS_NO_ADDON then
            color = "|cff808080"
            displayText = ver
        elseif ver == STATUS_OFFLINE then
            color = "|cffc0c0c0"
            displayText = ver
        else
            if highestVersion and compareVersions(ver, highestVersion) == 0 then
                color = "|cff00ff00"
            else
                color = "|cffff0000"
            end
            displayText = formatVersion(ver)
        end
        table.insert(results, color .. displayName .. ": " .. displayText .. "|r")
    end
    table.sort(results)

    self.configPanel.resultText:SetText(table.concat(results, "\n"))
end

function VersionCheckerModule:GetConfigSize()
    return 800, 600
end

function VersionCheckerModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        return self.configPanel
    end

    local configPanel = CreateFrame("Frame", "VersionCheckerPanel", parent)
    configPanel:SetAllPoints(parent)

    local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    title:SetText(self.title)

    local checkVersionsButton = UI:CreateButton(configPanel, "Check Versions", 120, 30, function()
        self:CheckVersions()
    end)
    checkVersionsButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)

    local resultFrame, resultText = UI:CreateReadOnlyBox(configPanel, 520, 450, "")
    resultFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -50)

    configPanel.resultFrame = resultFrame
    configPanel.resultText = resultText

    VACT.VersionCheck.responses = {}
    configPanel.resultText:SetText("Click 'Check Versions' to spot naughty people.")

    configPanel:SetScript("OnShow", function(self)
        VACT.VersionCheck.responses = {}
        if self.resultText then
            self.resultText:SetText("Click 'Check Versions' to spot naughty people.")
        end
    end)

    configPanel:SetScript("OnHide", function()
        if versionCheckTimer then
            versionCheckTimer:Cancel()
            versionCheckTimer = nil
        end
        checkContext = nil
    end)

    self.configPanel = configPanel
    return configPanel
end

function VersionCheckerModule:CheckVersions()
    if self.configPanel and self.configPanel.resultText then
        self.configPanel.resultText:SetText("Sending version check...")
    end
    self:SendVersionCheck()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    end
end)

AceComm:RegisterComm(PREFIX, function(...)
    VersionCheckerModule:OnCommReceived(...)
end)

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(VersionCheckerModule)
end
