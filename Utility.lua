local NicknameModule = {}

NicknameModule.title = "Utility"
NicknameModule.isInitialized = false

local addonName = ...

if not ACT then
    return
end

ACT.Nicknames = NicknameModule

local db
local integrations_db
local bcm_db
local whisper_db
local cdm_db

local InitializeIntegrations

StaticPopupDialogs["ACT_UTILITY_RELOAD"] = {
    text = "Changing this setting requires a UI Reload to take full effect.\nDo you want to reload now?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function RealmIncludedName(unit)
    local name, realm = UnitNameUnmodified(unit)
    
    if (name and issecretvalue(name)) or (realm and issecretvalue(realm)) then
        return nil
    end

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
    if not ACT.db.profile.bcm_settings then
        ACT.db.profile.bcm_settings = {
            essential_centering = false,
            utility_centering = false
        }
    end
    if ACT.db.profile.bcm_settings.utility_centering == nil then
        ACT.db.profile.bcm_settings.utility_centering = false
    end

    if not ACT.db.profile.whisper_settings then
        ACT.db.profile.whisper_settings = {
            enabled = false
        }
    end

    if not ACT.db.profile.cdm_settings then
        ACT.db.profile.cdm_settings = {
            global_ignore_aura_override = false
        }
    end

    if ACT.db.profile.nickname == nil then
        ACT.db.profile.nickname = nil
    end

    db = ACT.db.profile.nicknames
    integrations_db = ACT.db.profile.nickname_integrations
    bcm_db = ACT.db.profile.bcm_settings
    whisper_db = ACT.db.profile.whisper_settings
    cdm_db = ACT.db.profile.cdm_settings

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

    if ACT.BCM and ACT.BCM.UpdateState then
        ACT.BCM:UpdateState()
    end
    
    if ACT.AuraOverride then
        if ACT.AuraOverride.Initialize then
            ACT.AuraOverride:Initialize()
        end
        if ACT.AuraOverride.UpdateState then
            ACT.AuraOverride:UpdateState()
        end
    end
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

    local windowTitle = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    windowTitle:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    windowTitle:SetText(self.title)

    local nicknameSettingsTitle = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nicknameSettingsTitle:SetPoint("TOPLEFT", windowTitle, "BOTTOMLEFT", 0, -25)
    nicknameSettingsTitle:SetText("Nickname Settings")

    local nicknameLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nicknameLabel:SetPoint("TOPLEFT", nicknameSettingsTitle, "BOTTOMLEFT", 0, -15)
    nicknameLabel:SetText("Nickname")

    local nicknameEditBoxFrame, nicknameEditBox = UI:CreateMultilineEditBox(configPanel, 200, 32, "", function(text)
        NicknameModule:UpdateNicknameForUnit("player", text)
    end)
    nicknameEditBoxFrame:SetPoint("TOPLEFT", nicknameLabel, "BOTTOMLEFT", 0, -10)
    nicknameEditBox:SetMaxLetters(12)
    configPanel.nicknameEditBox = nicknameEditBox

    local saveButton = UI:CreateButton(configPanel, "Save", 80, 32, function()
        NicknameModule:UpdateNicknameForUnit("player", nicknameEditBox:GetText())
        nicknameEditBox:ClearFocus()
    end)
    saveButton:SetPoint("LEFT", nicknameEditBoxFrame, "RIGHT", 10, 0)

    local integrationsLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    integrationsLabel:SetPoint("TOPLEFT", nicknameEditBoxFrame, "BOTTOMLEFT", 0, -25)
    integrationsLabel:SetText("Enable Integrations")

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
        key = "UnhaltedUnitFrames",
        name = "Unhalted Unit Frames"
    }, {
        key = "VuhDo",
        name = "VuhDo"
    }}

    wipe(addOnNameToCheckButton) 

    local lastCheckButton
    for i, data in ipairs(integrations) do
        local checkButton = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
        checkButton:SetSize(22, 22)

        if not lastCheckButton then
            checkButton:SetPoint("TOPLEFT", integrationsLabel, "BOTTOMLEFT", 0, -10)
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
    
    local divider = configPanel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.2)
    divider:SetHeight(1)
    
    divider:SetPoint("TOP", lastCheckButton, "BOTTOM", 0, -20)
    divider:SetPoint("LEFT", configPanel, "LEFT", 20, 0)
    divider:SetPoint("RIGHT", configPanel, "RIGHT", -255, 0)

    local utilityLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    utilityLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -20)
    utilityLabel:SetText("Utility Settings")

    local bcmCheck = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    bcmCheck:SetSize(22, 22)
    bcmCheck:SetPoint("TOPLEFT", utilityLabel, "BOTTOMLEFT", 0, -10)
    
    bcmCheck.Text = bcmCheck:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bcmCheck.Text:SetText("Essential Cooldown Bar Centering")
    bcmCheck.Text:SetPoint("LEFT", bcmCheck, "RIGHT", 5, 0)
    
    bcmCheck:SetScript("OnClick", function(self)
        if not NicknameModule.isInitialized or not bcm_db then return end
        
        local checked = self:GetChecked()
        bcm_db.essential_centering = checked
        
        if ACT.BCM and ACT.BCM.UpdateState then
            ACT.BCM:UpdateState()
        end
        
        if checked then
            bcmCheck.Text:SetTextColor(1, 0.82, 0)
        else
            bcmCheck.Text:SetTextColor(0.5, 0.5, 0.5)
        end

        StaticPopup_Show("ACT_UTILITY_RELOAD")
    end)

    local bcmUtilityCheck = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    bcmUtilityCheck:SetSize(22, 22)
    bcmUtilityCheck:SetPoint("TOPLEFT", bcmCheck, "BOTTOMLEFT", 0, -5)
    
    bcmUtilityCheck.Text = bcmUtilityCheck:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bcmUtilityCheck.Text:SetText("Utility Cooldown Bar Centering")
    bcmUtilityCheck.Text:SetPoint("LEFT", bcmUtilityCheck, "RIGHT", 5, 0)
    
    bcmUtilityCheck:SetScript("OnClick", function(self)
        if not NicknameModule.isInitialized or not bcm_db then return end
        
        local checked = self:GetChecked()
        bcm_db.utility_centering = checked
        
        if ACT.BCM and ACT.BCM.UpdateState then
            ACT.BCM:UpdateState()
        end
        
        if checked then
            bcmUtilityCheck.Text:SetTextColor(1, 0.82, 0)
        else
            bcmUtilityCheck.Text:SetTextColor(0.5, 0.5, 0.5)
        end

        StaticPopup_Show("ACT_UTILITY_RELOAD")
    end)

    local whisperCheck = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    whisperCheck:SetSize(22, 22)
    whisperCheck:SetPoint("TOPLEFT", bcmUtilityCheck, "BOTTOMLEFT", 0, -5)
    
    whisperCheck.Text = whisperCheck:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    whisperCheck.Text:SetText("Whisper Sound Notifications (Master Channel)")
    whisperCheck.Text:SetPoint("LEFT", whisperCheck, "RIGHT", 5, 0)
    
    whisperCheck:SetScript("OnClick", function(self)
        if not NicknameModule.isInitialized or not whisper_db then return end
        
        local checked = self:GetChecked()
        whisper_db.enabled = checked
        
        if ACT.WhisperNotify and ACT.WhisperNotify.UpdateState then
            ACT.WhisperNotify:UpdateState()
        end
        
        if checked then
            whisperCheck.Text:SetTextColor(1, 0.82, 0)
        else
            whisperCheck.Text:SetTextColor(0.5, 0.5, 0.5)
        end
    end)

    local cdmOverrideCheck = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    cdmOverrideCheck:SetSize(22, 22)
    cdmOverrideCheck:SetPoint("TOPLEFT", whisperCheck, "BOTTOMLEFT", 0, -5)
    
    cdmOverrideCheck.Text = cdmOverrideCheck:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cdmOverrideCheck.Text:SetText("Remove Cooldown Manager Aura Duration")
    cdmOverrideCheck.Text:SetPoint("LEFT", cdmOverrideCheck, "RIGHT", 5, 0)
    
    cdmOverrideCheck:SetScript("OnClick", function(self)
        if not NicknameModule.isInitialized or not cdm_db then return end
        
        local checked = self:GetChecked()
        cdm_db.global_ignore_aura_override = checked
        
        if ACT.AuraOverride and ACT.AuraOverride.UpdateState then
            ACT.AuraOverride:UpdateState()
        end
        
        if checked then
            cdmOverrideCheck.Text:SetTextColor(1, 0.82, 0)
        else
            cdmOverrideCheck.Text:SetTextColor(0.5, 0.5, 0.5)
        end
    end)

    configPanel.OnShow = function()
        if not NicknameModule.isInitialized or not db or not integrations_db or not bcm_db or not whisper_db or not cdm_db then
            return
        end

        if configPanel.nicknameEditBox then
            configPanel.nicknameEditBox:SetText(ACT.db.profile.nickname or "")
        end

        for addOnName, checkButton in pairs(addOnNameToCheckButton) do
            checkButton:SetChecked(integrations_db[addOnName] or false)
        end
        NicknameModule:UpdateCheckButtons()
        
        local isBCMEnabled = bcm_db.essential_centering or false
        bcmCheck:SetChecked(isBCMEnabled)
        if isBCMEnabled then
            bcmCheck.Text:SetTextColor(1, 0.82, 0)
        else
            bcmCheck.Text:SetTextColor(0.5, 0.5, 0.5)
        end

        local isBCMUtilityEnabled = bcm_db.utility_centering or false
        bcmUtilityCheck:SetChecked(isBCMUtilityEnabled)
        if isBCMUtilityEnabled then
            bcmUtilityCheck.Text:SetTextColor(1, 0.82, 0)
        else
            bcmUtilityCheck.Text:SetTextColor(0.5, 0.5, 0.5)
        end

        local isWhisperEnabled = whisper_db.enabled or false
        whisperCheck:SetChecked(isWhisperEnabled)
        if isWhisperEnabled then
            whisperCheck.Text:SetTextColor(1, 0.82, 0)
        else
            whisperCheck.Text:SetTextColor(0.5, 0.5, 0.5)
        end

        local isCDMOverrideEnabled = cdm_db.global_ignore_aura_override or false
        cdmOverrideCheck:SetChecked(isCDMOverrideEnabled)
        if isCDMOverrideEnabled then
            cdmOverrideCheck.Text:SetTextColor(1, 0.82, 0)
        else
            cdmOverrideCheck.Text:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    configPanel:SetScript("OnShow", configPanel.OnShow)

    return configPanel
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(NicknameModule)
end

return NicknameModule