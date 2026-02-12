local addonName, NS = ...

if not ACT then return end

local GeneralPack = {}
ACT.GeneralPack = GeneralPack

local LEM = LibStub("LibEditMode", true)
local LSM = LibStub("LibSharedMedia-3.0", true)
local LCG = LibStub("LibCustomGlow-1.0", true)
local LGF = LibStub("LibGetFrame-1.0", true)

local ALERT_COOLDOWNS = {
    ["MakeHS"] = 120,
    ["MakeSummon"] = 120, 
}

local MONITORED_EVENTS = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    "UNIT_PET", "UPDATE_INVENTORY_DURABILITY", "BAG_UPDATE",
    "CHAT_MSG_RAID", "CHAT_MSG_PARTY", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_PARTY_LEADER"
}

local tempAlerts = {}
local lastTriggerTimes = {}
GeneralPack.pendingUpdate = false

local anchor = CreateFrame("Frame", "ACT_GeneralPack_Anchor", UIParent)
anchor:SetSize(200, 30)
anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
anchor:SetFrameStrata("HIGH")
anchor:Show()

local display = CreateFrame("Frame", "ACT_GeneralPack_Display", UIParent, "BackdropTemplate")
display:SetAllPoints(anchor)
display:SetFrameStrata("HIGH")
display:Hide()

display.text = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
display.text:SetPoint("CENTER")

local textFramePool = {}
local function GetTextFrame()
    for _, f in ipairs(textFramePool) do
        if not f:IsShown() then return f end
    end
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(100, 20)
    f:SetFrameStrata("DIALOG") 
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.text:SetPoint("CENTER")
    f.text:SetTextColor(1, 0, 0)
    table.insert(textFramePool, f)
    return f
end

local function GetShortName(name)
    if not name then return "" end
    return string.match(name, "^([^-]+)") or name
end

local function NamesMatch(n1, n2)
    if not n1 or not n2 then return false end
    return GetShortName(n1) == GetShortName(n2)
end

local function GetUnitFrame(targetUnit)
    if not targetUnit then return nil end

    if DandersFrames_GetFrameForUnit then
        local frame = DandersFrames_GetFrameForUnit(targetUnit)
        if frame and frame:IsVisible() then 
            return frame 
        end
    end

    if LGF then
        local frame = LGF.GetUnitFrame(targetUnit)
        if frame and frame:IsVisible() then
            return frame
        end
    end

    for i = 1, 40 do
        local frame = _G["CompactRaidFrame"..i]
        if frame and frame:IsVisible() and frame.unit and UnitIsUnit(frame.unit, targetUnit) then
            return frame
        end
    end

    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember"..i]
        if frame and frame:IsVisible() and frame.unit and UnitIsUnit(frame.unit, targetUnit) then
            return frame
        end
    end

    for i = 1, 4 do
        local frame = _G["PartyMemberFrame"..i]
        if frame and frame:IsVisible() and frame.unit and UnitIsUnit(frame.unit, targetUnit) then
            return frame
        end
    end

    if UnitIsUnit("player", targetUnit) then
        if PlayerFrame and PlayerFrame:IsVisible() then
            return PlayerFrame
        end
    end

    return nil
end

local function UpdateVisuals()
    if not ACT.db or not ACT.db.profile.general_pack then return end
    local db = ACT.db.profile.general_pack

    local fontPath = "Fonts\\FRIZQT__.TTF"
    if LSM and db.fontFace then
        fontPath = LSM:Fetch("font", db.fontFace) or fontPath
    end

    display.text:SetFont(fontPath, db.fontSize or 20, db.fontOutline or "OUTLINE")
    display.text:ClearAllPoints()
    
    local justify = db.fontJustify or "CENTER"
    if justify == "LEFT" then
        display.text:SetPoint("LEFT", display, "LEFT", 2, 0)
    elseif justify == "RIGHT" then
        display.text:SetPoint("RIGHT", display, "RIGHT", -2, 0)
    else
        display.text:SetPoint("CENTER", display, "CENTER", 0, 0)
    end
    display.text:SetJustifyH(justify)
    
    anchor:SetSize(200, (db.fontSize or 20) + 10)
end

local function CheckAlerts()
    local db = ACT.db and ACT.db.profile and ACT.db.profile.general_pack
    if not db or not db.enabled then 
        display:Hide()
        return 
    end

    local textLines = {}
    local inCombat = InCombatLockdown()
    local inInstance = IsInInstance()

    -- Check for missing pet
    local _, class = UnitClass("player")
    local petClasses = {HUNTER=true, WARLOCK=true, DEATHKNIGHT=true}
    if petClasses[class] and not UnitExists("pet") and not UnitIsDeadOrGhost("player") then
        if inCombat or inInstance then
            table.insert(textLines, "|cffff0000Summon Pet!|r")
        end
    end

    -- Repair Reminder (atm less than 30%)
    for i = 1, 18 do
        local current, max = GetInventoryItemDurability(i)
        if current and max and max > 0 and (current / max) < 0.3 then
            table.insert(textLines, "|cffffd000Repair Gear!|r")
            break 
        end
    end

    -- Temp alerts
    local now = GetTime()
    local hasMakeHS = false

    for key, data in pairs(tempAlerts) do
        if now < data.expires then
            if data.text then
                table.insert(textLines, data.text)
            end
            if key == "MakeHS" then hasMakeHS = true end
        else
            tempAlerts[key] = nil
        end
    end

    if hasMakeHS and GetItemCount(5512) < 3 and (inCombat or inInstance) then
         if not (tempAlerts["MakeHS"] and tempAlerts["MakeHS"].text) then
             table.insert(textLines, "|cff00ff00Click Soulwell!|r")
         end
    end

    if #textLines > 0 then
        display.text:SetText(table.concat(textLines, "\n"))
        display:Show()
    elseif not (LEM and LEM:IsInEditMode()) then
        display:Hide()
    end
end

local function TriggerTempAlert(key, text, duration)
    local now = GetTime()
    local last = lastTriggerTimes[key] or 0
    local cd = ALERT_COOLDOWNS[key] or 0

    if (now - last) > cd then
        tempAlerts[key] = { text = text, expires = now + duration }
        lastTriggerTimes[key] = now
        CheckAlerts()
                C_Timer.After(duration + 0.5, CheckAlerts)
    end
end

local function HandleChatTrigger(msg, sender)
    if not msg or not sender then return end

    local _, class = UnitClass("player")
    local isPlayer = NamesMatch(sender, UnitName("player"))
    local isWarlock = (class == "WARLOCK")
    
    msg = string.lower(msg)

    -- healthstone msg
    if msg == "hs" then
        if isWarlock and not isPlayer then
            -- Warlock sees OTHER person ask, remind to CREATE
            TriggerTempAlert("MakeHS", "|cffaa00ffCreate Soulwell!|r", 10)
        elseif not isWarlock then
            -- Non-warlock sees ANYONE ask, enable the "Click" check
            TriggerTempAlert("MakeHS", nil, 10)
        end
        -- Warlocks typing "hs" themselves get nothing
    end

    -- summon msg
    if msg == "123" then
        if isWarlock and not isPlayer then
            TriggerTempAlert("MakeSummon", "|cffaa00ffCreate Summoning Stone!|r", 10)
        end

        local targetUnitID = nil

        if IsInRaid() then
            for i = 1, 40 do
                local u = "raid"..i
                if NamesMatch(sender, UnitName(u)) then targetUnitID = u; break end
            end
        elseif IsInGroup() then
            for i = 1, 4 do
                local u = "party"..i
                if NamesMatch(sender, UnitName(u)) then targetUnitID = u; break end
            end
            if not targetUnitID and isPlayer then
                targetUnitID = "player"
            end
        else
            if isPlayer then targetUnitID = "player" end
        end

        if targetUnitID then
            local uFrame = GetUnitFrame(targetUnitID)
            if uFrame then
                -- Glow
                if LCG then
                    LCG.PixelGlow_Start(uFrame, {0, 1, 0, 1}, 8, 0.25, nil, 2, 0, 0, false, "PackGlow")
                end
                
                -- Text
                local tFrame = GetTextFrame()
                tFrame:ClearAllPoints()
                tFrame:SetPoint("CENTER", uFrame, "CENTER", 0, 0)
                tFrame.text:SetText("123")
                tFrame:Show()

                C_Timer.After(10, function() 
                    if LCG then LCG.PixelGlow_Stop(uFrame, "PackGlow") end
                    tFrame:Hide()
                end)
            end
        end
    end
end

local function OnEvent(self, event, ...)
    local args = {...}

    if InCombatLockdown() and event ~= "PLAYER_REGEN_ENABLED" then
        return
    end

    if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_PARTY_LEADER" then
        HandleChatTrigger(args[1], args[2])
    elseif event == "PLAYER_REGEN_ENABLED" then
        if GeneralPack.pendingUpdate then
            GeneralPack.pendingUpdate = false
            GeneralPack:UpdateState()
        end
        CheckAlerts()
    else
        CheckAlerts()
    end
end
display:SetScript("OnEvent", OnEvent)

local function GetEditModeSettings()
    return {
        {
            kind = LEM.SettingType.Dropdown, name = "Font Face", height = 300,
            default = "Friz Quadrata TT",
            values = (function()
                local t = {}
                if LSM then
                    for _, name in ipairs(LSM:List("font")) do table.insert(t, {text = name, value = name}) end
                else
                    table.insert(t, {text = "Friz Quadrata TT", value = "Friz Quadrata TT"})
                end
                return t
            end)(),
            get = function() return ACT.db.profile.general_pack.fontFace end,
            set = function(_, v) ACT.db.profile.general_pack.fontFace = v; UpdateVisuals() end
        },
        {
            kind = LEM.SettingType.Slider, name = "Font Size", minValue = 8, maxValue = 40, valueStep = 1,
            default = 20,
            get = function() return ACT.db.profile.general_pack.fontSize end,
            set = function(_, v) ACT.db.profile.general_pack.fontSize = v; UpdateVisuals() end
        },
        {
            kind = LEM.SettingType.Dropdown, name = "Font Outline",
            default = "OUTLINE",
            values = { {text="None", value=""}, {text="Outline", value="OUTLINE"}, {text="Thick", value="THICKOUTLINE"} },
            get = function() return ACT.db.profile.general_pack.fontOutline end,
            set = function(_, v) ACT.db.profile.general_pack.fontOutline = v; UpdateVisuals() end
        },
        {
            kind = LEM.SettingType.Dropdown, name = "Text Justification",
            default = "CENTER",
            values = { {text="Left", value="LEFT"}, {text="Center", value="CENTER"}, {text="Right", value="RIGHT"} },
            get = function() return ACT.db.profile.general_pack.fontJustify end,
            set = function(_, v) ACT.db.profile.general_pack.fontJustify = v; UpdateVisuals() end
        }
    }
end

local function OnLayoutChanged(frame, layoutName, point, x, y)
    if not ACT.db or not ACT.db.profile.general_pack then return end
    local db = ACT.db.profile.general_pack
    db.pos = db.pos or {}
    db.pos[layoutName] = {point = point, x = x, y = y}
end

function GeneralPack:UpdateState()
    if InCombatLockdown() then
        self.pendingUpdate = true
        display:RegisterEvent("PLAYER_REGEN_ENABLED") 
        return
    end

    if not ACT.db or not ACT.db.profile then return end
    
    ACT.db.profile.general_pack = ACT.db.profile.general_pack or { enabled = false, pos = {} }
    local db = ACT.db.profile.general_pack
    db.fontSize = db.fontSize or 20
    db.fontFace = db.fontFace or "Friz Quadrata TT"
    db.fontOutline = db.fontOutline or "OUTLINE"
    db.fontJustify = db.fontJustify or "CENTER"

    UpdateVisuals()

    display:UnregisterAllEvents()
    if db.enabled then
        for _, event in ipairs(MONITORED_EVENTS) do
            display:RegisterEvent(event)
        end
        CheckAlerts()
        
        if LEM and LEM:IsInEditMode() then
            display:Show()
            display.text:SetText("General Pack Alerts")
            display:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
            display:SetBackdropColor(0, 0, 0.5, 0.5)
            display:SetBackdropBorderColor(0, 0, 1, 1)
        end
    else
        display:Hide()
    end
    
    if LEM then
        if db.enabled and not anchor.editModeRegistered then
            LEM:AddFrame(anchor, OnLayoutChanged, {point = "CENTER", x = 0, y = 100}, "General Pack Alerts")
            LEM:AddFrameSettings(anchor, GetEditModeSettings())
            anchor.editModeRegistered = true
            
            if LEM.GetActiveLayoutName then
                local layout = LEM:GetActiveLayoutName()
                local pos = db.pos and db.pos[layout]
                if pos then
                     anchor:ClearAllPoints()
                     anchor:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
                end
            end
        elseif not db.enabled and anchor.editModeRegistered then
             if LEM.frameSelections[anchor] then LEM.frameSelections[anchor]:Hide() end
        end
    end
end

function GeneralPack:Initialize()
    self:UpdateState()

    if LEM then
        LEM:RegisterCallback("enter", function()
            if ACT.db.profile.general_pack.enabled then
                display:Show()
                display.text:SetText("General Pack Alerts")
                display:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
                display:SetBackdropColor(0, 0, 0.5, 0.5)
                display:SetBackdropBorderColor(0, 0, 1, 1)
            end
        end)

        LEM:RegisterCallback("exit", function()
            display:SetBackdrop(nil)
            display:SetBackdropColor(0,0,0,0)
            display:SetBackdropBorderColor(0,0,0,0)
            CheckAlerts()
        end)
        
        LEM:RegisterCallback("layout", function(layoutName)
            local db = ACT.db.profile.general_pack
            if not db or not db.enabled then return end
            local pos = db.pos and db.pos[layoutName]
            if pos then
                anchor:ClearAllPoints()
                anchor:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
            else
                anchor:ClearAllPoints()
                anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
            end
        end)
    end
end