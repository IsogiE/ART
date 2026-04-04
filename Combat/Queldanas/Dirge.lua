local addonName, NS = ...
if not ACT then return end

local DeathDirge = {}
ACT.DeathDirgeAssignments = DeathDirge

ACT.RegisteredMechanics = ACT.RegisteredMechanics or {}
table.insert(ACT.RegisteredMechanics, {
    raid = "March on Quel'Danas",
    id = "death_dirge_assignments",
    name = "Death Dirge Assignments",
    module = DeathDirge
})

local LEM = LibStub and LibStub("LibEditMode", true)

local DEBUG_MODE = false
local ENCOUNTER_ID = 3183

local RUNE_TEX_COORDS = {
    {0.000, 0.208, 0.28, 0.72}, -- 1
    {0.204, 0.410, 0.28, 0.72}, -- 2
    {0.385, 0.592, 0.28, 0.72}, -- 3
    {0.581, 0.788, 0.28, 0.72}, -- 4
    {0.784, 0.973, 0.28, 0.72}, -- 5
}

local SQUAD_POSITIONS = {
    { point = "CENTER", x = 28, y = 38 },   -- #1 Top Right
    { point = "CENTER", x = 46, y = -4 },   -- #2 3pm
    { point = "CENTER", x = 0, y = -48 },   -- #3 6pm
    { point = "CENTER", x = -46, y = -4 },  -- #4 9pm
    { point = "CENTER", x = -28, y = 38 },  -- #5 Top Left
}

local shapeNames = {"4", "6", "7", "2", "3"}

local chatmsgs = {
    ["2"] = "26:105:297:373",
    ["3"] = "6:124:383:501",
    ["4"] = "19:113:4:88",
    ["6"] = "6:121:86:201",
    ["7"] = "14:120:207:288",
}

local inEncounter = false
local dirgeCastCount = 1

local function GetConfig()
    local db = ACT.db.profile
    db.death_dirge_assignments = db.death_dirge_assignments or {}
    local cfg = db.death_dirge_assignments

    cfg.enabled = cfg.enabled == nil and false or cfg.enabled

    cfg.pos_buttons = cfg.pos_buttons or {}
    cfg.pos_squad = cfg.pos_squad or {}
    cfg.pos_bar = cfg.pos_bar or {}

    cfg.scale_buttons = cfg.scale_buttons or {}
    cfg.scale_squad = cfg.scale_squad or {}
    cfg.scale_bar = cfg.scale_bar or {}

    cfg.button_order = cfg.button_order or {}
    cfg.show_buttons = cfg.show_buttons or {}

    cfg.ttsEnabled = cfg.ttsEnabled == nil and false or cfg.ttsEnabled
    cfg.ttsVoice = cfg.ttsVoice or 0

    return cfg
end

local buttonsAnchor = CreateFrame("Frame", "ACT_DeathDirge_ButtonsAnchor", UIParent)
buttonsAnchor:SetSize(220, 40)
buttonsAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -150)

local buttonsContent = CreateFrame("Frame", nil, buttonsAnchor)
buttonsContent:SetAllPoints()
buttonsContent:Hide()

local secureAnchor = CreateFrame("Frame", "ACT_DeathDirge_SecureAnchor", UIParent)
secureAnchor:SetSize(220, 40)
secureAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
secureAnchor:Hide()

hooksecurefunc(buttonsAnchor, "ClearAllPoints", function()
    if not InCombatLockdown() then secureAnchor:ClearAllPoints() end
end)
hooksecurefunc(buttonsAnchor, "SetPoint", function(self, ...)
    if not InCombatLockdown() then secureAnchor:SetPoint(...) end
end)

local buttonBGs = {}
local secureButtons = {}

for i = 1, 5 do
    local bg = CreateFrame("Frame", nil, buttonsContent)
    bg:SetSize(40, 40)
    bg:SetPoint("LEFT", buttonsContent, "LEFT", (i - 1) * 45, 0)

    local border = bg:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.3, 0.3, 0.3, 1)

    local inner = bg:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    inner:SetColorTexture(0, 0, 0, 1)

    local tex = bg:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -4)
    tex:SetPoint("BOTTOMRIGHT", -7, 4)
    tex:SetTexture("Interface\\AddOns\\ACT\\media\\Runes.png")
    tex:SetTexCoord(unpack(RUNE_TEX_COORDS[i]))

    buttonBGs[i] = bg

    local btn = CreateFrame("Button", "ACT_DeathDirge_Btn" .. i, secureAnchor, "SecureActionButtonTemplate")
    btn:SetSize(40, 40)
    btn:SetPoint("LEFT", secureAnchor, "LEFT", (i - 1) * 45, 0)
    
    local chatChannel = DEBUG_MODE and "/s " or "/raid "
    
    btn:SetAttribute("type1", "macro")
    btn:SetAttribute("macrotext1", chatChannel .. chatmsgs[shapeNames[i]])
    btn:SetAttribute("useOnKeyDown", false)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(10)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.3)
    hl:SetBlendMode("ADD")

    secureButtons[i] = btn
end
DeathDirge.ButtonsFrame = buttonsAnchor

local squadAnchor = CreateFrame("Frame", "ACT_DeathDirge_SquadAnchor", UIParent)
squadAnchor:SetSize(140, 140)
squadAnchor:SetPoint("CENTER", UIParent, "CENTER", -200, 50)

local squadFrame = CreateFrame("Frame", nil, squadAnchor, "BackdropTemplate")
squadFrame:SetAllPoints()
squadFrame:Hide()
squadFrame.backdropInfo = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}
squadFrame:ApplyBackdrop()
squadFrame:SetBackdropColor(0, 0, 0, 0.8)

local redCircle = squadFrame:CreateTexture(nil, "ARTWORK")
redCircle:SetColorTexture(0.9, 0, 0, 1)
redCircle:SetSize(40, 40)
redCircle:SetPoint("CENTER", squadFrame, "CENTER", 0, -4)

local mask = squadFrame:CreateMaskTexture()
mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
mask:SetAllPoints(redCircle)
redCircle:AddMaskTexture(mask)

local tankIcon = squadFrame:CreateTexture(nil, "OVERLAY")
tankIcon:SetAtlas("groupfinder-icon-role-large-tank")
tankIcon:SetSize(30, 30)
tankIcon:SetPoint("CENTER", redCircle, "TOP", 0, 0)

local squadArrow = squadFrame:CreateTexture(nil, "OVERLAY")
squadArrow:SetSize(32, 32)
squadArrow:SetPoint("TOP", squadFrame, "TOP", 0, -4)
squadArrow:Hide()

local squadDisplay = {}
for i = 1, 5 do
    local fs = squadFrame:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 12)
    fs:SetPoint(SQUAD_POSITIONS[i].point, squadFrame, SQUAD_POSITIONS[i].point, SQUAD_POSITIONS[i].x, SQUAD_POSITIONS[i].y)
    fs:SetSize(32, 32)
    fs:Hide()
    squadDisplay[i] = fs
end
DeathDirge.SquadFrame = squadFrame

local barAnchor = CreateFrame("Frame", "ACT_DeathDirge_BarAnchor", UIParent)
barAnchor:SetSize(200, 50)
barAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 50)

local barFrame = CreateFrame("Frame", nil, barAnchor, "BackdropTemplate")
barFrame:SetAllPoints()
barFrame:Hide()
barFrame.backdropInfo = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}
barFrame:ApplyBackdrop()
barFrame:SetBackdropColor(0, 0, 0, 0.8)

local barDisplay = {}
for i = 1, 5 do
    local fs = barFrame:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 12)
    fs:SetPoint("LEFT", barFrame, "LEFT", 10 + (i - 1) * 36, 0)
    fs:SetSize(32, 32)
    fs:Hide()
    barDisplay[i] = fs
end
DeathDirge.BarFrame = barFrame

local function ApplyLayoutConfig(layoutName)
    local db = GetConfig()
    layoutName = layoutName or "Modern"

    local btnScale = db.scale_buttons[layoutName] or 1
    buttonsAnchor:SetScale(btnScale)
    
    if not InCombatLockdown() then
        secureAnchor:SetScale(btnScale)
    end

    squadAnchor:SetScale(db.scale_squad[layoutName] or 1)
    barAnchor:SetScale(db.scale_bar[layoutName] or 1)

    local order = db.button_order[layoutName] or {1, 2, 3, 4, 5}
    for j = 1, 5 do
        buttonBGs[j]:ClearAllPoints()
        buttonBGs[j]:SetPoint("LEFT", buttonsContent, "LEFT", (order[j] - 1) * 45, 0)
        
        if not InCombatLockdown() then
            secureButtons[j]:ClearAllPoints()
            secureButtons[j]:SetPoint("LEFT", secureAnchor, "LEFT", (order[j] - 1) * 45, 0)
        end
    end

    local show = db.show_buttons[layoutName]
    if show == nil then show = true end
    if LEM and LEM:IsInEditMode() then
        local a = show and 1 or 0.4
        buttonsContent:SetAlpha(a)
    else
        buttonsContent:SetAlpha(1)
    end

    local pBtn = db.pos_buttons[layoutName]
    if pBtn then 
        buttonsAnchor:ClearAllPoints()
        buttonsAnchor:SetPoint(pBtn.point, UIParent, pBtn.point, pBtn.x, pBtn.y)
    end

    local pSq = db.pos_squad[layoutName]
    if pSq then squadAnchor:ClearAllPoints(); squadAnchor:SetPoint(pSq.point, UIParent, pSq.point, pSq.x, pSq.y) end

    local pBar = db.pos_bar[layoutName]
    if pBar then barAnchor:ClearAllPoints(); barAnchor:SetPoint(pBar.point, UIParent, pBar.point, pBar.x, pBar.y) end
end

local ttsTicker = nil

local function PlaySafeTTS(text)
    local cfg = GetConfig()
    if not cfg.ttsEnabled then return end
    if not (C_VoiceChat and C_VoiceChat.SpeakText) then return end

    local targetVoiceID = tonumber(cfg.ttsVoice) or 0
    local validVoice = false
    local voices = C_VoiceChat.GetTtsVoices()
    
    if voices then
        for _, voice in ipairs(voices) do
            if voice.voiceID == targetVoiceID then
                validVoice = true
                break
            end
        end
    end

    if not validVoice then targetVoiceID = 0 end

    local rate = (C_TTSSettings and C_TTSSettings.GetSpeechRate()) or 0
    C_VoiceChat.SpeakText(targetVoiceID, text, rate, 100, false)
end

local function StopTTS()
    if ttsTicker then
        ttsTicker:Cancel()
        ttsTicker = nil
    end
end

local function StartTTSSequence()
    StopTTS()
    local ttsStep = 2
    
    ttsTicker = C_Timer.NewTicker(2, function()
        PlaySafeTTS(tostring(ttsStep))
        ttsStep = ttsStep + 1
    end, 4)
end

local currentSequence = 0
local hideTimer = nil

local function UpdateDirectionArrow()
    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID == 16 or DEBUG_MODE then
        if dirgeCastCount % 2 == 0 then
            squadArrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
            for i = 1, 5 do
                local rev = 6 - i 
                squadDisplay[i]:ClearAllPoints()
                squadDisplay[i]:SetPoint(SQUAD_POSITIONS[rev].point, squadFrame, SQUAD_POSITIONS[rev].point, SQUAD_POSITIONS[rev].x, SQUAD_POSITIONS[rev].y)
            end
        else
            squadArrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
            for i = 1, 5 do
                squadDisplay[i]:ClearAllPoints()
                squadDisplay[i]:SetPoint(SQUAD_POSITIONS[i].point, squadFrame, SQUAD_POSITIONS[i].point, SQUAD_POSITIONS[i].x, SQUAD_POSITIONS[i].y)
            end
        end
        squadArrow:Show()
    else
        squadArrow:Hide()
        for i = 1, 5 do
            squadDisplay[i]:ClearAllPoints()
            squadDisplay[i]:SetPoint(SQUAD_POSITIONS[i].point, squadFrame, SQUAD_POSITIONS[i].point, SQUAD_POSITIONS[i].x, SQUAD_POSITIONS[i].y)
        end
    end
end

local function HideAllRunes()
    for i = 1, 5 do
        squadDisplay[i]:Hide()
        barDisplay[i]:Hide()
    end
    
    if currentSequence > 0 and inEncounter then
        dirgeCastCount = dirgeCastCount + 1
        UpdateDirectionArrow()
    end
    
    currentSequence = 0
    squadFrame:Hide()
    barFrame:Hide()
    StopTTS()
end

local encounterFrame = CreateFrame("Frame")

encounterFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID = ...
        if encounterID == ENCOUNTER_ID or DEBUG_MODE then
            inEncounter = true
            currentSequence = 0
            dirgeCastCount = 1
            hideTimer = nil
            StopTTS()
            UpdateDirectionArrow()

            C_Timer.After(0, function()
                for i = 1, 5 do
                    squadDisplay[i]:Hide()
                    barDisplay[i]:Hide()
                end
                squadFrame:Hide()
                barFrame:Hide()
                
                buttonsContent:Show() 
            end)
        end

    elseif event == "ENCOUNTER_END" then
        if not DEBUG_MODE then
            inEncounter = false
            StopTTS()
            C_Timer.After(0, function()
                buttonsContent:Hide()
                HideAllRunes()
            end)
        end
    end
end)

local chatListenerFrame = CreateFrame("Frame")

chatListenerFrame:SetScript("OnEvent", function(self, event, msg)
    if not inEncounter then return end
    if currentSequence >= 5 then return end

    currentSequence = currentSequence + 1
    local pos = currentSequence

    if pos == 1 then
        StartTTSSequence()
    end

    C_Timer.After(0, function()
        squadDisplay[pos]:SetFormattedText("%s%s%s", "|T7412681:28:28:0:0:512:512:", msg, "|t")
        squadDisplay[pos]:Show()
        squadFrame:Show()

        barDisplay[pos]:SetFormattedText("%s%s%s", "|T7412681:24:24:0:0:512:512:", msg, "|t")
        barDisplay[pos]:Show()
        barFrame:Show()

        if pos == 1 then
            if hideTimer then hideTimer:Cancel() end
            hideTimer = C_Timer.NewTimer(15, HideAllRunes)
        end
    end)
end)

function DeathDirge:UpdateState()
    if InCombatLockdown() then
        encounterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local db = GetConfig()
    encounterFrame:UnregisterAllEvents()
    chatListenerFrame:UnregisterAllEvents()

    if db.enabled then
        chatListenerFrame:RegisterEvent("CHAT_MSG_RAID")
        chatListenerFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
        if DEBUG_MODE then
            chatListenerFrame:RegisterEvent("CHAT_MSG_SAY")
        end

        encounterFrame:RegisterEvent("ENCOUNTER_START")
        encounterFrame:RegisterEvent("ENCOUNTER_END")
        
        if DEBUG_MODE then
            RegisterStateDriver(secureAnchor, "visibility", "show")
        else
            RegisterStateDriver(secureAnchor, "visibility", "[combat] show; hide")
        end

        if LEM and not buttonsAnchor.editModeRegistered then
            LEM:AddFrame(buttonsAnchor, function(f, layout, point, x, y)
                GetConfig().pos_buttons[layout] = { point = point, x = x, y = y }
            end, { point = "CENTER", x = 0, y = -150 }, "Dirge Buttons")

            LEM:AddFrame(squadAnchor, function(f, layout, point, x, y)
                GetConfig().pos_squad[layout] = { point = point, x = x, y = y }
            end, { point = "CENTER", x = -200, y = 50 }, "Dirge Squad")

            LEM:AddFrame(barAnchor, function(f, layout, point, x, y)
                GetConfig().pos_bar[layout] = { point = point, x = x, y = y }
            end, { point = "CENTER", x = 0, y = 50 }, "Dirge Bar")

            local ttsVals = {}
            if C_VoiceChat and C_VoiceChat.GetTtsVoices then
                local voices = C_VoiceChat.GetTtsVoices()
                if voices then
                    for _, voice in ipairs(voices) do
                        table.insert(ttsVals, { text = voice.name, value = voice.voiceID })
                    end
                end
            end
            if #ttsVals == 0 then
                table.insert(ttsVals, { text = "Default System Voice", value = 0 })
            end

            local buttonsSettings = {
                {
                    kind = LEM.SettingType.Checkbox,
                    name = "Show buttons",
                    get = function(layout)
                        local val = GetConfig().show_buttons[layout]
                        return val == nil and true or val
                    end,
                    set = function(layout, val)
                        GetConfig().show_buttons[layout] = val
                        local a = (LEM:IsInEditMode() and not val) and 0.4 or 1
                        buttonsContent:SetAlpha(a)
                    end
                },
                {
                    kind = LEM.SettingType.Slider,
                    name = "Scale",
                    minValue = 50, maxValue = 200, valueStep = 1,
                    get = function(layout) return (GetConfig().scale_buttons[layout] or 1) * 100 end,
                    set = function(layout, val)
                        local scale = val / 100
                        GetConfig().scale_buttons[layout] = scale
                        buttonsAnchor:SetScale(scale)
                        
                        if not InCombatLockdown() then
                            secureAnchor:SetScale(scale)
                        end
                    end
                },
                {
                    kind = LEM.SettingType.Divider,
                    name = "Button Order"
                }
            }

            for i = 1, 5 do
                table.insert(buttonsSettings, {
                    kind = LEM.SettingType.Slider,
                    name = shapeNames[i] .. " Position",
                    minValue = 1, maxValue = 5, valueStep = 1,
                    get = function(layout)
                        local order = GetConfig().button_order[layout]
                        return order and order[i] or i
                    end,
                    set = function(layout, val)
                        local order = GetConfig().button_order[layout]
                        if not order then
                            order = {1, 2, 3, 4, 5}
                            GetConfig().button_order[layout] = order
                        end

                        local oldPos = order[i]
                        for j = 1, 5 do
                            if order[j] == val and j ~= i then
                                order[j] = oldPos
                                break
                            end
                        end
                        order[i] = val

                        for j = 1, 5 do
                            buttonBGs[j]:ClearAllPoints()
                            buttonBGs[j]:SetPoint("LEFT", buttonsContent, "LEFT", (order[j] - 1) * 45, 0)
                            
                            if not InCombatLockdown() then
                                secureButtons[j]:ClearAllPoints()
                                secureButtons[j]:SetPoint("LEFT", secureAnchor, "LEFT", (order[j] - 1) * 45, 0)
                            end
                        end
                    end
                })
            end

            LEM:AddFrameSettings(buttonsAnchor, buttonsSettings)

            LEM:AddFrameSettings(squadAnchor, {
                {
                    kind = LEM.SettingType.Slider,
                    name = "Scale",
                    minValue = 50, maxValue = 200, valueStep = 1,
                    get = function(layout) return (GetConfig().scale_squad[layout] or 1) * 100 end,
                    set = function(layout, val)
                        local scale = val / 100
                        GetConfig().scale_squad[layout] = scale
                        squadAnchor:SetScale(scale)
                    end
                },
                {
                    kind = LEM.SettingType.Divider,
                    name = "Audio Cues"
                },
                {
                    kind = LEM.SettingType.Checkbox,
                    name = "Enable TTS Countdown",
                    get = function(layout) return GetConfig().ttsEnabled end,
                    set = function(layout, val) GetConfig().ttsEnabled = val end
                },
                { 
                    kind = LEM.SettingType.Dropdown, 
                    name = "TTS Voice", 
                    values = ttsVals,
                    hidden = function(layout) return not GetConfig().ttsEnabled end, 
                    get = function(layout) return GetConfig().ttsVoice or 0 end, 
                    set = function(layout, val) 
                        local numericVoiceID = tonumber(val) or 0
                        GetConfig().ttsVoice = numericVoiceID
                        
                        if C_VoiceChat and C_VoiceChat.SpeakText then
                            local rate = C_TTSSettings and C_TTSSettings.GetSpeechRate() or 0
                            local volume = C_TTSSettings and C_TTSSettings.GetSpeechVolume() or 100
                            C_VoiceChat.SpeakText(numericVoiceID, "Voice test", rate, volume, false)
                        end
                    end 
                }
            })

            LEM:AddFrameSettings(barAnchor, {
                {
                    kind = LEM.SettingType.Slider,
                    name = "Scale",
                    minValue = 50, maxValue = 200, valueStep = 1,
                    get = function(layout) return (GetConfig().scale_bar[layout] or 1) * 100 end,
                    set = function(layout, val)
                        local scale = val / 100
                        GetConfig().scale_bar[layout] = scale
                        barAnchor:SetScale(scale)
                    end
                }
            })

            LEM:RegisterCallback("layout", function(layoutName)
                ApplyLayoutConfig(layoutName)
            end)

            buttonsAnchor.editModeRegistered = true
        end

        if LEM and LEM.GetActiveLayoutName then
            ApplyLayoutConfig(LEM:GetActiveLayoutName())
        end

        if DEBUG_MODE then
            inEncounter = true
            currentSequence = 0
            buttonsContent:Show()
            UpdateDirectionArrow()
        end
    else
        chatListenerFrame:UnregisterAllEvents()
        inEncounter = false
        buttonsContent:Hide()
        squadFrame:Hide()
        barFrame:Hide()
        StopTTS()
        
        UnregisterStateDriver(secureAnchor, "visibility")
        secureAnchor:Hide()
        
        for i = 1, 5 do
            squadDisplay[i]:Hide()
            barDisplay[i]:Hide()
        end
    end
end

function DeathDirge:Initialize()
    if LEM then
        LEM:RegisterCallback("enter", function()
            if not GetConfig().enabled then return end

            local layout = LEM:GetActiveLayoutName()
            local show = GetConfig().show_buttons[layout]
            if show == nil then show = true end

            buttonsContent:Show()
            
            local a = show and 1 or 0.4
            buttonsContent:SetAlpha(a)
            
            squadFrame:Show()
            barFrame:Show()
            
            squadArrow:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
            squadArrow:Show()

            for i = 1, 5 do
                local msg = chatmsgs[shapeNames[i]]
                squadDisplay[i]:SetFormattedText("%s%s%s", "|T7412681:28:28:0:0:512:512:", msg, "|t")
                squadDisplay[i]:Show()
                barDisplay[i]:SetFormattedText("%s%s%s", "|T7412681:24:24:0:0:512:512:", msg, "|t")
                barDisplay[i]:Show()
            end
        end)

        LEM:RegisterCallback("exit", function()
            buttonsContent:SetAlpha(1)
            UpdateDirectionArrow()
            
            if not GetConfig().enabled then return end

            if not inEncounter then
                buttonsContent:Hide()
                squadFrame:Hide()
                barFrame:Hide()
                for i = 1, 5 do
                    squadDisplay[i]:Hide()
                    barDisplay[i]:Hide()
                end
            else
                if currentSequence == 0 then
                    squadFrame:Hide()
                    barFrame:Hide()
                    for i = 1, 5 do
                        squadDisplay[i]:Hide()
                        barDisplay[i]:Hide()
                    end
                else
                    for i = currentSequence + 1, 5 do
                        squadDisplay[i]:Hide()
                        barDisplay[i]:Hide()
                    end
                end
            end
        end)
    end

    self:UpdateState()
end

if ACT.db and ACT.db.profile then
    DeathDirge:Initialize()
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(self)
        DeathDirge:Initialize()
        self:UnregisterAllEvents()
    end)
end