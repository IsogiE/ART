local BossModsModule = {}

BossModsModule.title = "Boss Mods"
BossModsModule.isInitialized = false

local addonName = ...

if not ACT then return end

ACT.BossMods = BossModsModule

ACT.RegisteredMechanics = ACT.RegisteredMechanics or {}

local function InitializeDatabase()
    if not ACT.db or not ACT.db.profile then return end

    local profile = ACT.db.profile
    
    if not profile.combat_timer then profile.combat_timer = { enabled = false } end
    if not profile.general_pack then profile.general_pack = { enabled = false } end
    if not profile.hot_tracker then profile.hot_tracker = { enabled = false } end
    
    if not profile.selected_raid then profile.selected_raid = "The Voidspire" end

    for _, mech in ipairs(ACT.RegisteredMechanics) do
        if not profile[mech.id] then profile[mech.id] = { enabled = false } end
    end

    BossModsModule.isInitialized = true

    local modules = {
        { ref = ACT.CombatTimer, key = "CombatTimer" },
        { ref = ACT.GeneralPack, key = "GeneralPack" },
        { ref = ACT.HotTracker, key = "HotTracker" },
    }

    for _, mod in ipairs(modules) do
        if mod.ref then
            if mod.ref.Initialize then mod.ref:Initialize() end
            if mod.ref.UpdateState then mod.ref:UpdateState() end
        end
    end

    for _, mech in ipairs(ACT.RegisteredMechanics) do
        if mech.module then
            if mech.module.Initialize then mech.module:Initialize() end
            if mech.module.UpdateState then mech.module:UpdateState() end
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
            if ACT.db and ACT.db.profile then InitializeDatabase() end
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end)
end

function BossModsModule:GetConfigSize() return 800, 600 end

local function CreateCheckButton(parent, label, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    check.Text = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    check.Text:SetText(label)
    check.Text:SetPoint("LEFT", check, "RIGHT", 5, 0)
    check:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        self.Text:SetTextColor(checked and 1 or 0.5, checked and 0.82 or 0.5, checked and 0 or 0.5)
        if onClick then onClick(checked) end
    end)
    return check
end

function BossModsModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        return self.configPanel
    end

    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetAllPoints(parent)
    self.configPanel = configPanel

    local windowTitle = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    windowTitle:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    windowTitle:SetText(self.title)

    local generalLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    generalLabel:SetPoint("TOPLEFT", windowTitle, "BOTTOMLEFT", 0, -25)
    generalLabel:SetText("General")

    local hotTrackerCheck = CreateCheckButton(configPanel, "Healer HoTs", function(checked)
        ACT.db.profile.hot_tracker.enabled = checked
        if ACT.HotTracker and ACT.HotTracker.UpdateState then ACT.HotTracker:UpdateState() end
    end)
    hotTrackerCheck:SetPoint("TOPLEFT", generalLabel, "BOTTOMLEFT", 0, -10)

    local combatTimerCheck = CreateCheckButton(configPanel, "Combat Timer", function(checked)
        ACT.db.profile.combat_timer.enabled = checked
        if ACT.CombatTimer and ACT.CombatTimer.UpdateState then ACT.CombatTimer:UpdateState() end
    end)
    combatTimerCheck:SetPoint("TOPLEFT", hotTrackerCheck, "BOTTOMLEFT", 0, -5)

    local generalPackCheck = CreateCheckButton(configPanel, "General WA Replacement", function(checked)
        ACT.db.profile.general_pack.enabled = checked
        if ACT.GeneralPack and ACT.GeneralPack.UpdateState then ACT.GeneralPack:UpdateState() end
    end)
    generalPackCheck:SetPoint("TOPLEFT", combatTimerCheck, "BOTTOMLEFT", 0, -5)

    local divider = configPanel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.2)
    divider:SetHeight(1)
    divider:SetPoint("TOP", generalPackCheck, "BOTTOM", 0, -10)
    divider:SetPoint("LEFT", configPanel, "LEFT", 20, 0)
    divider:SetPoint("RIGHT", configPanel, "RIGHT", -255, 0)

    local bossMechanicsLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bossMechanicsLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -10)
    bossMechanicsLabel:SetText("Boss Mechanics")

    local dynamicRaidMechanics = {}
    for _, mech in ipairs(ACT.RegisteredMechanics) do
        if not dynamicRaidMechanics[mech.raid] then
            dynamicRaidMechanics[mech.raid] = {}
        end
        table.insert(dynamicRaidMechanics[mech.raid], mech)
    end

    local dropDown = UI:CreateDropdown(configPanel, 200, 24)
    dropDown:SetPoint("TOPLEFT", bossMechanicsLabel, "BOTTOMLEFT", 0, -10)

    local activeCheckboxes = {}
    local checkboxPool = {}

    function configPanel:RefreshMechanics()
        for _, cb in ipairs(activeCheckboxes) do cb:Hide() end
        wipe(activeCheckboxes)

        local selectedRaid = ACT.db.profile.selected_raid or "The Voidspire"
        dropDown.button.text:SetText(selectedRaid)

        local mechanics = dynamicRaidMechanics[selectedRaid] or {}
        local startAnchor = dropDown
        local firstInCol = nil
        local lastBtn = nil

        for i, mech in ipairs(mechanics) do
            local cb = checkboxPool[i]
            if not cb then
                cb = CreateCheckButton(configPanel, "", nil)
                checkboxPool[i] = cb
            end

            cb.Text:SetText(mech.name)
            
            local isChecked = ACT.db.profile[mech.id] and ACT.db.profile[mech.id].enabled
            cb:SetChecked(isChecked)
            cb.Text:SetTextColor(isChecked and 1 or 0.5, isChecked and 0.82 or 0.5, isChecked and 0 or 0.5)

            cb:SetScript("OnClick", function(self)
                local checked = self:GetChecked()
                self.Text:SetTextColor(checked and 1 or 0.5, checked and 0.82 or 0.5, checked and 0 or 0.5)
                ACT.db.profile[mech.id].enabled = checked
                if mech.module and mech.module.UpdateState then mech.module:UpdateState() end
            end)

            cb:ClearAllPoints()
            if i == 1 then
                cb:SetPoint("TOPLEFT", startAnchor, "BOTTOMLEFT", 0, -10)
                firstInCol = cb
            elseif (i - 1) % 10 == 0 then
                cb:SetPoint("LEFT", firstInCol, "RIGHT", 250, 0)
                firstInCol = cb
            else
                cb:SetPoint("TOPLEFT", lastBtn, "BOTTOMLEFT", 0, -5)
            end
            
            lastBtn = cb
            table.insert(activeCheckboxes, cb)
            cb:Show()
        end
    end

    local dropdownOptions = {}
    
    local sortedRaids = {}
    for raidName in pairs(dynamicRaidMechanics) do table.insert(sortedRaids, raidName) end
    table.sort(sortedRaids)

    for _, raidName in ipairs(sortedRaids) do
        table.insert(dropdownOptions, {
            text = raidName,
            value = raidName,
            onClick = function()
                ACT.db.profile.selected_raid = raidName
                configPanel:RefreshMechanics()
            end
        })
    end
    
    if #dropdownOptions == 0 then
        table.insert(dropdownOptions, { text = "No Raids Loaded", value = "None" })
    end
    
    UI:SetDropdownOptions(dropDown, dropdownOptions)
    
    if not dynamicRaidMechanics[ACT.db.profile.selected_raid] and #dropdownOptions > 0 then
        ACT.db.profile.selected_raid = dropdownOptions[1].value
    end

    configPanel:SetScript("OnShow", function()
        if not BossModsModule.isInitialized then return end
        local profile = ACT.db.profile

        local function UpdateBtn(btn, val)
            btn:SetChecked(val)
            btn.Text:SetTextColor(val and 1 or 0.5, val and 0.82 or 0.5, val and 0 or 0.5)
        end

        UpdateBtn(hotTrackerCheck, profile.hot_tracker.enabled)
        UpdateBtn(combatTimerCheck, profile.combat_timer.enabled)
        UpdateBtn(generalPackCheck, profile.general_pack.enabled)
        
        configPanel:RefreshMechanics()
    end)

    return configPanel
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(BossModsModule)
end

return BossModsModule