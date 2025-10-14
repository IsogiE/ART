local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then
    return
end

local tagFuncs = {
    ["name"] = [[function(_, unitOwner)
        if ACT_AccountDB and ACT_AccountDB.nickname_integrations.ShadowedUnitFrames and ACT:HasNickname(unitOwner) then
            local nickname = ACT:GetRawNickname(unitOwner)
            local _, class = UnitClass(unitOwner)
            if class and RAID_CLASS_COLORS[class] then
                -- Return two values: the text and a format string. SUF will combine them.
                return nickname, string.format("|c%s%%s|r", RAID_CLASS_COLORS[class].colorStr)
            end
            return nickname
        end
        return UnitName(unitOwner) or UNKNOWN
    end]],

    ["abbrev:name"] = [[function(_, unitOwner)
        if ACT_AccountDB and ACT_AccountDB.nickname_integrations.ShadowedUnitFrames and ACT:HasNickname(unitOwner) then
            local nickname = ACT:GetRawNickname(unitOwner)
            local _, class = UnitClass(unitOwner)
            if class and RAID_CLASS_COLORS[class] then
                return nickname, string.format("|c%s%%s|r", RAID_CLASS_COLORS[class].colorStr)
            end
            return nickname
        end
        local name = UnitName(unitOwner) or UNKNOWN
        return string.len(name) > 10 and ShadowUF.Tags.abbrevCache[name] or name
    end]],

    ["colorname"] = [[function(_, unitOwner)
		local color = ShadowUF:GetClassColor(unitOwner)
        local useNickname = ACT_AccountDB and ACT_AccountDB.nickname_integrations.ShadowedUnitFrames and ACT:HasNickname(unitOwner)

        if useNickname then
            local nickname = ACT:GetRawNickname(unitOwner)
            if not color then
                return nickname
            end
            return string.format("%s%s|r", color, nickname)
        else
            local name = UnitName(unitOwner) or UNKNOWN
            if not color then
                return name
            end
            return string.format("%s%s|r", color, name)
        end
	end]]
}

local function Update()
    if ShadowUF and ShadowUF.Tags and ShadowUF.Tags.Reload then
        ShadowUF.Tags:Reload()
    end
end

local function Enable()
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations.ShadowedUnitFrames = true
        Update()
    end
end

local function Disable()
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations.ShadowedUnitFrames = false
        Update()
    end
end

local function Init()
    if not ShadowUF then
        return
    end

    hooksecurefunc(ShadowUF, "OnInitialize", function()
        for tagName, tagFunc in pairs(tagFuncs) do
            if ShadowUF.Tags.defaultTags then
                ShadowUF.Tags.defaultTags[tagName] = tagFunc
            end
        end
        Update()
    end)
end

NicknameModule.nicknameFunctions["ShadowedUnitFrames"] = {
    Enable = Enable,
    Disable = Disable,
    Update = Update,
    Init = Init
}
