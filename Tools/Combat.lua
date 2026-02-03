local addonName, NS = ...

if not ACT then return end

local CombatTimer = {}
ACT.CombatTimer = CombatTimer

local LEM = LibStub("LibEditMode", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

local frame = CreateFrame("Frame", "ACT_CombatTimerFrame", UIParent, "BackdropTemplate")
frame:SetSize(100, 30)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("HIGH")
frame:Hide()

frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
frame.text:SetPoint("CENTER")
frame.text:SetText("0:00")

local function UpdateTimer(self, elapsed)
    self.timer = (self.timer or 0) + elapsed

    if self.timer >= 0.2 then 
        local duration = GetTime() - self.startTime
        local m = math.floor(duration / 60)
        local s = math.floor(duration % 60)
        self.text:SetText(string.format("%d:%02d", m, s))
        
        self.timer = 0
    end
end

local function UpdateVisuals()
    if not ACT.db or not ACT.db.profile or not ACT.db.profile.combat_timer then return end
    local db = ACT.db.profile.combat_timer

    local fontPath
    local fontFace = db.fontFace or "Friz Quadrata TT"
    local fontSize = db.fontSize or 20
    local fontOutline = db.fontOutline or "OUTLINE"
    local fontJustify = db.fontJustify or "CENTER"

    if LSM then
        fontPath = LSM:Fetch("font", fontFace)
    end

    if not fontPath then
        fontPath = "Fonts\\FRIZQT__.TTF" 
    end

    frame.text:SetFont(fontPath, fontSize, fontOutline)
    
    frame.text:ClearAllPoints()
    if fontJustify == "LEFT" then
        frame.text:SetPoint("LEFT", frame, "LEFT", 2, 0)
        frame.text:SetJustifyH("LEFT")
    elseif fontJustify == "RIGHT" then
        frame.text:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
        frame.text:SetJustifyH("RIGHT")
    else
        frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.text:SetJustifyH("CENTER")
    end
end

local function OnEvent(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        self.startTime = GetTime()
        self.text:SetText("0:00")
        self:Show()
        self:SetScript("OnUpdate", UpdateTimer)
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:SetScript("OnUpdate", nil)
        if not (LEM and LEM:IsInEditMode()) then
            self:Hide()
        end
    end
end
frame:SetScript("OnEvent", OnEvent)

local function OnLayoutChanged(frame, layoutName, point, x, y)
    if not ACT.db or not ACT.db.profile or not ACT.db.profile.combat_timer then return end
    
    local db = ACT.db.profile.combat_timer
    db.pos = db.pos or {}
    db.pos[layoutName] = {point = point, x = x, y = y}
end

function CombatTimer:UpdateState()
    if not ACT.db or not ACT.db.profile then return end
    
    if not ACT.db.profile.combat_timer then
        ACT.db.profile.combat_timer = { enabled = false, pos = {} }
    end
    
    local db = ACT.db.profile.combat_timer

    if not db.fontSize then db.fontSize = 20 end
    if not db.fontFace then db.fontFace = "Friz Quadrata TT" end
    if not db.fontOutline then db.fontOutline = "OUTLINE" end
    if not db.fontJustify then db.fontJustify = "CENTER" end

    UpdateVisuals()

    if db.enabled then
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")

        if InCombatLockdown() and not frame:IsShown() then
            frame.startTime = GetTime()
            frame:Show()
            frame:SetScript("OnUpdate", UpdateTimer)
        end
        
        if LEM and LEM:IsInEditMode() then
            frame:Show()
            frame.text:SetText("0:00")
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8", 
                edgeFile = "Interface\\Buttons\\WHITE8x8", 
                edgeSize = 1
            })
            frame:SetBackdropColor(0, 0.5, 0, 0.5)
            frame:SetBackdropBorderColor(0, 1, 0, 1)
        end
    else
        frame:UnregisterAllEvents()
        frame:Hide()
        frame:SetScript("OnUpdate", nil)
    end
    
    if LEM then
        if db.enabled then
            if not frame.editModeRegistered then
                local defaultPos = {point = "CENTER", x = 0, y = 0}
                
                LEM:AddFrame(frame, OnLayoutChanged, defaultPos, "Combat Timer")
                
                local settings = {
                    {
                        kind = LEM.SettingType.Dropdown,
                        name = "Font Face",
                        height = 300,
                        values = (function()
                            local t = {}
                            if LSM then
                                for _, name in ipairs(LSM:List("font")) do
                                    table.insert(t, {text = name, value = name})
                                end
                            else
                                table.insert(t, {text = "Friz Quadrata TT", value = "Friz Quadrata TT"})
                            end
                            return t
                        end)(),
                        get = function() return ACT.db.profile.combat_timer.fontFace end,
                        set = function(_, value) 
                            ACT.db.profile.combat_timer.fontFace = value
                            UpdateVisuals()
                        end
                    },
                    {
                        kind = LEM.SettingType.Slider,
                        name = "Font Size",
                        minValue = 8, 
                        maxValue = 40,
                        valueStep = 1,
                        get = function() return ACT.db.profile.combat_timer.fontSize end,
                        set = function(_, value)
                            ACT.db.profile.combat_timer.fontSize = value
                            UpdateVisuals()
                        end
                    },
                    {
                        kind = LEM.SettingType.Dropdown,
                        name = "Font Outline",
                        values = {
                            {text = "None", value = ""},
                            {text = "Outline", value = "OUTLINE"},
                            {text = "Thick Outline", value = "THICKOUTLINE"},
                            {text = "Monochrome", value = "MONOCHROME"},
                        },
                        get = function() return ACT.db.profile.combat_timer.fontOutline end,
                        set = function(_, value)
                           ACT.db.profile.combat_timer.fontOutline = value
                           UpdateVisuals()
                        end
                    },
                    {
                        kind = LEM.SettingType.Dropdown,
                        name = "Text Justification",
                        values = {
                            {text = "Left", value = "LEFT"},
                            {text = "Center", value = "CENTER"},
                            {text = "Right", value = "RIGHT"},
                        },
                        get = function() return ACT.db.profile.combat_timer.fontJustify end,
                        set = function(_, value)
                           ACT.db.profile.combat_timer.fontJustify = value
                           UpdateVisuals()
                        end
                    }
                }

                LEM:AddFrameSettings(frame, settings)
                
                frame.editModeRegistered = true
                
                if LEM.GetActiveLayoutName then
                    local layout = LEM:GetActiveLayoutName()
                    local pos = db.pos and db.pos[layout]
                    if pos then
                         frame:ClearAllPoints()
                         frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
                    end
                end
            end
        else
            if frame.editModeRegistered and LEM.frameSelections[frame] then
                LEM.frameSelections[frame]:Hide()
            end
        end
    end
end

function CombatTimer:Initialize()
    self:UpdateState()

    if LEM then
        LEM:RegisterCallback("enter", function()
            local db = ACT.db and ACT.db.profile and ACT.db.profile.combat_timer
            if db and db.enabled then
                frame:Show()
                frame.text:SetText("0:00")
                frame:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8", 
                    edgeFile = "Interface\\Buttons\\WHITE8x8", 
                    edgeSize = 1
                })
                frame:SetBackdropColor(0, 0.5, 0, 0.5)
                frame:SetBackdropBorderColor(0, 1, 0, 1)
            end
        end)

        LEM:RegisterCallback("exit", function()
            frame:SetBackdrop(nil)
            frame:SetBackdropColor(0, 0, 0, 0)
            frame:SetBackdropBorderColor(0, 0, 0, 0)
            
            if not InCombatLockdown() then
                frame:Hide()
            end
        end)
        
        LEM:RegisterCallback("layout", function(layoutName)
            local db = ACT.db and ACT.db.profile and ACT.db.profile.combat_timer
            if not db or not db.enabled then return end
            
            local pos = db.pos and db.pos[layoutName]
            if pos then
                frame:ClearAllPoints()
                frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
            else
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        end)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    if ACT.db and ACT.db.profile then
        CombatTimer:Initialize()
    end
end)