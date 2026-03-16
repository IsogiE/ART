local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then
    return
end

local EQoL

local function GetEQoL()
    if EQoL then return EQoL end
    local addon = _G["EnhanceQoL"]
    if addon and addon.Aura and addon.Aura.UF and addon.Aura.UF.GroupFrames then
        EQoL = addon.Aura.UF.GroupFrames
    end
    return EQoL
end

local function PostUpdateName(self, frame)
    if not ACT_AccountDB
        or not ACT_AccountDB.nickname_integrations
        or not ACT_AccountDB.nickname_integrations.EnhanceQoL
    then
        return
    end

    local unit = frame and (frame.unit or (frame.GetAttribute and frame:GetAttribute("unit")))
    if not unit or not UnitIsPlayer(unit) or not ACT:HasNickname(unit) then return end

    local st = frame._eqolUFState
    local fs = st and (st.nameText or st.name)
    if not fs then return end

    if fs.IsShown and not fs:IsShown() then return end

    local nickname = ACT:GetNickname(unit)
    if not nickname or nickname == "" then return end

    local connected = UnitIsConnected and UnitIsConnected(unit)
    local displayName = nickname
    if connected == false then
        displayName = displayName .. " |cffff6666DC|r"
    end

    st._lastName = nil

    if fs.SetText then fs:SetText(displayName) end
end

local function ForceUpdate()
    local GF = GetEQoL()
    if not GF then return end
    if GF.RefreshNames then GF:RefreshNames() end
end

local function Update()
    if not ACT_AccountDB or not ACT_AccountDB.nickname_integrations or not ACT_AccountDB.nickname_integrations.EnhanceQoL then
        return
    end
    ForceUpdate()
end

local function Enable()
    if not ACT_AccountDB then ACT_AccountDB = {} end
    if not ACT_AccountDB.nickname_integrations then ACT_AccountDB.nickname_integrations = {} end
    ACT_AccountDB.nickname_integrations.EnhanceQoL = true
    ForceUpdate()
end

local function Disable()
    if not ACT_AccountDB then ACT_AccountDB = {} end
    if not ACT_AccountDB.nickname_integrations then ACT_AccountDB.nickname_integrations = {} end
    ACT_AccountDB.nickname_integrations.EnhanceQoL = false
    ForceUpdate()
end

local function Init()
    local GF = GetEQoL()
    if not GF then return end

    hooksecurefunc(GF, "UpdateName", PostUpdateName)

    Update()
end

NicknameModule.nicknameFunctions["EnhanceQoL"] = {
    Enable = Enable,
    Disable = Disable,
    Update = Update,
    Init = Init
}

Init()
