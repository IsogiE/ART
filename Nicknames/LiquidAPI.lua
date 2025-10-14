-- Might as well keep it supported for now till prepatch, and in case they somehow keep using it in the future
-- Thanks Ironi <3
local unitIDs = {
    player = true,
    focus = true,
    focustarget = true,
    target = true,
    targettarget = true,
    mouseover = true,
    npc = true,
    vehicle = true,
    pet = true
}

for i = 1, 4 do
    unitIDs["party" .. i] = true
    unitIDs["party" .. i .. "target"] = true
end

for i = 1, 40 do
    unitIDs["raid" .. i] = true
    unitIDs["raid" .. i .. "target"] = true
end

for i = 1, 40 do
    unitIDs["nameplate" .. i] = true
    unitIDs["nameplate" .. i .. "target"] = true
end

for i = 1, 15 do
    unitIDs["boss" .. i .. "target"] = true
end

local LiquidAPI = {
    GetName = function(_, characterName, formatting, atlasSize)
        if not characterName then
            error("LiquidAPI:GetName(characterName[, formatting, atlasSize]), characterName is nil")
            return
        end

        local unit
        local lowerCharName = characterName:lower()

        if unitIDs[lowerCharName] and UnitExists(lowerCharName) then
            unit = lowerCharName
        elseif ACT and ACT.GetCharacterInGroup then
            unit = ACT:GetCharacterInGroup(characterName)
            if not unit then
                for i = 1, GetNumGroupMembers() do
                    local currentUnit = "raid" .. i
                    if UnitExists(currentUnit) then
                        local name = UnitNameUnmodified(currentUnit)
                        if name and name:lower() == lowerCharName then
                            unit = currentUnit
                            break
                        end
                    end
                end
            end
        end

        local displayName
        if unit and ACT and ACT.GetNickname then
            displayName = ACT:GetNickname(unit)
        else
            displayName = characterName
        end

        if not formatting then
            return displayName
        end

        if not unit then
            return displayName, "%s", ""
        end

        local classFileName = UnitClassBase(unit)
        local colorStr = (classFileName and RAID_CLASS_COLORS[classFileName] and
                             RAID_CLASS_COLORS[classFileName].colorStr) or "ffffffff"
        local colorFormat = string.format("|c%s%%s|r", colorStr)

        local role = UnitGroupRolesAssigned(unit)
        local roleAtlas = (role == "TANK" and "Role-Tank-SM") or (role == "HEALER" and "Role-Healer-SM") or
                              (role == "DAMAGER" and "Role-DPS-SM")
        local roleIcon = roleAtlas and CreateAtlasMarkup(roleAtlas, atlasSize or 12, atlasSize or 12) or ""

        return displayName, colorFormat, roleIcon, RAID_CLASS_COLORS[classFileName] or {}
    end,

    GetCharacterInGroup = function(_, nickname)
        if not nickname or not ACT or not ACT.GetCharacterInGroup then
            return nil
        end

        local unit = ACT:GetCharacterInGroup(nickname)

        if unit and UnitExists(unit) then
            local characterName = UnitNameUnmodified(unit)
            local guid = UnitGUID(unit)
            local classFileName = UnitClassBase(unit)

            if characterName and guid and classFileName and RAID_CLASS_COLORS[classFileName] then
                local colorFormat = string.format("|c%s%%s|r", RAID_CLASS_COLORS[classFileName].colorStr)
                return characterName, colorFormat, guid
            end
        end

        return nil
    end,

    GetCharacters = function(_, nickname)
        if not nickname then
            error("LiquidAPI:GetCharacters(nickname), nickname is nil")
            return
        end

        local chars = {}
        local found = false

        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and ACT and ACT.HasNickname and ACT:HasNickname(unit) then
                local currentNickname = ACT:GetNickname(unit)
                if currentNickname and currentNickname:lower() == nickname:lower() then
                    local unitName = UnitNameUnmodified(unit)
                    if unitName then
                        chars[unitName] = true
                        found = true
                    end
                end
            end
        end

        if found then
            return chars
        end
        return nil
    end
}

_G.LiquidAPI = LiquidAPI
