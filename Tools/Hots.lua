local addonName, NS = ...

if not ACT then return end

local HotTracker = {}
ACT.HotTracker = HotTracker

local LEM = LibStub("LibEditMode", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

local ICON_TEX_COORD     = { 0.08, 0.92, 0.08, 0.92 }
local FALLBACK_ICON      = 134400
local TICKER_INTERVAL    = 0.1
local ANCHOR_DEFAULT_X   = 0
local ANCHOR_DEFAULT_Y   = 150
local ANCHOR_DEFAULT_W   = 200
local ANCHOR_DEFAULT_H   = 44
local EDITMODE_BG_FILE   = "Interface\\Buttons\\WHITE8x8"
local DEFAULT_FONT_PATH  = "Fonts\\FRIZQT__.TTF"
local DEFAULT_FONT_FACE  = "Friz Quadrata TT"

local COMBAT_RESYNC_INTERVAL = 5

local EDITMODE_BACKDROP = {
    bgFile   = EDITMODE_BG_FILE,
    edgeFile = EDITMODE_BG_FILE,
    edgeSize = 1,
}
local EDITMODE_BG_COLOR     = { 0,   0.2, 0.5, 0.5 }
local EDITMODE_BORDER_COLOR = { 0,   0.5, 1,   1   }

local CLASS_SPELLS = {
    EVOKER = {
        { id = 364343, name = "Echo",           color = {0.4, 0.8, 1},   specIDs = {1468}, dbKey = "track_echo"         },
        { id = 366155, name = "Reversion",      color = {0.2, 1,   0.6}, specIDs = {1468}, dbKey = "track_reversion"    },
        { id = 367364, name = "Echo Reversion", color = {0.2, 1,   0.6}, specIDs = {1468}, dbKey = "track_reversion",   hidden = true },
    },
    DRUID = {
        { id = 774,    name = "Rejuvenation",   color = {0.2, 1,   0.3}, specIDs = {105},  dbKey = "track_rejuv"        },
        { id = 155777, name = "Germination",    color = {0.1, 0.9, 0.2}, specIDs = {105},  dbKey = "track_rejuv",       hidden = true },
    },
    MONK = {
        { id = 119611, name = "Renewing Mist",  color = {0.4, 0.9, 1},   specIDs = {270},  dbKey = "track_renewingmist" },
    },
    SHAMAN = {
        { id = 61295,  name = "Riptide",        color = {0.2, 0.6, 1},   specIDs = {264},  dbKey = "track_riptide"      },
    },
    PRIEST = {
        { id = 194384, name = "Atonement",      color = {0.9, 0.5, 1},   specIDs = {256},  dbKey = "track_atonement"   },
    },
    PALADIN = {
        { id = 156322,  name = "Eternal Flame",      color = {1, 0.8, 0.2}, specIDs = {65}, dbKey = "track_eternalflame" },
        { id = 1244893, name = "Beacon of the Savior", color = {1, 0.8, 0.2}, specIDs = {65}, dbKey = "track_bsavior"   },
    },
}

local SHOW_WHEN_VALUES = {
    { text = "Always",        value = "always"   },
    { text = "In Combat",     value = "combat"   },
    { text = "Out of Combat", value = "nocombat" },
    { text = "Never",         value = "never"    },
}

local ANCHOR_POINTS = {
    { text = "Top Left",     value = "TOPLEFT"     },
    { text = "Top",          value = "TOP"         },
    { text = "Top Right",    value = "TOPRIGHT"    },
    { text = "Left",         value = "LEFT"        },
    { text = "Center",       value = "CENTER"      },
    { text = "Right",        value = "RIGHT"       },
    { text = "Bottom Left",  value = "BOTTOMLEFT"  },
    { text = "Bottom",       value = "BOTTOM"      },
    { text = "Bottom Right", value = "BOTTOMRIGHT" },
}

local OUTLINE_VALUES = {
    { text = "None",    value = ""             },
    { text = "Outline", value = "OUTLINE"      },
    { text = "Thick",   value = "THICKOUTLINE" },
}

local COLOR_DEFAULTS = {
    bgColor     = {0, 0, 0, 1},
    borderColor = {0, 0, 0, 1},
    countColor  = {1, 1, 1, 1},
    timerColor  = {1, 0.8, 0, 1},
}

local DEFAULTS = {
    enabled      = false,
    showWhen     = "always",
    iconSize     = 36,
    iconPad      = 4,
    iconOpacity  = 100,

    bgEnabled      = false,
    bgColor        = nil,
    bgOpacity      = 50,
    borderEnabled  = false,
    borderTexture  = "None",
    borderSize     = 12,
    borderColor    = nil,
    borderOpacity  = 100,
    countEnabled   = true,
    countAnchor    = "TOPLEFT",
    countOffsetX   = 0,
    countOffsetY   = 0,
    countFace      = DEFAULT_FONT_FACE,
    countSize      = 11,
    countOutline   = "OUTLINE",
    countColor     = nil,
    timerEnabled   = true,
    timerAnchor    = "BOTTOMRIGHT",
    timerOffsetX   = 0,
    timerOffsetY   = 0,
    timerFace      = DEFAULT_FONT_FACE,
    timerSize      = 10,
    timerOutline   = "OUTLINE",
    timerColor     = nil,
    timerDecimals  = 1,

    exp_icon   = true,
    exp_bg     = false,
    exp_border = false,
    exp_count  = false,
    exp_timer  = false,
    exp_spells = false,

    pos = {},
}

local auraData       = {}
local displayEntries = {}
local anchor, display
local icons             = {}
local pendingUpdate     = false
local inCombat          = false
local ticker            = nil
local bgBackdropApplied = false
local unitAuraCache     = {}
local lastCombatResync  = 0

local function GetDB()
    if ACT.db and ACT.db.profile and ACT.db.profile.hot_tracker then
        return ACT.db.profile.hot_tracker
    end
end

local function DBVal(key)
    local db = GetDB()
    local v  = db and db[key]
    if v ~= nil then return v end
    return DEFAULTS[key]
end

local function OpacityVal(key)
    return DBVal(key) / 100
end

local function GetColorRGBA(key)
    local db  = GetDB()
    local val = db and db[key]
    if val then
        if type(val.GetRGBA) == "function" then
            return val:GetRGBA()
        elseif type(val) == "table" then
            return val.r or val[1] or 1,
                   val.g or val[2] or 1,
                   val.b or val[3] or 1,
                   val.a or val[4] or 1
        end
    end
    local d = COLOR_DEFAULTS[key] or {1, 1, 1, 1}
    return d[1], d[2], d[3], d[4]
end

local function DBColor(key)
    return CreateColor(GetColorRGBA(key))
end

local function GetPlayerSpecID()
    local spec = GetSpecialization()
    if spec then return GetSpecializationInfo(spec) end
end

local function IsSpellEnabled(dbKey)
    local db = GetDB()
    if not db then return false end
    if db[dbKey] == nil then return true end
    return db[dbKey]
end

local function ShouldShowDisplay()
    local sw = DBVal("showWhen")
    if sw == "never"    then return false end
    if sw == "combat"   then return inCombat end
    if sw == "nocombat" then return not inCombat end
    return true
end

local function IsSecretValue(v)
    if issecretvalue then return issecretvalue(v) end
    return false
end

local function GetGroupUnits()
    local units      = { "player" }
    local numMembers = GetNumGroupMembers()
    if IsInRaid() then
        for i = 1, numMembers do
            local unit = "raid" .. i
            if not UnitIsUnit(unit, "player") then
                units[#units + 1] = unit
            end
        end
    else
        for i = 1, numMembers - 1 do
            units[#units + 1] = "party" .. i
        end
    end
    return units
end

local function GetFontPath(faceKey)
    local face = DBVal(faceKey)
    if LSM and face then
        local path = LSM:Fetch("font", face)
        if path then return path end
    end
    return DEFAULT_FONT_PATH
end

local function ExtractAura(aura)
    if not aura then return end

    local instanceID = aura.auraInstanceID
    if type(instanceID) ~= "number" then return end

    local fromPlayer = aura.isFromPlayerOrPlayerPet
    if IsSecretValue(fromPlayer) or not fromPlayer then return end

    local sourceUnit = aura.sourceUnit
    if sourceUnit and not IsSecretValue(sourceUnit) then
        if not UnitIsUnit(sourceUnit, "player") then return end
    end

    local sid = aura.spellId
    if IsSecretValue(sid) or type(sid) ~= "number" then return end
    if not auraData[sid] then return end

    local expiry = aura.expirationTime
    if IsSecretValue(expiry) or type(expiry) ~= "number" then expiry = 0 end
    if expiry ~= 0 and expiry < GetTime() then return end

    local duration = aura.duration
    if IsSecretValue(duration) or type(duration) ~= "number" then duration = 0 end

    return instanceID, sid, expiry, duration
end

local function ResyncUnit(unit, useCombatSafe)
    unitAuraCache[unit] = {}
    if not UnitExists(unit) then return end

    if useCombatSafe then
        local result = C_UnitAuras.GetUnitAuraInstanceIDs and
                       C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HELPFUL")
        if not result then return end
        for _, instanceID in ipairs(result) do
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instanceID)
            if aura then
                local iid, sid, expiry, duration = ExtractAura(aura)
                if iid then
                    unitAuraCache[unit][iid] = { spellId = sid, expirationTime = expiry, duration = duration }
                end
            end
        end
    else
        local auras = C_UnitAuras.GetUnitAuras and
                      C_UnitAuras.GetUnitAuras(unit, "HELPFUL|PLAYER")
        if not auras then return end
        for _, aura in ipairs(auras) do
            local instanceID, sid, expiry, duration = ExtractAura(aura)
            if instanceID then
                unitAuraCache[unit][instanceID] = { spellId = sid, expirationTime = expiry, duration = duration }
            end
        end
    end
end

local function ResyncAll()
    unitAuraCache = {}
    for _, unit in ipairs(GetGroupUnits()) do
        ResyncUnit(unit, inCombat)
    end
end

local function HandleUnitAuraEvent(unit, info)
    if info == nil or info.isFullUpdate then
        ResyncUnit(unit, inCombat)
        return
    end

    if not unitAuraCache[unit] then return end

    if info.removedAuraInstanceIDs then
        for _, instanceID in ipairs(info.removedAuraInstanceIDs) do
            unitAuraCache[unit][instanceID] = nil
        end
    end

    if info.addedAuras then
        for _, aura in ipairs(info.addedAuras) do
            local instanceID = aura.auraInstanceID
            if type(instanceID) == "number" then
                local fresh = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instanceID)
                if fresh then
                    local iid, sid, expiry, duration = ExtractAura(fresh)
                    if iid then
                        unitAuraCache[unit][iid] = { spellId = sid, expirationTime = expiry, duration = duration }
                    end
                end
            end
        end
    end

    if info.updatedAuraInstanceIDs then
        for _, instanceID in ipairs(info.updatedAuraInstanceIDs) do
            local fresh = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instanceID)
            if fresh then
                local _, sid, expiry, duration = ExtractAura(fresh)
                if sid then
                    unitAuraCache[unit][instanceID] = { spellId = sid, expirationTime = expiry, duration = duration }
                else
                    unitAuraCache[unit][instanceID] = nil
                end
            else
                unitAuraCache[unit][instanceID] = nil
            end
        end
    end
end

local function ScanGroupAuras()
    for spellID in pairs(auraData) do
        auraData[spellID] = { count = 0, minExpiry = math.huge, maxExpiry = 0, minDuration = 0 }
    end

    local now = GetTime()

    for _, unitCache in pairs(unitAuraCache) do
        local toRemove = {}
        for instanceID, entry in pairs(unitCache) do
            local sid    = entry.spellId
            local expiry = entry.expirationTime or 0

            if expiry == 0 or expiry < now or not auraData[sid] then
                toRemove[#toRemove + 1] = instanceID
            else
                local d = auraData[sid]
                d.count = d.count + 1
                if expiry < d.minExpiry then
                    d.minExpiry   = expiry
                    d.minDuration = entry.duration or 0
                end
                if expiry > d.maxExpiry then
                    d.maxExpiry = expiry
                end
            end
        end
        for _, instanceID in ipairs(toRemove) do
            unitCache[instanceID] = nil
        end
    end
end

local function FormatTime(seconds)
    if seconds <= 0 or seconds == math.huge then return "" end
    if seconds >= 60 then return string.format("%dm", math.ceil(seconds / 60)) end
    local decimals = DBVal("timerDecimals")
    if decimals == 0 then
        return string.format("%d", math.floor(seconds))
    elseif decimals == 2 then
        return string.format("%.2f", seconds)
    else
        return string.format("%.1f", seconds)
    end
end

local function ApplyLabelPoint(label, anchorKey, oxKey, oyKey)
    local pt = DBVal(anchorKey)
    label:ClearAllPoints()
    label:SetPoint(pt, label:GetParent(), pt, DBVal(oxKey), DBVal(oyKey))
end

local function UpdateLabelStyle(label, faceKey, sizeKey, outlineKey, colorKey, anchorKey, oxKey, oyKey)
    label:SetFont(GetFontPath(faceKey), DBVal(sizeKey), DBVal(outlineKey))
    label:SetTextColor(GetColorRGBA(colorKey))
    ApplyLabelPoint(label, anchorKey, oxKey, oyKey)
end

local function GetOrCreateIcon(index)
    if icons[index] then return icons[index] end

    local f = CreateFrame("Frame", nil, display, "BackdropTemplate")
    f:SetFrameStrata("MEDIUM")

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0, 0, 0, 0)

    f.texture = f:CreateTexture(nil, "ARTWORK")
    f.texture:SetAllPoints()
    f.texture:SetTexCoord(ICON_TEX_COORD[1], ICON_TEX_COORD[2], ICON_TEX_COORD[3], ICON_TEX_COORD[4])

    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints(f)
    f.cooldown:SetFrameLevel(f:GetFrameLevel() + 1)
    f.cooldown:SetDrawBling(false)
    f.cooldown:SetDrawEdge(false)
    f.cooldown:SetHideCountdownNumbers(true)

    local textHolder = CreateFrame("Frame", nil, f)
    textHolder:SetAllPoints(f)
    textHolder:SetFrameLevel(f:GetFrameLevel() + 2)

    f.count = textHolder:CreateFontString(nil, "OVERLAY")
    f.count:SetFont(DEFAULT_FONT_PATH, DEFAULTS.countSize, DEFAULTS.countOutline)
    f.count:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)

    f.timer = textHolder:CreateFontString(nil, "OVERLAY")
    f.timer:SetFont(DEFAULT_FONT_PATH, DEFAULTS.timerSize, DEFAULTS.timerOutline)
    f.timer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

    f.border = CreateFrame("Frame", nil, display, "BackdropTemplate")
    f.border:SetFrameStrata("MEDIUM")
    f.border:SetFrameLevel(f:GetFrameLevel())
    f.border:Hide()
    f.borderApplied = false

    icons[index] = f
    return f
end

local function UpdateDisplay()
    local bgEnabled  = DBVal("bgEnabled")
    local inEditMode = LEM and LEM:IsInEditMode()

    if not bgEnabled or inEditMode then
        if not inEditMode then display:SetBackdrop(nil) end
        bgBackdropApplied = false
        return
    end

    if not bgBackdropApplied then
        display:SetBackdrop({
            bgFile = EDITMODE_BG_FILE,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        bgBackdropApplied = true
    end

    local r, g, b = GetColorRGBA("bgColor")
    display:SetBackdropColor(r, g, b, OpacityVal("bgOpacity"))
end

local function UpdateIconBorder(ic, borderEnabled, edgeTex, edgeSize)
    if not borderEnabled or not edgeTex or edgeSize <= 0 then
        ic.border:Hide()
        ic.borderApplied = false
        return
    end

    if not ic.borderApplied or ic.lastBorderTex ~= edgeTex or ic.lastBorderSize ~= edgeSize then
        ic.border:ClearAllPoints()
        ic.border:SetPoint("TOPLEFT",     ic, "TOPLEFT",     -edgeSize,  edgeSize)
        ic.border:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT",  edgeSize, -edgeSize)

        local half = edgeSize / 2
        ic.border:SetBackdrop({
            edgeFile = edgeTex,
            edgeSize = edgeSize,
            insets   = { left = half, right = half, top = half, bottom = half },
        })
        ic.lastBorderTex  = edgeTex
        ic.lastBorderSize = edgeSize
        ic.borderApplied  = true
    end

    local r, g, b = GetColorRGBA("borderColor")
    ic.border:SetBackdropBorderColor(r, g, b, OpacityVal("borderOpacity"))
    ic.border:Show()
end

local function ApplyEditModeBackdrop()
    display:Show()
    display:SetBackdrop(EDITMODE_BACKDROP)
    display:SetBackdropColor(unpack(EDITMODE_BG_COLOR))
    display:SetBackdropBorderColor(unpack(EDITMODE_BORDER_COLOR))
end

local function UpdateIcons()
    local db = GetDB()
    if not db or not db.enabled or not ShouldShowDisplay() then
        for _, ic in ipairs(icons) do
            ic:Hide()
            if ic.border then ic.border:Hide() end
        end
        if not (LEM and LEM:IsInEditMode()) then display:Hide() end
        return
    end

    if inCombat then
        local now = GetTime()
        if now - lastCombatResync >= COMBAT_RESYNC_INTERVAL then
            lastCombatResync = now
            ResyncAll()
        end
    end

    ScanGroupAuras()
    UpdateDisplay()

    local now           = GetTime()
    local iconSize      = DBVal("iconSize")
    local iconPad       = DBVal("iconPad")
    local opacity       = OpacityVal("iconOpacity")
    local borderEnabled = DBVal("borderEnabled")
    local inEditMode    = LEM and LEM:IsInEditMode()
    local edgeTex, edgeSize = nil, 0

    if borderEnabled then
        local tex = DBVal("borderTexture")
        if tex and tex ~= "None" then
            edgeTex  = (LSM and LSM:Fetch("border", tex)) or EDITMODE_BG_FILE
        end
        edgeSize = edgeTex and DBVal("borderSize") or 0
    end

    local shown = 0

    for _, entry in ipairs(displayEntries) do
        if IsSpellEnabled(entry.dbKey) then
            local totalCount, minExpiry, maxExpiry, minDuration = 0, math.huge, 0, 0
            for _, sid in ipairs(entry.spellIDs) do
                local d = auraData[sid]
                if d then
                    totalCount = totalCount + d.count
                    if d.minExpiry < minExpiry then
                        minExpiry   = d.minExpiry
                        minDuration = d.minDuration
                    end
                    if d.maxExpiry > maxExpiry then maxExpiry = d.maxExpiry end
                end
            end

            shown = shown + 1
            local ic = GetOrCreateIcon(shown)
            ic:SetSize(iconSize, iconSize)
            ic:ClearAllPoints()
            if shown == 1 then
                ic:SetPoint("TOPLEFT", display, "TOPLEFT", iconPad, -iconPad)
            else
                ic:SetPoint("LEFT", icons[shown - 1], "RIGHT", iconPad, 0)
            end

            ic.texture:SetTexture(entry.texID)
            ic.texture:SetAlpha(opacity)
            ic.texture:SetDesaturated(totalCount == 0)
            ic.texture:SetVertexColor(1, 1, 1)

            if DBVal("countEnabled") then
                UpdateLabelStyle(ic.count, "countFace", "countSize", "countOutline", "countColor",
                                           "countAnchor", "countOffsetX", "countOffsetY")
                ic.count:SetText(tostring(totalCount))
                ic.count:Show()
            else
                ic.count:Hide()
            end

            if DBVal("timerEnabled") and (totalCount > 0 or inEditMode) then
                UpdateLabelStyle(ic.timer, "timerFace", "timerSize", "timerOutline", "timerColor",
                                           "timerAnchor", "timerOffsetX", "timerOffsetY")
                ic.timer:SetText(totalCount > 0 and FormatTime(minExpiry - now) or "9.9")
                ic.timer:Show()
            else
                ic.timer:Hide()
            end

            if totalCount > 0 and minExpiry ~= math.huge and minDuration > 0 then
                ic.cooldown:SetCooldown(minExpiry - minDuration, minDuration)
                ic.cooldown:Show()
            elseif inEditMode then
                ic.cooldown:SetCooldown(GetTime() - 5, 10)
                ic.cooldown:Show()
            else
                ic.cooldown:SetCooldown(0, 0)
                ic.cooldown:Hide()
            end

            UpdateIconBorder(ic, borderEnabled, edgeTex, edgeSize)
            ic:Show()
        end
    end

    for i = shown + 1, #icons do
        icons[i]:Hide()
        if icons[i].border then icons[i].border:Hide() end
    end

    if shown > 0 then
        anchor:SetSize(shown * iconSize + (shown + 1) * iconPad, iconSize + iconPad * 2)
        display:SetAllPoints(anchor)
        display:Show()
    elseif not inEditMode then
        display:Hide()
    end
end

local function StartTicker()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(TICKER_INTERVAL, function()
        if DBVal("enabled") then UpdateIcons() end
    end)
end

local function StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function RebuildTrackedSpells()
    auraData       = {}
    displayEntries = {}
    unitAuraCache  = {}

    local _, class = UnitClass("player")
    local specID   = GetPlayerSpecID()
    if not class or not specID then return end

    local spellList = CLASS_SPELLS[class]
    if not spellList then return end

    local entryMap = {}

    for _, spell in ipairs(spellList) do
        local validSpec = false
        for _, sid in ipairs(spell.specIDs) do
            if sid == specID then validSpec = true; break end
        end
        if validSpec then
            auraData[spell.id] = { count = 0, minExpiry = math.huge, maxExpiry = 0 }

            if spell.hidden then
                local parent = entryMap[spell.dbKey]
                if parent then table.insert(parent.spellIDs, spell.id) end
            else
                local info  = C_Spell.GetSpellInfo(spell.id)
                local entry = {
                    label    = spell.name,
                    dbKey    = spell.dbKey,
                    spellIDs = { spell.id },
                    color    = spell.color,
                    texID    = info and info.iconID or FALLBACK_ICON,
                }
                table.insert(displayEntries, entry)
                entryMap[spell.dbKey] = entry
            end
        end
    end
end

local eventFrame = CreateFrame("Frame", "ACT_HotTracker_Events", UIParent)

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        if pendingUpdate then
            pendingUpdate = false
            HotTracker:UpdateState()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        lastCombatResync = GetTime()
        UpdateIcons()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        RebuildTrackedSpells()
        ResyncAll()
        UpdateIcons()

    elseif event == "GROUP_ROSTER_UPDATE" then
        local currentUnits = {}
        for _, unit in ipairs(GetGroupUnits()) do
            currentUnits[unit] = true
            if not unitAuraCache[unit] then
                ResyncUnit(unit, inCombat)
            end
        end
        for unit in pairs(unitAuraCache) do
            if not currentUnits[unit] then unitAuraCache[unit] = nil end
        end
        UpdateIcons()

    elseif event == "UNIT_AURA" then
        local unit, info = ...
        if UnitIsUnit(unit, "player") then unit = "player" end
        if unitAuraCache[unit] or (info == nil or info.isFullUpdate) then
            HandleUnitAuraEvent(unit, info)
            UpdateIcons()
        end
    end
end)

local ST = nil

local function Hidden(expKey)
    return function() return not DBVal(expKey) end
end

local function Exp(expKey, label)
    return {
        kind    = LEM.SettingType.Expander,
        name    = label,
        default = DEFAULTS[expKey],
        get     = function() return DBVal(expKey) end,
        set     = function(_, v) local db = GetDB(); if db then db[expKey] = v end end,
    }
end

local function Setting(kind, name, opts)
    local expKey = opts.hidden
    return {
        kind       = kind,
        name       = name,
        default    = opts.default,
        minValue   = opts.min,
        maxValue   = opts.max,
        valueStep  = opts.step,
        values     = opts.values,
        height     = opts.height,
        hasOpacity = opts.hasOpacity,
        hidden     = expKey and (type(expKey) == "function" and expKey or Hidden(expKey)) or nil,
        get = opts.get or function() return DBVal(opts.dbKey) end,
        set = opts.set or function(_, v)
            local db = GetDB(); if db then db[opts.dbKey] = v end
            UpdateIcons()
        end,
    }
end

local function Chk(name, dbKey, default, expKey)
    return Setting(ST.Checkbox, name, { dbKey = dbKey, default = default, hidden = expKey })
end

local function Sld(name, dbKey, min, max, step, default, expKey)
    return Setting(ST.Slider, name, { dbKey = dbKey, default = default, min = min, max = max, step = step, hidden = expKey })
end

local function Drp(name, dbKey, values, default, expKey)
    return Setting(ST.Dropdown, name, { dbKey = dbKey, default = default, values = values, hidden = expKey })
end

local function DrpFont(name, dbKey, expKey)
    local vals = {}
    if LSM then
        for _, n in ipairs(LSM:List("font")) do vals[#vals + 1] = { text = n, value = n } end
    else
        vals[1] = { text = DEFAULT_FONT_FACE, value = DEFAULT_FONT_FACE }
    end
    return Setting(ST.Dropdown, name, { dbKey = dbKey, default = DEFAULT_FONT_FACE, values = vals, height = 300, hidden = expKey })
end

local function DrpBorder(name, dbKey, expKey)
    local vals = { { text = "None", value = "None" } }
    if LSM then
        for _, n in ipairs(LSM:List("border")) do
            if n ~= "None" then vals[#vals + 1] = { text = n, value = n } end
        end
    end
    return Setting(ST.Dropdown, name, { dbKey = dbKey, default = "None", values = vals, height = 300, hidden = expKey })
end

local function Clr(name, dbKey, expKey)
    local d = COLOR_DEFAULTS[dbKey] or {1, 1, 1, 1}
    return Setting(ST.ColorPicker, name, {
        dbKey      = dbKey,
        default    = CreateColor(d[1], d[2], d[3], d[4]),
        hasOpacity = false,
        hidden     = expKey,
        get        = function() return DBColor(dbKey) end,
    })
end

local function GetEditModeSettings()
    if not LEM then return {} end
    ST = LEM.SettingType

    local s = {}
    local function add(t) s[#s + 1] = t end

    add(Exp("exp_icon", "Icon"))
    add(Drp("Show",    "showWhen",    SHOW_WHEN_VALUES, "always", "exp_icon"))
    add(Sld("Size",    "iconSize",    20, 64,  1, 36,  "exp_icon"))
    add(Sld("Spacing", "iconPad",     0,  20,  1, 4,   "exp_icon"))
    add(Sld("Opacity", "iconOpacity", 0, 100,  1, 100, "exp_icon"))

    add(Exp("exp_bg", "Background"))
    add(Chk("Enable Background", "bgEnabled", false,         "exp_bg"))
    add(Clr("Color",             "bgColor",                  "exp_bg"))
    add(Sld("Opacity",           "bgOpacity", 0, 100, 1, 50, "exp_bg"))

    add(Exp("exp_border", "Border"))
    add(Chk("Enable Border",  "borderEnabled", false,           "exp_border"))
    add(DrpBorder("Texture",  "borderTexture",                  "exp_border"))
    add(Sld("Size",           "borderSize",    1, 32, 1, 12,   "exp_border"))
    add(Clr("Color",          "borderColor",                    "exp_border"))
    add(Sld("Opacity",        "borderOpacity", 0, 100, 1, 100, "exp_border"))

    add(Exp("exp_count", "Stack Count"))
    add(Chk("Show Count", "countEnabled", true,                   "exp_count"))
    add(Drp("Anchor",     "countAnchor",  ANCHOR_POINTS, "TOPLEFT", "exp_count"))
    add(Sld("Offset X",   "countOffsetX", -30, 30, 1, 1,          "exp_count"))
    add(Sld("Offset Y",   "countOffsetY", -30, 30, 1, -1,         "exp_count"))
    add(DrpFont("Font",   "countFace",                             "exp_count"))
    add(Sld("Font Size",  "countSize",    7, 24, 1, 11,            "exp_count"))
    add(Drp("Outline",    "countOutline", OUTLINE_VALUES, "OUTLINE", "exp_count"))
    add(Clr("Color",      "countColor",                            "exp_count"))

    add(Exp("exp_timer", "Timer"))
    add(Chk("Show Timer", "timerEnabled", true,                        "exp_timer"))
    add(Drp("Anchor",     "timerAnchor",  ANCHOR_POINTS, "BOTTOMRIGHT", "exp_timer"))
    add(Sld("Offset X",   "timerOffsetX", -30, 30, 1, -1,             "exp_timer"))
    add(Sld("Offset Y",   "timerOffsetY", -30, 30, 1,  1,             "exp_timer"))
    add(DrpFont("Font",   "timerFace",                                 "exp_timer"))
    add(Sld("Font Size",  "timerSize",    7, 24, 1, 10,                "exp_timer"))
    add(Drp("Outline",    "timerOutline", OUTLINE_VALUES, "OUTLINE",   "exp_timer"))
    add(Clr("Color",      "timerColor",                                "exp_timer"))
    add(Drp("Decimals",   "timerDecimals", {
        { text = "1",    value = 0 },
        { text = "1.1",  value = 1 },
        { text = "1.11", value = 2 },
    }, 1, "exp_timer"))

    add(Exp("exp_spells", "Tracked Spells"))
    local seenKeys = {}
    for className, spellList in pairs(CLASS_SPELLS) do
        local classLabel = className:sub(1, 1) .. className:sub(2):lower()
        for _, spell in ipairs(spellList) do
            if not spell.hidden and not seenKeys[spell.dbKey] then
                seenKeys[spell.dbKey] = true
                local key   = spell.dbKey
                local label = spell.name .. " (" .. classLabel .. ")"
                add({
                    kind    = ST.Checkbox,
                    name    = label,
                    default = true,
                    hidden  = Hidden("exp_spells"),
                    get     = function()
                        local db = GetDB()
                        if not db or db[key] == nil then return true end
                        return db[key]
                    end,
                    set     = function(_, v)
                        local db = GetDB(); if db then db[key] = v end
                        UpdateIcons()
                    end,
                })
            end
        end
    end

    return s
end

local function OnLayoutChanged(frame, layoutName, point, x, y)
    local db = GetDB()
    if not db then return end
    db.pos = db.pos or {}
    db.pos[layoutName] = { point = point, x = x, y = y }
end

function HotTracker:UpdateState()
    if InCombatLockdown() then
        pendingUpdate = true
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    if not ACT.db or not ACT.db.profile then return end

    local profile = ACT.db.profile
    profile.hot_tracker = profile.hot_tracker or {}
    local db = profile.hot_tracker

    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    for key, rgba in pairs(COLOR_DEFAULTS) do
        if db[key] == nil then db[key] = CreateColor(rgba[1], rgba[2], rgba[3], 1) end
    end

    eventFrame:UnregisterAllEvents()

    if db.enabled then
        eventFrame:RegisterEvent("UNIT_AURA")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

        inCombat = UnitAffectingCombat("player") == true

        RebuildTrackedSpells()
        ResyncAll()
        UpdateIcons()
        StartTicker()

        if LEM and LEM:IsInEditMode() then
            ApplyEditModeBackdrop()
        end
    else
        StopTicker()
        for _, ic in ipairs(icons) do
            ic:Hide()
            if ic.border then ic.border:Hide() end
        end
        display:Hide()
    end

    if LEM then
        if db.enabled and not anchor.editModeRegistered then
            LEM:AddFrame(anchor, OnLayoutChanged, { point = "CENTER", x = ANCHOR_DEFAULT_X, y = ANCHOR_DEFAULT_Y }, "HoT Tracker")
            LEM:AddFrameSettings(anchor, GetEditModeSettings())
            anchor.editModeRegistered = true

            if LEM.GetActiveLayoutName then
                local layout = LEM:GetActiveLayoutName()
                local pos    = db.pos and db.pos[layout]
                if pos then
                    anchor:ClearAllPoints()
                    anchor:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
                end
            end
        elseif not db.enabled and anchor.editModeRegistered then
            if LEM.frameSelections and LEM.frameSelections[anchor] then
                LEM.frameSelections[anchor]:Hide()
            end
        end
    end
end

function HotTracker:Initialize()
    anchor = CreateFrame("Frame", "ACT_HotTracker_Anchor", UIParent)
    anchor:SetSize(ANCHOR_DEFAULT_W, ANCHOR_DEFAULT_H)
    anchor:SetPoint("CENTER", UIParent, "CENTER", ANCHOR_DEFAULT_X, ANCHOR_DEFAULT_Y)
    anchor:SetFrameStrata("MEDIUM")
    anchor:Show()

    display = CreateFrame("Frame", "ACT_HotTracker_Display", UIParent, "BackdropTemplate")
    display:SetAllPoints(anchor)
    display:SetFrameStrata("MEDIUM")
    display:SetFrameLevel(anchor:GetFrameLevel())
    display:Hide()

    self:UpdateState()

    if LEM then
        LEM:RegisterCallback("enter", function()
            if DBVal("enabled") then
                ApplyEditModeBackdrop()
                bgBackdropApplied = false
            end
        end)

        LEM:RegisterCallback("exit", function()
            display:SetBackdrop(nil)
            bgBackdropApplied = false
            UpdateIcons()
        end)

        LEM:RegisterCallback("layout", function(layoutName)
            if not DBVal("enabled") or not LEM:IsInEditMode() then return end
            local db  = GetDB()
            local pos = db and db.pos and db.pos[layoutName]
            anchor:ClearAllPoints()
            if pos then
                anchor:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
            else
                anchor:SetPoint("CENTER", UIParent, "CENTER", ANCHOR_DEFAULT_X, ANCHOR_DEFAULT_Y)
            end
        end)
    end
end
