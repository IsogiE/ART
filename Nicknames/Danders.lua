local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then
    return
end

local DF
local originalGetUnitName

local function GetDF()
    if DF then return DF end
    DF = _G.DandersFrames
    return DF
end

local function GetUnitNameHook(self, unit)
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations and ACT_AccountDB.nickname_integrations.DandersFrames and ACT:HasNickname(unit) then
        return ACT:GetNickname(unit)
    end
    
    if originalGetUnitName then
        return originalGetUnitName(self, unit)
    end
    
    return UnitName(unit)
end

local function Update()
    local Danders = GetDF()
    if not Danders then return end

    if Danders.IterateCompactFrames then
        Danders:IterateCompactFrames(function(frame)
            if frame and frame:IsShown() and Danders.UpdateNameText then
                Danders:UpdateNameText(frame)
            end
        end)
    end
end

local function Enable()
    if not ACT_AccountDB then ACT_AccountDB = {} end
    if not ACT_AccountDB.nickname_integrations then ACT_AccountDB.nickname_integrations = {} end
    ACT_AccountDB.nickname_integrations.DandersFrames = true
    Update()
end

local function Disable()
    if not ACT_AccountDB then ACT_AccountDB = {} end
    if not ACT_AccountDB.nickname_integrations then ACT_AccountDB.nickname_integrations = {} end
    ACT_AccountDB.nickname_integrations.DandersFrames = false
    Update()
end

local function Init()
    local Danders = GetDF()
    if not Danders then return end

    if Danders.GetUnitName and Danders.GetUnitName ~= GetUnitNameHook then
        originalGetUnitName = Danders.GetUnitName
        Danders.GetUnitName = GetUnitNameHook
    end
    
    Update()
end

NicknameModule.nicknameFunctions["DandersFrames"] = {
    Enable = Enable,
    Disable = Disable,
    Update = Update,
    Init = Init
}

Init()