local addonName, NS = ...

if not ACT then
    return
end

local GeneralPack = {}
ACT.GeneralPack = GeneralPack

local LEM = LibStub("LibEditMode", true)
local LSM = LibStub("LibSharedMedia-3.0", true)
local LCG = LibStub("LibCustomGlow-1.0", true)
local LGF = LibStub("LibGetFrame-1.0", true)
local AC = LibStub("AceComm-3.0", true)

local COMM_PREFIX = "ACT_GeneralPack"

local MONITORED_EVENTS = {"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "UNIT_PET",
                          "UPDATE_INVENTORY_DURABILITY", "CHAT_MSG_RAID", "CHAT_MSG_PARTY", "CHAT_MSG_RAID_LEADER",
                          "CHAT_MSG_PARTY_LEADER", "UNIT_AURA", "READY_CHECK", "UNIT_SPELLCAST_SUCCEEDED"}

local SPELL_IDS = {
    SOULWELL = 29893,
    RITUAL_OF_SUMMONING = 698,
    HEALTHSTONE_SPELL = 6262,
    DEMONIC_HEALTHSTONE = 452930
}

local tempAlerts = {}
GeneralPack.pendingUpdate = false
GeneralPack.missingHealthstone = false
GeneralPack.timeoutTimer = nil

local scanTooltip = CreateFrame("GameTooltip", "ACT_GeneralPack_ScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local eventFrame = CreateFrame("Frame", "ACT_GeneralPack_Events", UIParent)
eventFrame:SetPoint("CENTER")
eventFrame:SetSize(1, 1)
eventFrame:Show()

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
        if not f:IsShown() then
            return f
        end
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
    return name and strsplit("-", name) or ""
end

local function NamesMatch(n1, n2)
    return n1 and n2 and GetShortName(n1) == GetShortName(n2)
end

local function GetUnitFrame(targetUnit)
    if not targetUnit then
        return nil
    end

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
        local frame = _G["CompactRaidFrame" .. i]
        if frame and frame:IsVisible() and frame.unit and UnitIsUnit(frame.unit, targetUnit) then
            return frame
        end
    end

    for i = 1, 5 do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame and frame:IsVisible() and frame.unit and UnitIsUnit(frame.unit, targetUnit) then
            return frame
        end
    end

    if UnitIsUnit("player", targetUnit) and PlayerFrame and PlayerFrame:IsVisible() then
        return PlayerFrame
    end

    return nil
end

local function UpdateVisuals()
    if not ACT.db or not ACT.db.profile.general_pack then
        return
    end
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
    if InCombatLockdown() then
        display:Hide()
        return
    end

    local db = ACT.db and ACT.db.profile and ACT.db.profile.general_pack
    if not db or not db.enabled then
        display:Hide()
        return
    end

    local textLines = {}
    local inInstance = IsInInstance()
    local _, class = UnitClass("player")
    local needsPet = false

    if not UnitIsDeadOrGhost("player") and not UnitInVehicle("player") then
        if class == "WARLOCK" then
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(196099)
            if not aura then
                needsPet = true
            end
        elseif class == "HUNTER" then
            local currentSpec = GetSpecialization()
            if currentSpec then
                local specID = GetSpecializationInfo(currentSpec)
                if specID == 253 or specID == 255 then
                    needsPet = true
                elseif specID == 254 and IsPlayerSpell(1223323) then
                    needsPet = true
                end
            end
        elseif class == "DEATHKNIGHT" then
            local currentSpec = GetSpecialization()
            if currentSpec then
                local specID = GetSpecializationInfo(currentSpec)
                if specID == 252 then
                    needsPet = true
                end
            end
        end
    end

    if needsPet and inInstance and (not UnitExists("pet") or UnitIsDead("pet")) then
        table.insert(textLines, "|cffff0000Summon Pet!|r")
    end

    for i = 1, 18 do
        local current, max = GetInventoryItemDurability(i)
        if current and max and max > 0 and (current / max) < 0.3 then
            table.insert(textLines, "|cffffd000Repair Gear!|r")
            break
        end
    end

    if GeneralPack.missingHealthstone then
        table.insert(textLines, "|cff00ff00Click Soulwell!|r")
    end

    local now = GetTime()
    for key, data in pairs(tempAlerts) do
        if now < data.expires then
            if data.text then
                table.insert(textLines, data.text)
            end
        else
            tempAlerts[key] = nil
        end
    end

    if #textLines > 0 then
        display.text:SetText(table.concat(textLines, "\n"))
        local fontSize = tonumber(db.fontSize or 20)
        local lineCount = #textLines
        local newHeight = (fontSize * lineCount) + 20
        anchor:SetSize(200, newHeight)
        display:Show()
    elseif not (LEM and LEM:IsInEditMode()) then
        display:Hide()
    end
end

local function GetHealthstoneCharges(bag, slot)
    scanTooltip:ClearLines()
    scanTooltip:SetBagItem(bag, slot)

    for i = 1, scanTooltip:NumLines() do
        local line = _G[scanTooltip:GetName() .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text then
                local count = text:match("(%d+) Charge")
                if count then
                    return tonumber(count)
                end
            end
        end
    end
    return 1
end

local function HasFullHealthstone()
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local _, spellID = GetItemSpell(info.itemID)
                if spellID == SPELL_IDS.HEALTHSTONE_SPELL or spellID == SPELL_IDS.DEMONIC_HEALTHSTONE then

                    if (info.stackCount or 1) >= 3 then
                        return true
                    end

                    local charges = GetHealthstoneCharges(bag, slot)
                    if charges and charges >= 3 then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function StopHealthstoneScan()
    if GeneralPack.timeoutTimer then
        GeneralPack.timeoutTimer:Cancel()
        GeneralPack.timeoutTimer = nil
    end

    if eventFrame:IsEventRegistered("BAG_UPDATE") then
        eventFrame:UnregisterEvent("BAG_UPDATE")
    end

    GeneralPack.missingHealthstone = false
    CheckAlerts()
end

local function StartHealthstoneScan()
    if InCombatLockdown() then
        return
    end

    if HasFullHealthstone() then
        return
    end

    GeneralPack.missingHealthstone = true
    CheckAlerts()

    eventFrame:RegisterEvent("BAG_UPDATE")

    if GeneralPack.timeoutTimer then
        GeneralPack.timeoutTimer:Cancel()
    end
    GeneralPack.timeoutTimer = C_Timer.After(5, StopHealthstoneScan)
end

local function IsSpellOnCooldown(spellID)
    if not spellID then
        return true
    end
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration and (cooldownInfo.duration > 1.5) then
        return true
    end
    return false
end

local function TriggerTempAlert(key, text, duration, spellID)
    if spellID and IsSpellOnCooldown(spellID) then
        return
    end

    tempAlerts[key] = {
        text = text,
        expires = GetTime() + duration,
        spellID = spellID
    }
    CheckAlerts()
    C_Timer.After(duration + 0.5, CheckAlerts)
end

local function HandleChatTrigger(msg, sender)
    if not msg or not sender then
        return
    end

    local _, class = UnitClass("player")
    local isPlayer = NamesMatch(sender, UnitName("player"))
    local isWarlock = (class == "WARLOCK")

    msg = msg:lower()

    if msg == "hs" then
        if isWarlock and not isPlayer then
            TriggerTempAlert("MakeHS", "|cffaa00ffCreate Soulwell!|r", 10, SPELL_IDS.SOULWELL)
        end
    end

    if msg == "123" then
        if isWarlock and not isPlayer then
            TriggerTempAlert("MakeSummon", "|cffaa00ffCreate Summoning Stone!|r", 10, SPELL_IDS.RITUAL_OF_SUMMONING)
        end

        local targetUnitID = nil
        if IsInRaid() then
            for i = 1, 40 do
                local u = "raid" .. i
                if NamesMatch(sender, UnitName(u)) then
                    targetUnitID = u;
                    break
                end
            end
        elseif IsInGroup() then
            for i = 1, 4 do
                local u = "party" .. i
                if NamesMatch(sender, UnitName(u)) then
                    targetUnitID = u;
                    break
                end
            end
            if not targetUnitID and isPlayer then
                targetUnitID = "player"
            end
        else
            if isPlayer then
                targetUnitID = "player"
            end
        end

        if targetUnitID then
            local uFrame = GetUnitFrame(targetUnitID)
            if uFrame and LCG then
                LCG.PixelGlow_Start(uFrame, {0, 1, 0, 1}, 8, 0.25, nil, 2, 0, 0, false, "PackGlow")
                local tFrame = GetTextFrame()
                tFrame:ClearAllPoints()
                tFrame:SetPoint("CENTER", uFrame, "CENTER", 0, 0)
                tFrame.text:SetText("123")
                tFrame:Show()
                C_Timer.After(10, function()
                    LCG.PixelGlow_Stop(uFrame, "PackGlow")
                    tFrame:Hide()
                end)
            end
        end
    end
end

local function IsPetPassive()
    if not UnitExists("pet") then
        return false
    end
    for i = 1, NUM_PET_ACTION_SLOTS do
        local name, _, _, isActive = GetPetActionInfo(i)
        if name and (name == "PET_MODE_PASSIVE" or name == "PET_ACTION_MODE_PASSIVE") and isActive then
            return true
        end
    end
    return false
end

local function IsSoulstoneReady()
    local spellID = 20707
    if not IsPlayerSpell(spellID) then
        return false
    end
    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration and (cooldownInfo.duration > 1.5) then
        return false
    end
    return true
end

local function DoesGroupHaveSoulstone()
    local ssSpellID = 20707
    local function HasSS(unit)
        if not unit or not UnitExists(unit) then
            return false
        end
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not aura then
                break
            end
            if aura.spellId == ssSpellID then
                return true
            end
        end
        return false
    end
    if HasSS("player") then
        return true
    end
    if IsInRaid() then
        for i = 1, 40 do
            if HasSS("raid" .. i) then
                return true
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            if HasSS("party" .. i) then
                return true
            end
        end
    end
    return false
end

function GeneralPack:OnCommReceived(prefix, message, distribution, sender)
    if InCombatLockdown() then
        return
    end
    if prefix == COMM_PREFIX and message == "SOULWELL_UP" then
        StartHealthstoneScan()
    end
end

local function OnEvent(self, event, ...)
    if InCombatLockdown() then
        return
    end
    local args = {...}

    if event == "BAG_UPDATE" then
        if HasFullHealthstone() then
            StopHealthstoneScan()
        end
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = args[1], args[2], args[3]

        if unit == "player" then
            if spellID == SPELL_IDS.SOULWELL then
                if AC then
                    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY")
                    if channel then
                        AC:SendCommMessage(COMM_PREFIX, "SOULWELL_UP", channel)
                    end
                end
            end

            for key, data in pairs(tempAlerts) do
                if data.spellID and data.spellID == spellID then
                    tempAlerts[key] = nil
                end
            end
            CheckAlerts()
        end
        return
    end

    if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_RAID_LEADER" or event ==
        "CHAT_MSG_PARTY_LEADER" then
        HandleChatTrigger(args[1], args[2])
        return
    end

    if event == "READY_CHECK" then
        if IsPetPassive() then
            TriggerTempAlert("PetPassive", "|cffff0000Pet is on passive!|r", 10)
        end

        local _, class = UnitClass("player")
        if class == "WARLOCK" and IsSoulstoneReady() and not DoesGroupHaveSoulstone() then
            TriggerTempAlert("MissingSS", "|cffaa00ffApply Soulstone!|r", 10)
        end
        CheckAlerts()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if GeneralPack.pendingUpdate then
            GeneralPack.pendingUpdate = false
            GeneralPack:UpdateState()
        end
        CheckAlerts()
        return
    end

    if event == "UNIT_AURA" then
        local unit = args[1]
        if unit == "player" then
            CheckAlerts()
        end
        return
    end

    CheckAlerts()
end
eventFrame:SetScript("OnEvent", OnEvent)

local function GetEditModeSettings()
    return {{
        kind = LEM.SettingType.Dropdown,
        name = "Font Face",
        height = 300,
        default = "Friz Quadrata TT",
        values = (function()
            local t = {}
            if LSM then
                for _, name in ipairs(LSM:List("font")) do
                    table.insert(t, {
                        text = name,
                        value = name
                    })
                end
            else
                table.insert(t, {
                    text = "Friz Quadrata TT",
                    value = "Friz Quadrata TT"
                })
            end
            return t
        end)(),
        get = function()
            return ACT.db.profile.general_pack.fontFace
        end,
        set = function(_, v)
            ACT.db.profile.general_pack.fontFace = v;
            UpdateVisuals()
        end
    }, {
        kind = LEM.SettingType.Slider,
        name = "Font Size",
        minValue = 8,
        maxValue = 40,
        valueStep = 1,
        default = 20,
        get = function()
            return ACT.db.profile.general_pack.fontSize
        end,
        set = function(_, v)
            ACT.db.profile.general_pack.fontSize = v;
            UpdateVisuals()
        end
    }, {
        kind = LEM.SettingType.Dropdown,
        name = "Font Outline",
        default = "OUTLINE",
        values = {{
            text = "None",
            value = ""
        }, {
            text = "Outline",
            value = "OUTLINE"
        }, {
            text = "Thick",
            value = "THICKOUTLINE"
        }},
        get = function()
            return ACT.db.profile.general_pack.fontOutline
        end,
        set = function(_, v)
            ACT.db.profile.general_pack.fontOutline = v;
            UpdateVisuals()
        end
    }, {
        kind = LEM.SettingType.Dropdown,
        name = "Text Justification",
        default = "CENTER",
        values = {{
            text = "Left",
            value = "LEFT"
        }, {
            text = "Center",
            value = "CENTER"
        }, {
            text = "Right",
            value = "RIGHT"
        }},
        get = function()
            return ACT.db.profile.general_pack.fontJustify
        end,
        set = function(_, v)
            ACT.db.profile.general_pack.fontJustify = v;
            UpdateVisuals()
        end
    }}
end

local function OnLayoutChanged(frame, layoutName, point, x, y)
    if not ACT.db or not ACT.db.profile.general_pack then
        return
    end
    local db = ACT.db.profile.general_pack
    db.pos = db.pos or {}
    db.pos[layoutName] = {
        point = point,
        x = x,
        y = y
    }
end

function GeneralPack:UpdateState()
    if InCombatLockdown() then
        self.pendingUpdate = true
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    if not ACT.db or not ACT.db.profile then
        return
    end

    ACT.db.profile.general_pack = ACT.db.profile.general_pack or {
        enabled = false,
        pos = {}
    }
    local db = ACT.db.profile.general_pack
    db.fontSize = db.fontSize or 20
    db.fontFace = db.fontFace or "Friz Quadrata TT"
    db.fontOutline = db.fontOutline or "OUTLINE"
    db.fontJustify = db.fontJustify or "CENTER"

    UpdateVisuals()

    eventFrame:UnregisterAllEvents()
    if db.enabled then
        for _, event in ipairs(MONITORED_EVENTS) do
            eventFrame:RegisterEvent(event)
        end

        if AC then
            AC:RegisterComm(COMM_PREFIX, function(...)
                GeneralPack:OnCommReceived(...)
            end)
        end

        CheckAlerts()

        if LEM and LEM:IsInEditMode() then
            display:Show()
            display.text:SetText("General Pack Alerts")
            display:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1
            })
            display:SetBackdropColor(0, 0, 0.5, 0.5)
            display:SetBackdropBorderColor(0, 0, 1, 1)
        end
    else
        display:Hide()
        if AC then
            AC:RegisterComm(COMM_PREFIX, function()
            end)
        end
    end

    if LEM then
        if db.enabled and not anchor.editModeRegistered then
            LEM:AddFrame(anchor, OnLayoutChanged, {
                point = "CENTER",
                x = 0,
                y = 100
            }, "General Pack Alerts")
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
            if LEM.frameSelections[anchor] then
                LEM.frameSelections[anchor]:Hide()
            end
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
                display:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1
                })
                display:SetBackdropColor(0, 0, 0.5, 0.5)
                display:SetBackdropBorderColor(0, 0, 1, 1)
            end
        end)

        LEM:RegisterCallback("exit", function()
            display:SetBackdrop(nil)
            display:SetBackdropColor(0, 0, 0, 0)
            display:SetBackdropBorderColor(0, 0, 0, 0)
            CheckAlerts()
        end)

        LEM:RegisterCallback("layout", function(layoutName)
            local db = ACT.db.profile.general_pack
            if not db or not db.enabled then
                return
            end
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
