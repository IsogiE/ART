local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then return end

local nicknameMethods = {}
local tags

local function GetColoredNickname(unit, maxChars)
    local name = ACT:GetNickname(unit)

    if name and maxChars then
        name = string.sub(name, 1, maxChars)
    end

    local class = UnitClassBase(unit)
    local color = class and C_ClassColor.GetClassColor(class)

    if color then
        return color:WrapTextInColorCode(name)
    else
        return name
    end
end

local function Update()
    if not UUFG then return end
    if not tags then return end

    for tagName in pairs(nicknameMethods) do
        tags:RefreshMethods(tagName)
    end
end

local function Enable()
    if not ACT_AccountDB then ACT_AccountDB = {} end
    if not ACT_AccountDB.nickname_integrations then ACT_AccountDB.nickname_integrations = {} end
    ACT_AccountDB.nickname_integrations.UnhaltedUnitFrames = true

    Update()
end

local function Disable()
    if not ACT_AccountDB then ACT_AccountDB = {} end
    if not ACT_AccountDB.nickname_integrations then ACT_AccountDB.nickname_integrations = {} end
    ACT_AccountDB.nickname_integrations.UnhaltedUnitFrames = false

    Update()
end

local function Init()
    if not UUFG then return end
    if not UUFG.GetTags then return end

    tags = UUFG:GetTags()

    nicknameMethods = {
        ["name"] = function(unit)
            return ACT:GetNickname(unit)
        end,
        ["name:colour"] = function(unit)
            return GetColoredNickname(unit)
        end,
    }

    for i = 1, 25 do
        nicknameMethods["name:short:" .. i] = function(unit)
            local name = ACT:GetNickname(unit)
            return name and string.sub(name, 1, i)
        end
    end

    for i = 1, 25 do
        nicknameMethods["name:short:" .. i .. ":colour"] = function(unit)
            return GetColoredNickname(unit, i)
        end
    end

    for tagName, NicknameMethod in pairs(nicknameMethods) do
        local OriginalMethod = tags.Methods[tagName]

        if OriginalMethod then
            tags.Methods[tagName] = function(unit)
                local useNickname = ACT_AccountDB
                    and ACT_AccountDB.nickname_integrations
                    and ACT_AccountDB.nickname_integrations.UnhaltedUnitFrames
                    and ACT:HasNickname(unit)

                if useNickname then
                    return NicknameMethod(unit)
                else
                    return OriginalMethod(unit)
                end
            end
        end
    end

    Update()
end

NicknameModule.nicknameFunctions["UnhaltedUnitFrames"] = {
    Enable = Enable,
    Disable = Disable,
    Update = Update,
    Init = Init
}
