local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then return end

local bars = {}

local function FindUnitByName(name)
    if UnitName("player") == name then
        return "player"
    end

    for i = 1, GetNumGroupMembers() do
        local unit = "raid"..i
        if UnitName(unit) == name then
            return unit
        end
    end

    return nil
end

local function Update(unit, realmIncludedName, oldNickname, newNickname)
    if not GMRT then return end
    for bar in pairs(bars) do
        if bar.unit and UnitIsUnit(bar.unit, unit) then
            bar:UpdateText()
        end
    end
end

local function UpdateAll()
    if not GMRT then return end
    for bar in pairs(bars) do
        bar:UpdateText()
    end
end

local function Enable()
    if not ACT_AccountDB.nickname_integrations then ACT_AccountDB.nickname_integrations = {} end
    ACT_AccountDB.nickname_integrations.MRT = true
    UpdateAll()
end

local function Disable()
    if not ACT_AccountDB.nickname_integrations then ACT_AccountDB.nickname_integrations = {} end
    ACT_AccountDB.nickname_integrations.MRT = false
    UpdateAll()
end

local function Init()
    if not GMRT or not GMRT.F then return end
    
    GMRT.F:RegisterCallback("RaidCooldowns_Bar_Created", function(_, bar) bars[bar] = true end)
    GMRT.F:RegisterCallback("RaidCooldowns_Bar_Released", function(_, bar) bars[bar] = nil end)

    -- Follow bart's advise, revisit in the future if needeed
    C_Timer.After(0, function()
        if GMRT and GMRT.F then
            GMRT.F:RegisterCallback("RaidCooldowns_Bar_TextName", function(_, _, gsubData)
                if gsubData and gsubData.name and ACT_AccountDB and ACT_AccountDB.nickname_integrations and ACT_AccountDB.nickname_integrations.MRT then
                    
                    local unit = FindUnitByName(gsubData.name)

                    if unit and ACT:HasNickname(unit) then
                        gsubData.name = ACT:GetRawNickname(unit) --
                    end
                end
            end)
        end
    end)
    UpdateAll()
end

NicknameModule.nicknameFunctions["MRT"] = {
    Enable = Enable,
    Disable = Disable,
    Update = Update, 
    Init = Init
}