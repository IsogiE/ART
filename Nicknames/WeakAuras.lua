local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then return end

local function Update() end

local function Enable()
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations.WeakAuras = true
    end
end

local function Disable()
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations.WeakAuras = false
    end
end

local function Init()
    if not WeakAuras then return end

    local WA_GetName = WeakAuras.GetName
    local WA_UnitName = WeakAuras.UnitName
    local WA_GetUnitName = WeakAuras.GetUnitName
    local WA_UnitFullName = WeakAuras.UnitFullName

    if WA_GetName then
        WeakAuras.GetName = function(name)
            if not name then return end

            if ACT_AccountDB.nickname_integrations.WeakAuras and ACT:HasNickname(name) then
                local nickname = ACT:GetRawNickname(name)

                local formatString = "%s"
                local classFileName = UnitClassBase(name)
                if classFileName and RAID_CLASS_COLORS[classFileName] then
                    formatString = string.format("|c%s%%s|r", RAID_CLASS_COLORS[classFileName].colorStr)
                end
                
                return nickname, formatString
            end
            return WA_GetName(name)
        end
    end

    if WA_UnitName then
        WeakAuras.UnitName = function(unit)
            if ACT_AccountDB.nickname_integrations.WeakAuras and ACT:HasNickname(unit) then
                return ACT:GetRawNickname(unit), select(2, UnitName(unit))
            end
            return WA_UnitName(unit)
        end
    end

    if WA_GetUnitName then
        WeakAuras.GetUnitName = function(unit, showServerName)
            if not unit then return end

            if ACT_AccountDB.nickname_integrations.WeakAuras and ACT:HasNickname(unit) then
                if not UnitIsPlayer(unit) then
                    return GetUnitName(unit, showServerName)
                end
                
                local nickname = ACT:GetRawNickname(unit)
                local originalFullName = GetUnitName(unit, showServerName)
                
                local suffix = originalFullName:match(".+(%s%b())") or originalFullName:match(".+(%-[^%-]+)$") or ""

                return nickname .. suffix
            end
            return WA_GetUnitName(unit, showServerName)
        end
    end

    if WA_UnitFullName then
        WeakAuras.UnitFullName = function(unit)
            if not unit then return end
            
            if ACT_AccountDB.nickname_integrations.WeakAuras and ACT:HasNickname(unit) then
                local _, realm = UnitFullName(unit)
                return ACT:GetRawNickname(unit), realm
            end
            return WA_UnitFullName(unit)
        end
    end
end

NicknameModule.nicknameFunctions["WeakAuras"] = {
    Enable = Enable,
    Disable = Disable,
    Update = Update,
    Init = Init
}