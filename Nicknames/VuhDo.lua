local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then
    return
end

local vuhDoHooks = {}
local vuhDoPanelSettings = {}

local function UpdateVuhDoName(unit, nameText, buttonName)
    if not unit or not UnitExists(unit) then
        return
    end

    local name
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations and ACT_AccountDB.nickname_integrations.VuhDo then
        name = ACT:GetNickname(unit)
    else
        name = UnitName(unit)
    end

    local panelNumber = buttonName and buttonName:match("^Vd(%d+)")
    panelNumber = tonumber(panelNumber)

    local maxChars = panelNumber and vuhDoPanelSettings[panelNumber] and vuhDoPanelSettings[panelNumber].maxChars

    if name and maxChars and maxChars > 0 then
        name = name:sub(1, maxChars)
    end

    nameText:SetFormattedText(name or "")
end

local function UpdateAll()
    if not VUHDO_UNIT_BUTTONS then
        return
    end

    for unit, unitButtons in pairs(VUHDO_UNIT_BUTTONS) do
        if UnitExists(unit) then
            for _, button in ipairs(unitButtons) do
                local unitButtonName = button:GetName()
                local nameText = _G[unitButtonName .. "BgBarIcBarHlBarTxPnlUnN"]
                if nameText then
                    UpdateVuhDoName(unit, nameText, unitButtonName)
                end
            end
        end
    end
end

local function Update(unit)
    if not VUHDO_UNIT_BUTTONS or not unit or not UnitExists(unit) then
        return
    end

    for vuhDoUnit, unitButtons in pairs(VUHDO_UNIT_BUTTONS) do
        if UnitIsUnit(unit, vuhDoUnit) then
            for _, button in ipairs(unitButtons) do
                local unitButtonName = button:GetName()
                local nameText = _G[unitButtonName .. "BgBarIcBarHlBarTxPnlUnN"]
                if nameText then
                    UpdateVuhDoName(unit, nameText, unitButtonName)
                end
            end
            break
        end
    end
end

local function Enable()
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations.VuhDo = true
    end
    UpdateAll()
end

local function Disable()
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations.VuhDo = false
    end
    UpdateAll()
end

local function Init()
    if not VUHDO_PANEL_SETUP or not VUHDO_getBarText then
        return
    end

    for i, settings in pairs(VUHDO_PANEL_SETUP) do
        if type(settings) == "table" and settings.PANEL_COLOR and settings.PANEL_COLOR.TEXT then
            vuhDoPanelSettings[i] = settings.PANEL_COLOR.TEXT
        end
    end

    hooksecurefunc("VUHDO_getBarText", function(unitHealthBar)
        local unitFrameName = unitHealthBar and unitHealthBar:GetName()
        if not unitFrameName then
            return
        end

        local nameText = _G[unitFrameName .. "TxPnlUnN"]
        if not nameText or vuhDoHooks[nameText] then
            return
        end

        local unitButton = _G[unitFrameName:match("(.+)BgBarIcBarHlBar")]
        if not unitButton then
            return
        end

        hooksecurefunc(nameText, "SetText", function(self)
            local unit = unitButton.raidid
            UpdateVuhDoName(unit, self, unitFrameName)
        end)

        vuhDoHooks[nameText] = true
    end)
end

NicknameModule.nicknameFunctions["VuhDo"] = {
    Enable = Enable,
    Disable = Disable,
    Update = Update,
    Init = Init
}
