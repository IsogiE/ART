local NicknameModule = {}

NicknameModule.title = "Utility"
NicknameModule.isInitialized = false

local addonName = ...

if not ACT then return end

ACT.Nicknames = NicknameModule

local initializedNicknames = {}
local nicknameToCharacterCache = {}
local addOnNameToCheckButton = {}
local InitializeIntegrations

StaticPopupDialogs["ACT_UTILITY_RELOAD"] = {
    text = "Changing this setting requires a UI Reload to take full effect.\nDo you want to reload now?",
    button1 = YES,
    button2 = NO,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function RealmIncludedName(unit)
    local name, realm = UnitNameUnmodified(unit)
    if (name and issecretvalue(name)) or (realm and issecretvalue(realm)) then return nil end
    if not realm or realm == "" then realm = GetRealmName() end
    if not realm then return end
    return string.format("%s-%s", name, realm)
end

local function InitializeDatabase()
    if not ACT.db or not ACT.db.profile then return end

    local profile = ACT.db.profile
    profile.nicknames = profile.nicknames or {}
    profile.nickname_integrations = profile.nickname_integrations or {}
    
    if not profile.bcm_settings then
        profile.bcm_settings = { essential_centering = false, utility_centering = false }
    end
    if profile.bcm_settings.utility_centering == nil then profile.bcm_settings.utility_centering = false end

    if not profile.whisper_settings then profile.whisper_settings = { enabled = false } end
    if not profile.cdm_settings then profile.cdm_settings = { global_ignore_aura_override = false } end
    if not profile.combat_timer then profile.combat_timer = { enabled = false } end
    if not profile.general_pack then profile.general_pack = { enabled = false } end

    local db = profile.nicknames
    local playerRealmName = RealmIncludedName("player")
    local currentPlayerNickname = profile.nickname

    if playerRealmName and currentPlayerNickname then
        db[playerRealmName] = currentPlayerNickname
    end

    ACT_CharacterDB = { nicknames = db }
    ACT_AccountDB = { nickname_integrations = profile.nickname_integrations }
    NicknameModule.isInitialized = true

    InitializeIntegrations()

    if ACT.BCM and ACT.BCM.UpdateState then ACT.BCM:UpdateState() end
    if ACT.WhisperNotify and ACT.WhisperNotify.UpdateState then ACT.WhisperNotify:UpdateState() end
    
    if ACT.AuraOverride then
        if ACT.AuraOverride.Initialize then ACT.AuraOverride:Initialize() end
        if ACT.AuraOverride.UpdateState then ACT.AuraOverride:UpdateState() end
    end

    if ACT.CombatTimer then
        if ACT.CombatTimer.Initialize then ACT.CombatTimer:Initialize() end
        if ACT.CombatTimer.UpdateState then ACT.CombatTimer:UpdateState() end
    end

    if ACT.GeneralPack then
        if ACT.GeneralPack.Initialize then ACT.GeneralPack:Initialize() end
        if ACT.GeneralPack.UpdateState then ACT.GeneralPack:UpdateState() end
    end
end

if ACT.db and ACT.db.profile then
    InitializeDatabase()
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGIN" then
            if ACT.db and ACT.db.profile then InitializeDatabase() end
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end)
end

NicknameModule.nicknameFunctions = {}

function InitializeIntegrations()
    if not NicknameModule.isInitialized then return end
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
    if not NicknameModule.isInitialized or not ACT.db.profile.nicknames then return end
    local db = ACT.db.profile.nicknames
    local realmIncludedName = RealmIncludedName(unit)
    if not realmIncludedName then return end

    nickname = nickname and strtrim(nickname)
    if nickname == "" then nickname = nil end

    local oldNickname = db[realmIncludedName]
    if oldNickname == nickname then return end

    if unit == "player" then ACT.db.profile.nickname = nickname end
    db[realmIncludedName] = nickname

    if oldNickname then nicknameToCharacterCache[oldNickname] = nil end
    if nickname then nicknameToCharacterCache[nickname] = unit end

    for _, functions in pairs(self.nicknameFunctions) do
        if functions.Update then
            functions.Update(unit, realmIncludedName, oldNickname, nickname)
        end
    end
end

function ACT:HasNickname(unit)
    if not NicknameModule.isInitialized or not ACT.db.profile.nicknames then return false end
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
    local realmIncludedName = RealmIncludedName(unit)
    return realmIncludedName and ACT.db.profile.nicknames[realmIncludedName] ~= nil
end

function ACT:GetNickname(unit)
    return ACT:GetRawNickname(unit)
end

function ACT:GetRawNickname(unit)
    if not NicknameModule.isInitialized or not ACT.db.profile.nicknames then return UnitNameUnmodified(unit) end
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return UnitNameUnmodified(unit) end
    local realmIncludedName = RealmIncludedName(unit)
    return (realmIncludedName and ACT.db.profile.nicknames[realmIncludedName]) or UnitNameUnmodified(unit)
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

local integrationInitFrame = CreateFrame("Frame")
integrationInitFrame:RegisterEvent("ADDON_LOADED")
integrationInitFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if NicknameModule.isInitialized and loadedAddon ~= addonName then
        InitializeIntegrations()
    end
end)

function NicknameModule:GetConfigSize() return 800, 600 end

local function CreateCheckButton(parent, label, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    check.Text = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    check.Text:SetText(label)
    check.Text:SetPoint("LEFT", check, "RIGHT", 5, 0)
    check:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if checked then
            self.Text:SetTextColor(1, 0.82, 0)
        else
            self.Text:SetTextColor(0.5, 0.5, 0.5)
        end
        if onClick then onClick(checked) end
    end)
    return check
end

function NicknameModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        if self.configPanel.OnShow then self.configPanel:OnShow() end
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

    local integrations = {
        { key = "Blizzard", name = "Blizzard Raid Frames" },
        { key = "Cell", name = "Cell" },
        { key = "DandersFrames", name = "Danders Frames" },
        { key = "ElvUI", name = "ElvUI" },
        { key = "Grid2", name = "Grid2" },
        { key = "UnhaltedUnitFrames", name = "Unhalted Unit Frames" },
        { key = "VuhDo", name = "VuhDo" }
    }

    wipe(addOnNameToCheckButton) 
    local lastCheckButton
    for i, data in ipairs(integrations) do
        local checkButton = CreateCheckButton(configPanel, data.name, function(checked)
            if not NicknameModule.isInitialized or not ACT.db.profile.nickname_integrations then return end
            ACT.db.profile.nickname_integrations[data.key] = checked
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

        if not lastCheckButton then
            checkButton:SetPoint("TOPLEFT", integrationsLabel, "BOTTOMLEFT", 0, -10)
        else
            checkButton:SetPoint("TOPLEFT", lastCheckButton, "BOTTOMLEFT", 0, -5)
        end
        lastCheckButton = checkButton
        addOnNameToCheckButton[data.key] = checkButton
    end
    
    local divider = configPanel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.2)
    divider:SetHeight(1)
    divider:SetPoint("TOP", lastCheckButton, "BOTTOM", 0, -10)
    divider:SetPoint("LEFT", configPanel, "LEFT", 20, 0)
    divider:SetPoint("RIGHT", configPanel, "RIGHT", -255, 0)

    local utilityLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    utilityLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -10)
    utilityLabel:SetText("Utility Settings")

    local bcmCheck = CreateCheckButton(configPanel, "Essential Cooldown Bar Centering", function(checked)
        if not NicknameModule.isInitialized or not ACT.db.profile.bcm_settings then return end
        ACT.db.profile.bcm_settings.essential_centering = checked
        if ACT.BCM and ACT.BCM.UpdateState then ACT.BCM:UpdateState() end
        StaticPopup_Show("ACT_UTILITY_RELOAD")
    end)
    bcmCheck:SetPoint("TOPLEFT", utilityLabel, "BOTTOMLEFT", 0, -10)

    local bcmUtilityCheck = CreateCheckButton(configPanel, "Utility Cooldown Bar Centering", function(checked)
        if not NicknameModule.isInitialized or not ACT.db.profile.bcm_settings then return end
        ACT.db.profile.bcm_settings.utility_centering = checked
        if ACT.BCM and ACT.BCM.UpdateState then ACT.BCM:UpdateState() end
        StaticPopup_Show("ACT_UTILITY_RELOAD")
    end)
    bcmUtilityCheck:SetPoint("TOPLEFT", bcmCheck, "BOTTOMLEFT", 0, -5)

    local whisperCheck = CreateCheckButton(configPanel, "Whisper Sound Notifications (Master Channel)", function(checked)
        if not NicknameModule.isInitialized or not ACT.db.profile.whisper_settings then return end
        ACT.db.profile.whisper_settings.enabled = checked
        if ACT.WhisperNotify and ACT.WhisperNotify.UpdateState then ACT.WhisperNotify:UpdateState() end
    end)
    whisperCheck:SetPoint("TOPLEFT", bcmUtilityCheck, "BOTTOMLEFT", 0, -5)

    local cdmOverrideCheck = CreateCheckButton(configPanel, "Remove Cooldown Manager Aura Duration", function(checked)
        if not NicknameModule.isInitialized or not ACT.db.profile.cdm_settings then return end
        ACT.db.profile.cdm_settings.global_ignore_aura_override = checked
        if ACT.AuraOverride and ACT.AuraOverride.UpdateState then ACT.AuraOverride:UpdateState() end
    end)
    cdmOverrideCheck:SetPoint("TOPLEFT", whisperCheck, "BOTTOMLEFT", 0, -5)

    local combatTimerCheck = CreateCheckButton(configPanel, "Enable Combat Timer", function(checked)
        if not NicknameModule.isInitialized or not ACT.db.profile.combat_timer then return end
        ACT.db.profile.combat_timer.enabled = checked
        if ACT.CombatTimer and ACT.CombatTimer.UpdateState then 
            ACT.CombatTimer:UpdateState() 
        end
    end)
    combatTimerCheck:SetPoint("TOPLEFT", cdmOverrideCheck, "BOTTOMLEFT", 0, -5)

    local generalPackCheck = CreateCheckButton(configPanel, "General WA Pack Replacement", function(checked)
        if not NicknameModule.isInitialized or not ACT.db.profile.general_pack then return end
        ACT.db.profile.general_pack.enabled = checked
        if ACT.GeneralPack and ACT.GeneralPack.UpdateState then 
            ACT.GeneralPack:UpdateState() 
        end
    end)
    generalPackCheck:SetPoint("TOPLEFT", combatTimerCheck, "BOTTOMLEFT", 0, -5)

    configPanel.OnShow = function()
        if not NicknameModule.isInitialized then return end
        local profile = ACT.db.profile

        if configPanel.nicknameEditBox then
            configPanel.nicknameEditBox:SetText(profile.nickname or "")
        end

        for addOnName, checkButton in pairs(addOnNameToCheckButton) do
            local isChecked = profile.nickname_integrations and profile.nickname_integrations[addOnName] or false
            checkButton:SetChecked(isChecked)
            checkButton.Text:SetTextColor(isChecked and 1 or 0.5, isChecked and 0.82 or 0.5, isChecked and 0 or 0.5)
        end
        NicknameModule:UpdateCheckButtons()
        
        local function SetState(btn, val)
            btn:SetChecked(val)
            btn.Text:SetTextColor(val and 1 or 0.5, val and 0.82 or 0.5, val and 0 or 0.5)
        end

        if profile.bcm_settings then
            SetState(bcmCheck, profile.bcm_settings.essential_centering)
            SetState(bcmUtilityCheck, profile.bcm_settings.utility_centering)
        end
        if profile.whisper_settings then
            SetState(whisperCheck, profile.whisper_settings.enabled)
        end
        if profile.cdm_settings then
            SetState(cdmOverrideCheck, profile.cdm_settings.global_ignore_aura_override)
        end
        if profile.combat_timer then
            SetState(combatTimerCheck, profile.combat_timer.enabled)
        end
        if profile.general_pack then
            SetState(generalPackCheck, profile.general_pack.enabled)
        end
    end

    configPanel:SetScript("OnShow", configPanel.OnShow)

    return configPanel
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(NicknameModule)
end

return NicknameModule