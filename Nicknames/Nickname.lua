local NicknameModule = {}

NicknameModule.title = "Nicknames"
NicknameModule.isInitialized = false

local addonName = ...

if not ACT then
    return
end

ACT.Nicknames = NicknameModule

-- use the old DB for now 
local db
local integrations_db

local InitializeIntegrations

local function RealmIncludedName(unit)
    local name, realm = UnitNameUnmodified(unit)
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    if not realm then
        return
    end
    return string.format("%s-%s", name, realm)
end

local function InitializeDatabase()
    if not ACT.db or not ACT.db.profile then
        return
    end

    if not ACT.db.profile.nicknames then
        ACT.db.profile.nicknames = {}
    end
    if not ACT.db.profile.nickname_integrations then
        ACT.db.profile.nickname_integrations = {}
    end
    if ACT.db.profile.nickname == nil then
        ACT.db.profile.nickname = nil
    end

    db = ACT.db.profile.nicknames
    integrations_db = ACT.db.profile.nickname_integrations

    local playerRealmName = RealmIncludedName("player")
    local currentPlayerNickname = ACT.db.profile.nickname

    if playerRealmName and currentPlayerNickname then
        db[playerRealmName] = currentPlayerNickname
    end

    ACT_CharacterDB = {
        nicknames = db
    }
    ACT_AccountDB = {
        nickname_integrations = integrations_db
    }
    NicknameModule.isInitialized = true

    InitializeIntegrations()
end

if ACT.db and ACT.db.profile then
    InitializeDatabase()
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGIN" then
            if ACT.db and ACT.db.profile then
                InitializeDatabase()
            end
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end)
end

NicknameModule.nicknameFunctions = {}
local initializedNicknames = {}
local nicknameToCharacterCache = {}
local addOnNameToCheckButton = {}

function InitializeIntegrations()
    if not NicknameModule.isInitialized then
        return
    end
    for addOnName, functions in pairs(NicknameModule.nicknameFunctions) do
        if (addOnName == "Blizzard" or C_AddOns.IsAddOnLoaded(addOnName)) and not initializedNicknames[addOnName] then
            if functions.Init then
                functions.Init()
                initializedNicknames[addOnName] = true
            end
        end
    end
    NicknameModule:UpdateCheckButtons()
end

function NicknameModule:UpdateCheckButtons()
    for addOnName, checkButton in pairs(addOnNameToCheckButton) do
        local isLoaded = addOnName == "Blizzard" or C_AddOns.IsAddOnLoaded(addOnName)
        checkButton:SetEnabled(isLoaded)
        if isLoaded then
            checkButton.Text:SetTextColor(1, 0.82, 0)
        else
            checkButton.Text:SetTextColor(0.5, 0.5, 0.5)
        end
    end
end

function NicknameModule:UpdateNicknameForUnit(unit, nickname)
    if not NicknameModule.isInitialized or not db then
        return
    end
    local realmIncludedName = RealmIncludedName(unit)
    if not realmIncludedName then
        return
    end

    nickname = nickname and strtrim(nickname)
    if nickname == "" then
        nickname = nil
    end

    local oldNickname = db[realmIncludedName]

    if oldNickname == nickname then
        return
    end

    if unit == "player" then
        ACT.db.profile.nickname = nickname
    end
    db[realmIncludedName] = nickname

    if oldNickname then
        nicknameToCharacterCache[oldNickname] = nil
    end
    if nickname then
        nicknameToCharacterCache[nickname] = unit
    end

    for _, functions in pairs(self.nicknameFunctions) do
        if functions.Update then
            functions.Update(unit, realmIncludedName, oldNickname, nickname)
        end
    end
end

-- Stuff for integrations to use 
function ACT:HasNickname(unit)
    if not NicknameModule.isInitialized or not db then
        return false
    end
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
        return false
    end
    local realmIncludedName = RealmIncludedName(unit)
    if not realmIncludedName then
        return false
    end
    return db[realmIncludedName] ~= nil
end

function ACT:GetNickname(unit)
    if not NicknameModule.isInitialized or not db then
        return UnitNameUnmodified(unit)
    end
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
        return UnitNameUnmodified(unit)
    end
    local realmIncludedName = RealmIncludedName(unit)
    local nickname = db[realmIncludedName]
    return nickname or UnitNameUnmodified(unit)
end

function ACT:GetRawNickname(unit)
    if not NicknameModule.isInitialized or not db then
        return UnitNameUnmodified(unit)
    end
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
        return UnitNameUnmodified(unit)
    end
    local realmIncludedName = RealmIncludedName(unit)
    return db[realmIncludedName] or UnitNameUnmodified(unit)
end

function ACT:GetCharacterInGroup(nickname)
    local character = nicknameToCharacterCache[nickname]
    if not character then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if ACT:GetRawNickname(unit) == nickname then
                nicknameToCharacterCache[nickname] = unit
                return unit
            end
        end
    end
    return character
end

-- Init for now
local integrationInitFrame = CreateFrame("Frame")
integrationInitFrame:RegisterEvent("ADDON_LOADED")
integrationInitFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if NicknameModule.isInitialized and loadedAddon ~= addonName then
        InitializeIntegrations()
    end
end)

-- UI Stuff
function NicknameModule:GetConfigSize()
    return 800, 600
end

function NicknameModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        if self.configPanel.OnShow then
            self.configPanel:OnShow()
        end
        return self.configPanel
    end

    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetAllPoints(parent)
    self.configPanel = configPanel

    local nicknameLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nicknameLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    nicknameLabel:SetText(self.title)

    local nicknameEditBoxFrame, nicknameEditBox = UI:CreateMultilineEditBox(configPanel, 200, 32, "", function(text)
        NicknameModule:UpdateNicknameForUnit("player", text)
    end)
    nicknameEditBoxFrame:SetPoint("TOPLEFT", nicknameLabel, "BOTTOMLEFT", 0, -15)
    nicknameEditBox:SetMaxLetters(12)
    configPanel.nicknameEditBox = nicknameEditBox

    local saveButton = UI:CreateButton(configPanel, "Save", 80, 32, function()
        NicknameModule:UpdateNicknameForUnit("player", nicknameEditBox:GetText())
        nicknameEditBox:ClearFocus()
    end)
    saveButton:SetPoint("LEFT", nicknameEditBoxFrame, "RIGHT", 10, 0)

    local integrationsLabel = UI:CreateLabel(configPanel, "Enable Nickname Integrations", 14)
    integrationsLabel:SetPoint("TOPLEFT", nicknameEditBoxFrame, "BOTTOMLEFT", 0, -25)

    local integrations = {{
        key = "Blizzard",
        name = "Blizzard Raid Frames"
    }, {
        key = "Cell",
        name = "Cell"
    }, {
        key = "ElvUI",
        name = "ElvUI"
    }, {
        key = "Grid2",
        name = "Grid2"
    }, {
        key = "ShadowedUnitFrames",
        name = "Shadowed Unit Frames"
    }, {
        key = "VuhDo",
        name = "VuhDo"
    }}

    wipe(addOnNameToCheckButton) -- Clear the table in case the UI is ever rebuilt

    local lastCheckButton
    for i, data in ipairs(integrations) do
        local checkButton = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
        checkButton:SetSize(22, 22)

        if not lastCheckButton then
            checkButton:SetPoint("TOPLEFT", integrationsLabel, "BOTTOMLEFT", 15, -10)
        else
            checkButton:SetPoint("TOPLEFT", lastCheckButton, "BOTTOMLEFT", 0, -5)
        end
        lastCheckButton = checkButton

        local text = checkButton:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        text:SetText(data.name)
        text:SetPoint("LEFT", checkButton, "RIGHT", 5, 0)
        checkButton.Text = text

        addOnNameToCheckButton[data.key] = checkButton

        checkButton:SetScript("OnClick", function(self)
            if not NicknameModule.isInitialized or not integrations_db then
                return
            end
            local checked = self:GetChecked()
            integrations_db[data.key] = checked
            if checked then
                if NicknameModule.nicknameFunctions[data.key] and NicknameModule.nicknameFunctions[data.key].Enable then
                    NicknameModule.nicknameFunctions[data.key].Enable()
                end
            else
                if NicknameModule.nicknameFunctions[data.key] and NicknameModule.nicknameFunctions[data.key].Disable then
                    NicknameModule.nicknameFunctions[data.key].Disable()
                end
            end
        end)
    end

    configPanel.OnShow = function()
        if not NicknameModule.isInitialized or not db or not integrations_db then
            return
        end

        if configPanel.nicknameEditBox then
            configPanel.nicknameEditBox:SetText(ACT.db.profile.nickname or "")
        end

        for addOnName, checkButton in pairs(addOnNameToCheckButton) do
            checkButton:SetChecked(integrations_db[addOnName] or false)
        end
        NicknameModule:UpdateCheckButtons()
    end

    configPanel:SetScript("OnShow", configPanel.OnShow)

    return configPanel
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(NicknameModule)
end

return NicknameModule
