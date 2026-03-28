local addonName, NS = ...

if not ACT then return end

local DispellAssign = {}
ACT.DispellAssign = DispellAssign

local active = false
local healers = {}
local dwarfs = {}
local affected = {}
local healerassigned = {}
local lastAuraTime = nil

local myAssignedUnit = nil
local myAssignedAuraID = nil

local warnFrame = CreateFrame("Frame", "ACT_DispellAssign_WarnFrame", UIParent)
warnFrame:SetSize(400, 100)
warnFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200) 
warnFrame:Hide()

local warnText = warnFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
warnText:SetPoint("CENTER")

function DispellAssign:UpdateUI(show, text, isDwarf)
    if not show then
        warnFrame:Hide()
        myAssignedUnit = nil
        myAssignedAuraID = nil
        return
    end

    warnText:SetText(text)
    warnFrame:Show()
    
    -- TTS (Mirrors the WA's use of NSAPI, with a safe fallback)
    if NSAPI and NSAPI.TTS then
        NSAPI:TTS(isDwarf and "Use Dwarf" or "Dispel")
    elseif C_VoiceChat and C_VoiceChat.SpeakText and Enum and Enum.VoiceTtsDestination then
        C_VoiceChat.SpeakText(0, isDwarf and "Use Dwarf" or "Dispel", Enum.VoiceTtsDestination.LocalPlayback, 0, 100)
    end
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
    
    -- Insert Warlocks after healers
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
    if #affected > 15 then 
        wipe(affected)
        return 
    end

    table.sort(affected, function(a, b)
        return (a[2] or 999) < (b[2] or 999)
    end)

    lastAuraTime = nil
    wipe(healerassigned)

    -- Pass 1: Self-Dispel
    for i, v in ipairs(healers) do
        if not UnitIsDeadOrGhost(v) then
            for k, info in ipairs(affected) do
                if UnitIsUnit(info[1], v) then
                    info[4] = true
                    healerassigned[i] = true
                    if UnitIsUnit(v, "player") then
                        myAssignedUnit = info[1]
                        myAssignedAuraID = info[3]
                        local name = UnitName(info[1]) or info[1]
                        DispellAssign:UpdateUI(true, "|cff00ff00Dispel|r · |cffff44ff"..name.."|r", false)
                        C_Timer.After(9, function() DispellAssign:UpdateUI(false) end)
                        return
                    end
                    break 
                end
            end 
        end
    end
    
    -- Pass 2: Others
    for i, v in ipairs(healers) do
        if (not UnitIsDeadOrGhost(v)) and not healerassigned[i] then
            for k, info in ipairs(affected) do
                if not info[4] then
                    info[4] = true
                    healerassigned[i] = true
                    if UnitIsUnit(v, "player") then
                        myAssignedUnit = info[1]
                        myAssignedAuraID = info[3]
                        local name = UnitName(info[1]) or info[1]
                        DispellAssign:UpdateUI(true, "|cff00ff00Dispel|r · |cffff44ff"..name.."|r", false)
                        C_Timer.After(9, function() DispellAssign:UpdateUI(false) end)
                        return
                    end
                    break 
                end
            end 
        end
    end
    
    wipe(affected)
end

local eventFrame = CreateFrame("Frame")

function DispellAssign:Initialize()
    eventFrame:RegisterEvent("ENCOUNTER_START")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "ENCOUNTER_START" then
            active = true
            wipe(affected)
            DispellAssign:UpdateUI(false)
            BuildRoster()
            
        elseif event == "ENCOUNTER_END" then
            active = false
            DispellAssign:UpdateUI(false)
            wipe(affected)
            
        elseif event == "UNIT_AURA" then
            local unit, updateInfo = ...
            if not active then return end
            
            -- FIX FOR TAINT ERROR: Only process actual group members, ignore nameplates
            if not (unit == "player" or string.match(unit, "^raid%d+$") or string.match(unit, "^party%d+$")) then
                return
            end

            if updateInfo.addedAuras then
                for i, auraData in ipairs(updateInfo.addedAuras) do
                    local auraInstanceID = auraData.auraInstanceID
                    local isDebuff = not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HARMFUL")
                    
                    if isDebuff and auraData.dispelName ~= nil then
                        local now = GetTime()
                        
                        -- Batch timer (mirrors aura_env.last logic)
                        if not lastAuraTime or lastAuraTime < now - 3 then
                            lastAuraTime = now
                            wipe(affected)
                            C_Timer.After(0.2, RunAssignment)
                        end
                        
                        -- Dwarf Check
                        if dwarfs[unit] and now > dwarfs[unit] then
                            dwarfs[unit] = now + 121
                            if UnitIsUnit("player", unit) then
                                DispellAssign:UpdateUI(true, "|cffffd700USE DWARF RACIAL|r", true)
                                C_Timer.After(15, function() DispellAssign:UpdateUI(false) end)
                            end
                        else
                            local index = UnitInRaid(unit) or 999
                            table.insert(affected, {unit, index, auraInstanceID, false})
                        end
                    end
                end
            end
            
            -- Hide logic if aura drops (Mirrors WA removedAuraInstanceIDs loop)
            if updateInfo.removedAuraInstanceIDs and myAssignedAuraID and UnitIsUnit(unit, myAssignedUnit) then
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
