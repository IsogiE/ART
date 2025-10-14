local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then
    return
end

local nicknameMethods = {}

local function UpdateAll()
    if not ElvUF then
        return
    end

    for tagName in pairs(nicknameMethods) do
        ElvUF.Tags:RefreshMethods(tagName)
    end

    ElvUF.Tags:RefreshMethods("nickname")
    for i = 1, 12 do
        ElvUF.Tags:RefreshMethods("nickname-len" .. i)
    end
end

local function Update(unit)
    UpdateAll()
end

local function Enable()
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations.ElvUI = true
    end
    UpdateAll()
end

local function Disable()
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations.ElvUI = false
    end
    UpdateAll()
end

local function Init()
    if not ElvUI or not ElvUF then
        return
    end

    local E, L = unpack(ElvUI)
    local _TAGS = ElvUF.Tags.Methods
    local NameHealthColor = ElvUF.Tags.Env.NameHealthColor
    local Translit = E.Libs.Translit
    local translitMark = '!'

    nicknameMethods = {
        ["name"] = function(unit)
            return ACT:GetNickname(unit)
        end,
        ["name:health"] = function(unit, _, args)
            local name = ACT:GetNickname(unit)
            local min, max, bco, fco = UnitHealth(unit), UnitHealthMax(unit), strsplit(':', args or '')
            local to = math.ceil(string.utf8len(name) * (min / max))
            local fill = NameHealthColor(_TAGS, fco, unit, '|cFFff3333')
            local base = NameHealthColor(_TAGS, bco, unit, '|cFFffffff')
            return
                to > 0 and (base .. string.utf8sub(name, 0, to) .. fill .. string.utf8sub(name, to + 1, -1)) or fill ..
                    name
        end,
        ["name:first"] = function(unit)
            return ACT:GetNickname(unit)
        end,
        ["name:last"] = function(unit)
            return ACT:GetNickname(unit)
        end,
        ["name:veryshort"] = function(unit)
            local name = ACT:GetNickname(unit)
            return E:ShortenString(name, 5)
        end,
        ["name:veryshort:status"] = function(unit)
            local status = UnitIsDead(unit) and L["Dead"] or UnitIsGhost(unit) and L["Ghost"] or
                               not UnitIsConnected(unit) and L["Offline"]
            if status then
                return status
            end
            local name = ACT:GetNickname(unit)
            return E:ShortenString(name, 5)
        end,
        ["name:veryshort:translit"] = function(unit)
            local nickname = ACT:GetNickname(unit)
            local name = Translit:Transliterate(nickname, translitMark)
            if name then
                return E:ShortenString(name, 5)
            end
        end,
        ["name:short"] = function(unit)
            local name = ACT:GetNickname(unit)
            return E:ShortenString(name, 10)
        end,
        ["name:short:status"] = function(unit)
            local status = UnitIsDead(unit) and L["Dead"] or UnitIsGhost(unit) and L["Ghost"] or
                               not UnitIsConnected(unit) and L["Offline"]
            if status then
                return status
            end
            local name = ACT:GetNickname(unit)
            return E:ShortenString(name, 10)
        end,
        ["name:short:translit"] = function(unit)
            local nickname = ACT:GetNickname(unit)
            local name = Translit:Transliterate(nickname, translitMark)
            if name then
                return E:ShortenString(name, 10)
            end
        end,
        ["name:medium"] = function(unit)
            return ACT:GetNickname(unit)
        end,
        ["name:medium:status"] = function(unit)
            local status = UnitIsDead(unit) and L["Dead"] or UnitIsGhost(unit) and L["Ghost"] or
                               not UnitIsConnected(unit) and L["Offline"]
            if status then
                return status
            end
            return ACT:GetNickname(unit)
        end,
        ["name:medium:translit"] = function(unit)
            local nickname = ACT:GetNickname(unit)
            local name = Translit:Transliterate(nickname, translitMark)
            if name then
                return E:ShortenString(name, 15)
            end
        end,
        ["name:long"] = function(unit)
            return ACT:GetNickname(unit)
        end,
        ["name:long:status"] = function(unit)
            local status = UnitIsDead(unit) and L["Dead"] or UnitIsGhost(unit) and L["Ghost"] or
                               not UnitIsConnected(unit) and L["Offline"]
            if status then
                return status
            end
            return ACT:GetNickname(unit)
        end,
        ["name:long:translit"] = function(unit)
            local nickname = ACT:GetNickname(unit)
            local name = Translit:Transliterate(nickname, translitMark)
            if name then
                return E:ShortenString(name, 20)
            end
        end,
        ["name:abbrev"] = function(unit)
            return ACT:GetNickname(unit)
        end,
        ["name:abbrev:veryshort"] = function(unit)
            local name = ACT:GetNickname(unit)
            return E:ShortenString(name, 5)
        end,
        ["name:abbrev:short"] = function(unit)
            local name = ACT:GetNickname(unit)
            return E:ShortenString(name, 10)
        end,
        ["name:abbrev:medium"] = function(unit)
            return ACT:GetNickname(unit)
        end,
        ["name:abbrev:long"] = function(unit)
            return ACT:GetNickname(unit)
        end
    }

    for tagName, NicknameMethod in pairs(nicknameMethods) do
        local OriginalMethod = _TAGS[tagName]
        if OriginalMethod then
            _TAGS[tagName] = function(unit, _, args)
                local useNickname = ACT_AccountDB and ACT_AccountDB.nickname_integrations and
                                        ACT_AccountDB.nickname_integrations.ElvUI and ACT:HasNickname(unit)
                if useNickname then
                    return NicknameMethod(unit, _, args)
                else
                    return OriginalMethod(unit, _, args)
                end
            end
        end
    end

    E:AddTag("nickname", "UNIT_NAME_UPDATE", function(unit)
        return ACT:GetNickname(unit) or ""
    end)

    for i = 1, 12 do
        E:AddTag("nickname-len" .. i, "UNIT_NAME_UPDATE", function(unit)
            local nickname = ACT:GetNickname(unit)
            return nickname and strsub(nickname, 1, i) or ""
        end)
    end

    UpdateAll()
end

NicknameModule.nicknameFunctions["ElvUI"] = {
    Enable = Enable,
    Disable = Disable,
    Update = Update,
    Init = Init
}
