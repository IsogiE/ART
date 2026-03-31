local addonName, NS = ...

if not ACT then return end

local DispellAssign = {}
ACT.DispellAssign = DispellAssign

local ENCOUNTER_ID = 3180

local active = false
local healers = {}
local dwarfs = {}
local affected = {}
local assignTimer = nil
local uiClearTimer = nil

local lastAuraTime = nil
local pendingUpdate = false

local myAssignedUnit = nil
local myAssignedAuraID = nil

local GLOW_KEY   = "ACT_DispellAssign"

local LGF = LibStub and LibStub("LibGetFrame-1.0", true)
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local LEM = LibStub and LibStub("LibEditMode", true)
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

if LSM then
    LSM:Register("sound", "Idiot", "Interface\\AddOns\\ACT\\media\\sounds\\Idiot.ogg")
end

local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"
local DEFAULT_FONT_FACE = "Friz Quadrata TT"

local OUTLINE_VALUES = {
    { text = "None",    value = ""             },
    { text = "Outline", value = "OUTLINE"      },
    { text = "Thick",   value = "THICKOUTLINE" },
}

local NAME_COLOR_MODES = {
    { text = "Class Color",  value = "class"  },
    { text = "Custom Color", value = "custom" },
}

local AUDIO_TYPE_VALUES = {
    { text = "Sound", value = "sound" },
    { text = "TTS",   value = "tts"   },
}

local DEFAULTS = {
    enabled         = false,
    fontFace        = DEFAULT_FONT_FACE,
    fontSize        = 28,
    fontOutline     = "OUTLINE",
    actionColor     = {0, 1, 0, 1},
    dwarfColor      = {1, 0.84, 0, 1},
    nameColorMode   = "class",
    nameCustomColor = {1, 0.27, 1, 1},
    glowColor       = {0.247, 0.988, 0.247, 1},
    glowType        = "Pixel",
    glowLines       = 10,
    glowThickness   = 3,
    glowFrequency   = 3,
    glowScale       = 10,
    pos             = {},
    audioType       = "sound",
    audioSound      = "Idiot",
    ttsVoice        = 0,
}

local function GetDB()
    if ACT.db and ACT.db.profile then
        ACT.db.profile.dispell_assign = ACT.db.profile.dispell_assign or {}
        local db = ACT.db.profile.dispell_assign
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        return db
    end
    return DEFAULTS
end

local function DBVal(key)
    local db = GetDB()
    return db and db[key] or DEFAULTS[key]
end

local function GetFontPath(faceKey)
    local face = DBVal(faceKey)
    if LSM and face then
        local path = LSM:Fetch("font", face)
        if path then return path end
    end
    return DEFAULT_FONT_PATH
end

local function GetColorHex(key)
    local db = GetDB()
    local val = db and db[key]
    local r, g, b = 1, 1, 1
    if val then
        if type(val.GetRGBA) == "function" then
            r, g, b = val:GetRGBA()
        elseif type(val) == "table" then
            r, g, b = val.r or val[1] or 1, val.g or val[2] or 1, val.b or val[3] or 1
        end
    end
    return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function GetDBColor(key)
    local db = GetDB()
    local val = db and db[key]
    if val then
        if type(val.GetRGBA) == "function" then
            return val
        elseif type(val) == "table" then
            return CreateColor(val.r or val[1] or 1, val.g or val[2] or 1, val.b or val[3] or 1, val.a or val[4] or 1)
        end
    end
    return CreateColor(1, 1, 1, 1)
end

local function GetGlowColorArray()
    local db = GetDB()
    local c = db and db.glowColor or DEFAULTS.glowColor
    if type(c.GetRGBA) == "function" then
        return {c:GetRGBA()}
    elseif type(c) == "table" then
        return {c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, c.a or c[4] or 1}
    end
    return {0.247, 0.988, 0.247, 1}
end

-- Applies the selected glow
local function ApplyGlow(unit)
    if not LGF or not LCG then return end
    local frame = LGF.GetUnitFrame(unit)

    -- bit of a hail marry in case LFG doesn't work for danders
    if not frame and DandersFrames_GetFrameForUnit then
        frame = DandersFrames_GetFrameForUnit(unit)
    end

    if not frame then return end
    
    local gType = DBVal("glowType")
    local color = GetGlowColorArray()
    local lines = DBVal("glowLines")
    
    local freq  = DBVal("glowFrequency") / 10
    local scale = DBVal("glowScale") / 10
    
    if gType == "Pixel" then
        LCG.PixelGlow_Start(frame, color, lines, freq, nil, DBVal("glowThickness"), 0, 0, true, GLOW_KEY)
    elseif gType == "Autocast" then
        LCG.AutoCastGlow_Start(frame, color, lines, freq, scale, 0, 0, GLOW_KEY)
    elseif gType == "Button" then
        LCG.ButtonGlow_Start(frame, color, freq)
    elseif gType == "Proc" then
        local duration = (freq ~= 0) and math.abs(1 / freq) or 1
        LCG.ProcGlow_Start(frame, {color = color, duration = duration, key = GLOW_KEY})
    end
end

local function RemoveGlow(unit)
    if not LGF or not LCG then return end
    local frame = LGF.GetUnitFrame(unit)

    if not frame and DandersFrames_GetFrameForUnit then
        frame = DandersFrames_GetFrameForUnit(unit)
    end

    if not frame then return end
    
    -- Stop all potential glows to ensure no ghosting when switching types
    LCG.PixelGlow_Stop(frame, GLOW_KEY)
    LCG.AutoCastGlow_Stop(frame, GLOW_KEY)
    LCG.ButtonGlow_Stop(frame)
    LCG.ProcGlow_Stop(frame, GLOW_KEY)
end

local warnFrame = CreateFrame("Frame", "ACT_DispellAssign_WarnFrame", UIParent, "BackdropTemplate")
warnFrame:SetSize(400, 80)
warnFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
warnFrame:Hide()

local warnText = warnFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
warnText:SetPoint("CENTER")

local function UpdateTextFormat()
    warnText:SetFont(GetFontPath("fontFace"), DBVal("fontSize"), DBVal("fontOutline"))
end

local function GetFormattedAlertText(actionText, isDwarf, targetUnit)
    local actionHex = GetColorHex(isDwarf and "dwarfColor" or "actionColor")
    
    if isDwarf then
        return string.format("|cff%s%s|r", actionHex, actionText)
    end

    local nameHex = "ffffffff"
    local nick = targetUnit and ACT:GetNickname(targetUnit)
    local name = targetUnit and ((nick ~= "" and nick) or UnitName(targetUnit)) or "Unknown"

    if DBVal("nameColorMode") == "class" then
        if targetUnit then
            local _, class = UnitClass(targetUnit)
            if class and RAID_CLASS_COLORS[class] then
                nameHex = RAID_CLASS_COLORS[class].colorStr:sub(3)
            end
        end
    else
        nameHex = GetColorHex("nameCustomColor")
    end

    return string.format("|cff%s%s|r |cff%s%s|r", actionHex, actionText, nameHex, name)
end

local function PlaySafeTTS(text)
    if not (C_VoiceChat and C_VoiceChat.SpeakText) then return end

    local targetVoiceID = tonumber(DBVal("ttsVoice")) or 0

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

local function PlayAlert(ttsText)
    local audioType = DBVal("audioType")
    if audioType == "sound" then
        local soundKey = DBVal("audioSound")
        local soundPath = LSM and LSM:Fetch("sound", soundKey)
        
        -- Fallback if LSM fetch fails but it's the default sound
        if not soundPath and soundKey == "Idiot" then
            soundPath = "Interface\\AddOns\\ACT\\media\\sounds\\Idiot.ogg"
        end
        
        if soundPath then
            PlaySoundFile(soundPath, "Master")
        end
    else
        PlaySafeTTS(ttsText)
    end
end

function DispellAssign:UpdateUI(show, actionText, isDwarf, targetUnit)
    if not show then
        if not (LEM and LEM:IsInEditMode()) then
            warnFrame:Hide()
        end
        -- Remove glow from previous assign before clearing
        if myAssignedUnit then
            RemoveGlow(myAssignedUnit)
        end
        myAssignedUnit = nil
        myAssignedAuraID = nil
        return
    end

    UpdateTextFormat()
    warnText:SetText(GetFormattedAlertText(actionText, isDwarf, targetUnit))
    warnFrame:Show()

    -- Apply the frame glow to the assigned person
    if myAssignedUnit then
        ApplyGlow(myAssignedUnit)
    end

    local ttsText
    if isDwarf then
        ttsText = "Use Dwarf"
    else
        local nick = targetUnit and ACT:GetNickname(targetUnit)
        local name = targetUnit and ((nick ~= "" and nick) or UnitName(targetUnit)) or "Unknown"
        ttsText = "Dispel " .. name
    end
    
    PlayAlert(ttsText)
end

local function BuildRoster()
    wipe(healers)
    wipe(dwarfs)

    local members = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do table.insert(members, "raid"..i) end
    else
        table.insert(members, "player")
        for i = 1, GetNumGroupMembers() - 1 do table.insert(members, "party"..i) end
    end

    -- Healers + Dwarfs
    for _, unit in ipairs(members) do
        if UnitExists(unit) then
            if UnitGroupRolesAssigned(unit) == "HEALER" then
                table.insert(healers, unit)
            end
            local _, _, race = UnitRace(unit)
            if race == 3 or race == 34 then
                dwarfs[unit] = 0
            end
        end
    end

    -- Warlocks after healers, 2nd class citizens
    for _, unit in ipairs(members) do
        if UnitExists(unit) then
            local _, _, class = UnitClass(unit)
            if class == 9 then
                table.insert(healers, unit)
            end
        end
    end
end

local function RunAssignment()

    if myAssignedUnit then
        RemoveGlow(myAssignedUnit)
        myAssignedUnit = nil
        myAssignedAuraID = nil
    end
    
    if #affected > 15 then
        wipe(affected)
        return
    end

    table.sort(affected, function(a, b)
        local aDwarf = a[5] and 1 or 0
        local bDwarf = b[5] and 1 or 0
        if aDwarf ~= bDwarf then
            return aDwarf < bDwarf
        end
        if a[2] == b[2] then
            return a[3] < b[3] 
        end
        return (a[2] or 999) < (b[2] or 999)
    end)

    lastAuraTime = nil

    local available = {}
    for i, v in ipairs(healers) do
        if not UnitIsDeadOrGhost(v) then
            table.insert(available, v)
        end
    end

    local slotTaken   = {} 
    local healerUsed  = {} 
    for ai, v in ipairs(available) do
        for si, info in ipairs(affected) do
            if not slotTaken[si] and UnitIsUnit(info[1], v) then
                slotTaken[si]  = true
                healerUsed[ai] = true
                if UnitIsUnit(v, "player") then
                    local auraInfo = C_UnitAuras.GetAuraDataByAuraInstanceID(info[1], info[3])
                    if auraInfo then
                        myAssignedUnit  = info[1]
                        myAssignedAuraID = info[3]
                        DispellAssign:UpdateUI(true, "Dispel", false, myAssignedUnit)
                        if uiClearTimer then uiClearTimer:Cancel() end
                        uiClearTimer = C_Timer.NewTimer(9, function() DispellAssign:UpdateUI(false) end)
                    else
                        DispellAssign:UpdateUI(false)
                    end
                end
                break
            end
        end
    end

    local nextSlot = 1
    for ai, v in ipairs(available) do
        if not healerUsed[ai] then
            while nextSlot <= #affected and slotTaken[nextSlot] do
                nextSlot = nextSlot + 1
            end
            if nextSlot > #affected then break end  -- no debuffs left to assign

            local info = affected[nextSlot]
            slotTaken[nextSlot] = true
            healerUsed[ai]      = true
            nextSlot            = nextSlot + 1

            if UnitIsUnit(v, "player") then
                local auraInfo = C_UnitAuras.GetAuraDataByAuraInstanceID(info[1], info[3])
                if auraInfo then
                    myAssignedUnit  = info[1]
                    myAssignedAuraID = info[3]
                    DispellAssign:UpdateUI(true, "Dispel", false, myAssignedUnit)
                    if uiClearTimer then uiClearTimer:Cancel() end
                    uiClearTimer = C_Timer.NewTimer(9, function() DispellAssign:UpdateUI(false) end)
                else
                    DispellAssign:UpdateUI(false)
                end
            end
        end
    end

    local now = GetTime()
    for si, info in ipairs(affected) do
        if info[5] and not slotTaken[si] and UnitIsUnit(info[1], "player") then
            if (not dwarfs["player"]) or now >= dwarfs["player"] then
                dwarfs["player"] = now + 121
                DispellAssign:UpdateUI(true, "USE DWARF", true, "player")
                if uiClearTimer then uiClearTimer:Cancel() end
                uiClearTimer = C_Timer.NewTimer(9, function() DispellAssign:UpdateUI(false) end)
            end
            break
        end
    end

    wipe(affected)
end

local eventFrame = CreateFrame("Frame")

-- Edit Mode stuffs
local function GetEditModeSettings()
    if not LEM then return {} end
    local ST = LEM.SettingType

    local s = {}
    local function add(t) s[#s + 1] = t end
    local function setDB(key, v) local db = GetDB(); if db then db[key] = v; UpdateTextFormat(); if warnFrame:IsVisible() then warnText:SetText(GetFormattedAlertText("Dispel", false, "player")) end end end

    local GLOW_TYPES = {
        { text = "Pixel Glow", value = "Pixel" },
        { text = "Autocast Shine", value = "Autocast" },
        { text = "Action Button Glow", value = "Button" },
        { text = "Proc Glow", value = "Proc" },
    }

    local function updateGlowProp(key, v)
        setDB(key, v)
        if LEM and LEM:IsInEditMode() then
            RemoveGlow("player")
            ApplyGlow("player")
        end
    end

    local fontVals = {}
    if LSM then
        for _, n in ipairs(LSM:List("font")) do fontVals[#fontVals + 1] = { text = n, value = n } end
    else
        fontVals[1] = { text = DEFAULT_FONT_FACE, value = DEFAULT_FONT_FACE }
    end

    local soundVals = {}
    if LSM then
        for _, n in ipairs(LSM:List("sound")) do soundVals[#soundVals + 1] = { text = n, value = n } end
    else
        soundVals[1] = { text = "Idiot", value = "Idiot" }
    end

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

    add({
        kind = ST.Expander, name = "Text Style", default = true,
        get = function() return DBVal("exp_text") end,
        set = function(_, v) local db = GetDB(); if db then db["exp_text"] = v end end
    })

    add({ kind = ST.Dropdown, name = "Font", default = DEFAULT_FONT_FACE, values = fontVals, height = 300, hidden = function() return not DBVal("exp_text") end, get = function() return DBVal("fontFace") end, set = function(_, v) setDB("fontFace", v) end })
    add({ kind = ST.Slider, name = "Font Size", default = 28, minValue = 10, maxValue = 72, valueStep = 1, hidden = function() return not DBVal("exp_text") end, get = function() return DBVal("fontSize") end, set = function(_, v) setDB("fontSize", v) end })
    add({ kind = ST.Dropdown, name = "Outline", default = "OUTLINE", values = OUTLINE_VALUES, hidden = function() return not DBVal("exp_text") end, get = function() return DBVal("fontOutline") end, set = function(_, v) setDB("fontOutline", v) end })

    add({
        kind = ST.Expander, name = "Colors", default = true,
        get = function() return DBVal("exp_colors") end,
        set = function(_, v) local db = GetDB(); if db then db["exp_colors"] = v end end
    })
    
    add({ kind = ST.ColorPicker, name = "Dispel Action Color", default = CreateColor(0, 1, 0, 1), hasOpacity = false, hidden = function() return not DBVal("exp_colors") end, get = function() return GetDBColor("actionColor") end, set = function(_, v) setDB("actionColor", v) end })
    add({ kind = ST.ColorPicker, name = "Dwarf Action Color", default = CreateColor(1, 0.84, 0, 1), hasOpacity = false, hidden = function() return not DBVal("exp_colors") end, get = function() return GetDBColor("dwarfColor") end, set = function(_, v) setDB("dwarfColor", v) end })
    
    add({ kind = ST.Dropdown, name = "Target Name Color", default = "class", values = NAME_COLOR_MODES, hidden = function() return not DBVal("exp_colors") end, get = function() return DBVal("nameColorMode") end, set = function(_, v) setDB("nameColorMode", v) end })
    add({ kind = ST.ColorPicker, name = "Custom Name Color", default = CreateColor(1, 0.27, 1, 1), hasOpacity = false, hidden = function() return not DBVal("exp_colors") or DBVal("nameColorMode") == "class" end, get = function() return GetDBColor("nameCustomColor") end, set = function(_, v) setDB("nameCustomColor", v) end })

    add({
        kind = ST.Expander, name = "Glow Settings", default = true,
        get = function() return DBVal("exp_glow") end,
        set = function(_, v) local db = GetDB(); if db then db["exp_glow"] = v end end
    })

    add({ 
        kind = ST.Dropdown, name = "Glow Type", default = "Pixel", values = GLOW_TYPES, 
        hidden = function() return not DBVal("exp_glow") end, 
        get = function() return DBVal("glowType") end, 
        set = function(_, v) updateGlowProp("glowType", v) end 
    })

    add({ 
        kind = ST.ColorPicker, name = "Glow Color", default = CreateColor(0.247, 0.988, 0.247, 1), hasOpacity = true, 
        hidden = function() return not DBVal("exp_glow") end, 
        get = function() return GetDBColor("glowColor") end, 
        set = function(_, v) updateGlowProp("glowColor", v) end 
    })

    add({ 
        kind = ST.Slider, name = "Lines/Particles", default = 10, minValue = 1, maxValue = 20, valueStep = 1, 
        hidden = function() return not DBVal("exp_glow") or (DBVal("glowType") ~= "Pixel" and DBVal("glowType") ~= "Autocast") end, 
        get = function() return DBVal("glowLines") end, 
        set = function(_, v) updateGlowProp("glowLines", v) end 
    })

    add({ 
        kind = ST.Slider, name = "Thickness", default = 3, minValue = 1, maxValue = 10, valueStep = 1, 
        hidden = function() return not DBVal("exp_glow") or DBVal("glowType") ~= "Pixel" end, 
        get = function() return DBVal("glowThickness") end, 
        set = function(_, v) updateGlowProp("glowThickness", v) end 
    })

    add({ 
        kind = ST.Slider, name = "Speed/Frequency", default = 3, minValue = 0, maxValue = 20, valueStep = 1, 
        hidden = function() return not DBVal("exp_glow") end, 
        get = function() return DBVal("glowFrequency") end, 
        set = function(_, v) updateGlowProp("glowFrequency", v) end 
    })

add({ 
        kind = ST.Slider, name = "Scale", default = 10, minValue = 5, maxValue = 30, valueStep = 1, 
        hidden = function() return not DBVal("exp_glow") or DBVal("glowType") ~= "Autocast" end, 
        get = function() return DBVal("glowScale") end, 
        set = function(_, v) updateGlowProp("glowScale", v) end 
    })

    add({
        kind = ST.Expander, name = "Sound Settings", default = true,
        get = function() return DBVal("exp_audio") end,
        set = function(_, v) local db = GetDB(); if db then db["exp_audio"] = v end end
    })

    add({ 
        kind = ST.Dropdown, name = "Alert Type", default = "sound", values = AUDIO_TYPE_VALUES, 
        hidden = function() return not DBVal("exp_audio") end, 
        get = function() return DBVal("audioType") end, 
        set = function(_, v) setDB("audioType", v) end 
    })

    add({ 
        kind = ST.Dropdown, name = "Sound File", default = "Idiot", values = soundVals, height = 300,
        hidden = function() return not DBVal("exp_audio") or DBVal("audioType") ~= "sound" end, 
        get = function() return DBVal("audioSound") end, 
        set = function(_, v) 
            setDB("audioSound", v)
            local path = LSM and LSM:Fetch("sound", v)
            if path then PlaySoundFile(path, "Master") end
        end 
    })

    add({ 
        kind = ST.Dropdown, name = "TTS Voice", default = 0, values = ttsVals, height = 300,
        hidden = function() return not DBVal("exp_audio") or DBVal("audioType") ~= "tts" end, 
        get = function() return DBVal("ttsVoice") end, 
        set = function(_, v) 
            local numericVoiceID = tonumber(v) or 0
            setDB("ttsVoice", numericVoiceID)
            
            if C_VoiceChat and C_VoiceChat.SpeakText then
                local rate = C_TTSSettings and C_TTSSettings.GetSpeechRate() or 0
                local volume = C_TTSSettings and C_TTSSettings.GetSpeechVolume() or 100
                C_VoiceChat.SpeakText(numericVoiceID, "Voice test", rate, volume, false)
            end
        end 
    })

    return s
end

local function OnLayoutChanged(frame, layoutName, point, x, y)
    local db = GetDB()
    if not db then return end
    db.pos = db.pos or {}
    db.pos[layoutName] = { point = point, x = x, y = y }
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingUpdate then
            pendingUpdate = false
            DispellAssign:UpdateState()
        end

    elseif event == "ENCOUNTER_START" then
        local encounterID = select(1, ...)
        if encounterID ~= ENCOUNTER_ID then return end

        active = true
        wipe(affected)
        DispellAssign:UpdateUI(false)
        BuildRoster()

    elseif event == "ENCOUNTER_END" then
        if not active then return end
        active = false
        DispellAssign:UpdateUI(false)
        wipe(affected)

    elseif event == "UNIT_AURA" then
        local unit, updateInfo = ...
        if not active then return end

        if not (unit == "player" or string.match(unit, "^raid%d+$") or string.match(unit, "^party%d+$")) then
            return
        end

        if updateInfo.addedAuras then
            local batchTriggered = false
            
            for i, auraData in ipairs(updateInfo.addedAuras) do
                local auraInstanceID = auraData.auraInstanceID
                local isDebuff = not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HARMFUL")

                if isDebuff and auraData.dispelName ~= nil then
                    local index = UnitInRaid(unit) or 999
                    local isDwarf = dwarfs[unit] ~= nil
                    
                    local alreadyAdded = false
                    for _, v in ipairs(affected) do
                        if v[3] == auraInstanceID then alreadyAdded = true; break end
                    end

                    if not alreadyAdded then
                        table.insert(affected, {unit, index, auraInstanceID, false, isDwarf})
                        batchTriggered = true
                    end
                end
            end

            if batchTriggered then
                if assignTimer then
                    assignTimer:Cancel()
                end
                assignTimer = C_Timer.NewTimer(0.25, RunAssignment)
            end
        end

        if updateInfo.removedAuraInstanceIDs and myAssignedAuraID and myAssignedUnit and UnitIsUnit(unit, myAssignedUnit) then
            for i, id in ipairs(updateInfo.removedAuraInstanceIDs) do
                if id == myAssignedAuraID then
                    DispellAssign:UpdateUI(false)
                end
            end
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local u, _, spellID = ...
        if UnitIsUnit(u, "player") and (spellID == 20594 or spellID == 265221) then
            DispellAssign:UpdateUI(false)
        end
    end
end)

function DispellAssign:UpdateState()
    if InCombatLockdown() then
        pendingUpdate = true
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local db = GetDB()

    eventFrame:UnregisterAllEvents()

    if db.enabled then
        eventFrame:RegisterEvent("ENCOUNTER_START")
        eventFrame:RegisterEvent("ENCOUNTER_END")
        eventFrame:RegisterEvent("UNIT_AURA")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

        -- Register LEM if it's not already registered
        if LEM and not warnFrame.editModeRegistered then
            LEM:AddFrame(warnFrame, OnLayoutChanged, { point = "CENTER", x = 0, y = 0 }, "Vanguard Assignment")
            LEM:AddFrameSettings(warnFrame, GetEditModeSettings())
            warnFrame.editModeRegistered = true

            if LEM.GetActiveLayoutName then
                local layout = LEM:GetActiveLayoutName()
                local pos = db.pos and db.pos[layout]
                if pos then
                    warnFrame:ClearAllPoints()
                    warnFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
                end
            end
        elseif LEM and warnFrame.editModeRegistered then
             -- Unhide frame selection if we are re-enabling while inside edit mode
            if LEM:IsInEditMode() and LEM.frameSelections and LEM.frameSelections[warnFrame] then
                LEM.frameSelections[warnFrame]:Show()
            end
        end
    else
        -- Clean up
        warnFrame:Hide()
        active = false
        wipe(affected)
        myAssignedUnit = nil
        myAssignedAuraID = nil

        -- Hide from edit mode if it's currently showing
        if LEM and warnFrame.editModeRegistered then
            if LEM.frameSelections and LEM.frameSelections[warnFrame] then
                LEM.frameSelections[warnFrame]:Hide()
            end
        end
    end
end

function DispellAssign:Initialize()
    if LEM then
        LEM:RegisterCallback("enter", function()
            if not DBVal("enabled") then return end
            warnFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            warnFrame:SetBackdropColor(0, 0.2, 0.5, 0.5)
            UpdateTextFormat()
            warnText:SetText(GetFormattedAlertText("Dispel", false, "player"))
            warnFrame:Show()
            ApplyGlow("player")
        end)

        LEM:RegisterCallback("exit", function()
            if not DBVal("enabled") then return end
            warnFrame:SetBackdrop(nil)
            RemoveGlow("player")
            if not myAssignedUnit then 
                warnFrame:Hide()
            else
                warnText:SetText(GetFormattedAlertText("Dispel", false, myAssignedUnit))
                ApplyGlow(myAssignedUnit)
            end
        end)

        LEM:RegisterCallback("layout", function(layoutName)
            if not DBVal("enabled") or not LEM:IsInEditMode() then return end
            local db = GetDB()
            local pos = db and db.pos and db.pos[layoutName]
            warnFrame:ClearAllPoints()
            if pos then
                warnFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
            else
                warnFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        end)
    end

    self:UpdateState()
end

if ACT.db and ACT.db.profile then
    DispellAssign:Initialize()
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(self, event)
        DispellAssign:Initialize()
        self:UnregisterEvent("PLAYER_LOGIN")
    end)
end


-- Debug shit
SLASH_PALADISPELLTEST1 = "/pdtest"
SlashCmdList["PALADISPELLTEST"] = function()
    if ACT and ACT.DispellAssign then
        print("Testing DispellAssign: Assigning to player...")
        
        myAssignedUnit = "player"
        
        ACT.DispellAssign:UpdateUI(true, "Dispel", false, "player")
        
        C_Timer.After(5, function() 
            ACT.DispellAssign:UpdateUI(false) 
        end)
    end
end

SLASH_PALADISPELLDWARF1 = "/pddwarf"
SlashCmdList["PALADISPELLDWARF"] = function()
    if ACT and ACT.DispellAssign then
        print("Testing DispellAssign: Dwarf Racial...")
        
        ACT.DispellAssign:UpdateUI(true, "USE DWARF", true, "player")
        
        C_Timer.After(5, function() 
            ACT.DispellAssign:UpdateUI(false) 
        end)
    end
end