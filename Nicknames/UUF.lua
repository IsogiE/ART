local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then return end

local function GetColorHex(unit)
    local _, class = UnitClass(unit)
    if class then
        local color = RAID_CLASS_COLORS[class]
        if color then
            return string.format("ff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
        end
    end
    return "ffffffff"
end

local function ShortenString(text, maxChars)
    if not text then return "" end
    if maxChars and string.len(text) > maxChars then
        return string.sub(text, 1, maxChars)
    end
    return text
end

local function GetName(unit)
    local realName = (_G.UnitNameUnmodified and _G.UnitNameUnmodified(unit)) or UnitName(unit) or ""
    
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations and ACT_AccountDB.nickname_integrations.UnhaltedUnitFrames then
        if ACT:HasNickname(unit) then
            return ACT:GetRawNickname(unit)
        end
    end
    
    return realName
end

local function RegisterTags()
    if not UUFG then return end

    UUFG:AddTag("act:name", "UNIT_NAME_UPDATE", GetName, "Name", "[ACT] Nickname")
    
    UUFG:AddTag("act:name:colour", "UNIT_NAME_UPDATE", function(unit)
        return string.format("|c%s%s|r", GetColorHex(unit), GetName(unit))
    end, "Name", "[ACT] Nickname (Colored)")

    UUFG:AddTag("act:name:short", "UNIT_NAME_UPDATE", function(unit)
        return ShortenString(GetName(unit), 10)
    end, "Name", "[ACT] Nickname (Short)")
end

local function Update()
    if UUFG and UUFG.UpdateAllTags then
        UUFG:UpdateAllTags()
    end
end

NicknameModule.nicknameFunctions["UnhaltedUnitFrames"] = {
    Enable = Update,
    Disable = Update,
    Update = Update,
    Init = function() 
        RegisterTags() 
        Update() 
    end
}

RegisterTags()