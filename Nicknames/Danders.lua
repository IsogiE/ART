local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then
    return
end

local function Update(unit)
    if not DandersFrames then return end

    local unitFrame = DandersFrames:GetFrameForUnit(unit)

    if not unitFrame then return end

    DandersFrames:UpdateName(unitFrame) 
end

local function UpdateAll()
    if not DandersFrames then return end

    for unitFrame in DandersFrames:IterateCompactFrames() do
        DandersFrames:UpdateName(unitFrame) 
    end
end

local function Enable()
    if not ACT_AccountDB then ACT_AccountDB = {} end
    if not ACT_AccountDB.nickname_integrations then ACT_AccountDB.nickname_integrations = {} end
    ACT_AccountDB.nickname_integrations.DandersFrames = true

    UpdateAll()
end

local function Disable()
    if not ACT_AccountDB then ACT_AccountDB = {} end
    if not ACT_AccountDB.nickname_integrations then ACT_AccountDB.nickname_integrations = {} end
    ACT_AccountDB.nickname_integrations.DandersFrames = false

    UpdateAll()
end

local function Init()
    if not DandersFrames then return end

    local OriginalFunction = DandersFrames.GetUnitName

    DandersFrames.GetUnitName = function(self, unit)
        local useNickname = ACT_AccountDB
            and ACT_AccountDB.nickname_integrations
            and ACT_AccountDB.nickname_integrations.DandersFrames
            and ACT:HasNickname(unit)

        if useNickname then
            return ACT:GetNickname(unit)
        else
            return OriginalFunction(self, unit)
        end
    end
end

NicknameModule.nicknameFunctions["DandersFrames"] = {
    Enable = Enable,
    Disable = Disable,
    Update = Update,
    Init = Init
}

Init()
