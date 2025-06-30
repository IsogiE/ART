local CurrencyCheckerModule = {}
CurrencyCheckerModule.title = "Currency Checker"

local AceComm = LibStub("AceComm-3.0")

VACT = VACT or {}
local VACT = VACT

VACT.CurrencyCheck = VACT.CurrencyCheck or {}
VACT.CurrencyCheck.responses = {}
VACT.CurrencyCheck.currentCurrencyName = nil

local currencyCheckTimer = nil
local checkContext = nil

local PREFIX = "ADVANCECURRENCY"
local CMD_CHECK = "CURRENCY_CHECK"
local CMD_RESPONSE = "CURRENCY_RESPONSE"

local STATUS_NO_ADDON = "Addon not installed"
local STATUS_OFFLINE = "Offline"

function CurrencyCheckerModule:GetCurrencyAmount(currencyID)
    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if currencyInfo then
        return currencyInfo.quantity or 0
    end
    return 0
end

function CurrencyCheckerModule:SendCurrencyCheck(currencyID)
    VACT.CurrencyCheck.responses = {}
    local message = CMD_CHECK .. ":" .. currencyID

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
        if currencyCheckTimer then
            currencyCheckTimer:Cancel()
        end
        currencyCheckTimer = C_Timer.NewTimer(5, function()
            self:CheckForNonResponders()
        end)
    end
end

function CurrencyCheckerModule:SendCurrencyResponse(target, currencyID)
    local amount = self:GetCurrencyAmount(currencyID)
    local message = CMD_RESPONSE .. ":" .. amount
    AceComm:SendCommMessage(PREFIX, message, "WHISPER", target)
end

function CurrencyCheckerModule:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= PREFIX then
        return
    end

    local command, data = strsplit(":", message, 2)
    local playerName = sender
    local nickname = NicknameAPI:GetNicknameByCharacter(playerName)

    if command == CMD_CHECK then
        local currencyID = tonumber(data)
        if currencyID then
            self:SendCurrencyResponse(playerName, currencyID)
        end
    elseif command == CMD_RESPONSE then
        VACT.CurrencyCheck.responses[playerName] = {
            amount = data,
            nickname = nickname
        }
        self:ShowResults()
    end
end

function CurrencyCheckerModule:CheckForNonResponders()
    if not checkContext then
        return
    end

    local function addNonResponder(playerName, status)
        if not VACT.CurrencyCheck.responses[playerName] then
            local nickname = NicknameAPI:GetNicknameByCharacter(playerName)
            VACT.CurrencyCheck.responses[playerName] = {
                amount = status,
                nickname = nickname
            }
        end
    end

    if checkContext == "RAID" or checkContext == "PARTY" then
        local numGroupMembers = GetNumGroupMembers()
        for i = 1, numGroupMembers do
            local unit = (checkContext == "RAID" and "raid" or "party") .. i
            if UnitExists(unit) then
                local playerName = GetUnitName(unit, true)
                if playerName then
                    if UnitIsConnected(unit) then
                        addNonResponder(playerName, STATUS_NO_ADDON)
                    else
                        addNonResponder(playerName, STATUS_OFFLINE)
                    end
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

function CurrencyCheckerModule:ShowResults()
    if not self.configPanel or not self.configPanel.resultText then
        return
    end

    if VACT.CurrencyCheck.currentCurrencyName then
        self.configPanel.currencyNameLabel:SetText(VACT.CurrencyCheck.currentCurrencyName)
    end

    local results = {}
    for player, data in pairs(VACT.CurrencyCheck.responses) do
        local displayName = data.nickname or Ambiguate(player, "short")
        local amount = data.amount

        if amount == STATUS_NO_ADDON then
            table.insert(results, "|cff808080" .. displayName .. ": " .. amount .. "|r")
        elseif amount == STATUS_OFFLINE then
            table.insert(results, "|cffc0c0c0" .. displayName .. ": " .. amount .. "|r")
        else
            local numAmount = tonumber(amount)
            if numAmount then
                local color
                if numAmount > 0 then
                    color = "|cff00ff00"
                else
                    color = "|cffff0000"
                end
                table.insert(results, color .. displayName .. ": " .. FormatLargeNumber(numAmount) .. "|r")
            else
                table.insert(results, "|cffffff00" .. displayName .. ": Unknown|r")
            end
        end
    end
    table.sort(results)

    self.configPanel.resultText:SetText(table.concat(results, "\n"))
end

function CurrencyCheckerModule:GetConfigSize()
    return 800, 600
end

function CurrencyCheckerModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        return self.configPanel
    end

    local configPanel = CreateFrame("Frame", "CurrencyCheckerPanel", parent)
    configPanel:SetAllPoints(parent)

    local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    title:SetText("Currency Checker")

    local idLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    idLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -15)
    idLabel:SetText("Currency ID:")

    local idBoxFrame, idEditBox = UI:CreateMultilineEditBox(configPanel, 120, 30, "")
    idBoxFrame:SetPoint("TOPLEFT", idLabel, "BOTTOMLEFT", 0, -5)
    idEditBox:SetNumeric(true)

    local checkButton = UI:CreateButton(configPanel, "Check Currency", 150, 30, function()
        self:CheckCurrency()
    end)
    checkButton:SetPoint("LEFT", idBoxFrame, "RIGHT", 10, 0)

    local resultFrame, resultText = UI:CreateReadOnlyBox(configPanel, 520, 400, "")
    resultFrame:SetPoint("TOPLEFT", idBoxFrame, "BOTTOMLEFT", 0, -40)

    local currencyNameLabel = resultFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    currencyNameLabel:SetPoint("BOTTOMLEFT", resultFrame, "TOPLEFT", 5, 5)
    currencyNameLabel:SetTextColor(1, 0.82, 0)

    VACT.CurrencyCheck.responses = {}
    resultText:SetText("Enter a Currency ID and click 'Check Currency' to spot the slackers.")
    currencyNameLabel:SetText("")

    configPanel:SetScript("OnShow", function(self)
        VACT.CurrencyCheck.responses = {}
        self.resultText:SetText("Enter a Currency ID and click 'Check Currency' to spot the slackers.")
        self.currencyNameLabel:SetText("")
        VACT.CurrencyCheck.currentCurrencyName = nil
    end)

    configPanel:SetScript("OnHide", function()
        if currencyCheckTimer then
            currencyCheckTimer:Cancel()
            currencyCheckTimer = nil
        end
        checkContext = nil
    end)

    self.configPanel = configPanel
    self.configPanel.resultFrame = resultFrame
    self.configPanel.resultText = resultText
    self.configPanel.currencyIdBox = idEditBox
    self.configPanel.currencyNameLabel = currencyNameLabel

    return configPanel
end

function CurrencyCheckerModule:CheckCurrency()
    if not self.configPanel or not self.configPanel.currencyIdBox then
        return
    end

    local currencyID = tonumber(self.configPanel.currencyIdBox:GetText())
    if not currencyID or currencyID == 0 then
        self.configPanel.resultText:SetText("Please enter a valid Currency ID.")
        self.configPanel.currencyNameLabel:SetText("")
        return
    end

    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not currencyInfo then
        self.configPanel.resultText:SetText("Invalid Currency ID: " .. currencyID)
        self.configPanel.currencyNameLabel:SetText("")
        return
    end

    VACT.CurrencyCheck.currentCurrencyName = currencyInfo.name
    self.configPanel.currencyNameLabel:SetText("Checking: " .. currencyInfo.name)
    self.configPanel.resultText:SetText("Sending request...")

    self:SendCurrencyCheck(currencyID)
end

AceComm:RegisterComm(PREFIX, function(...)
    CurrencyCheckerModule:OnCommReceived(...)
end)

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(CurrencyCheckerModule)
end
