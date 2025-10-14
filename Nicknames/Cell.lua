local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then
    return
end

local unitButtonTables = {}

local function UpdateAll()
    if not Cell then
        return
    end

    for _, unitButtonTable in pairs(unitButtonTables) do
        for _, unitButton in pairs(unitButtonTable) do
            if type(unitButton) == "table" and unitButton.indicators and unitButton.indicators.nameText then
                if unitButton.states and unitButton.states.isPlayer then
                    unitButton.indicators.nameText:UpdateName()
                end
            end
        end
    end
end

local function Update(unit)
    if not Cell then
        return
    end

    for _, unitButtonTable in pairs(unitButtonTables) do
        for _, unitButton in pairs(unitButtonTable) do
            if type(unitButton) == "table" then
                if unitButton.unit and UnitIsUnit(unitButton.unit, unit) then
                    unitButton.indicators.nameText:UpdateName()
                end
            end
        end
    end
end

local function Enable()
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations.Cell = true
    end
    UpdateAll()
end

local function Disable()
    if ACT_AccountDB and ACT_AccountDB.nickname_integrations then
        ACT_AccountDB.nickname_integrations.Cell = false
    end
    UpdateAll()
end

local function Init()
    if not Cell then
        return
    end

    local F = Cell.funcs
    local LibTranslit = LibStub("LibTranslit-1.0")

    unitButtonTables = {Cell.unitButtons.solo, Cell.unitButtons.party, Cell.unitButtons.quickAssist,
                        Cell.unitButtons.spotlight, Cell.unitButtons.raid.CellRaidFrameHeader0,
                        Cell.unitButtons.raid.CellRaidFrameHeader1, Cell.unitButtons.raid.CellRaidFrameHeader2,
                        Cell.unitButtons.raid.CellRaidFrameHeader3, Cell.unitButtons.raid.CellRaidFrameHeader4,
                        Cell.unitButtons.raid.CellRaidFrameHeader5, Cell.unitButtons.raid.CellRaidFrameHeader6,
                        Cell.unitButtons.raid.CellRaidFrameHeader7, Cell.unitButtons.raid.CellRaidFrameHeader8}

    local function NicknameFunction(parent)
        local unit = parent == CellSoloFramePlayer and "player" or parent.unit
        local name = ACT:GetNickname(unit)
        local nameText = parent.indicators.nameText

        if Cell.loaded and CellDB["general"]["translit"] then
            name = LibTranslit:Transliterate(name)
        end

        F.UpdateTextWidth(nameText.name, name, nameText.width, parent.widgets.healthBar)

        if CELL_SHOW_GROUP_PET_OWNER_NAME and parent.isGroupPet then
            local owner = F.GetPlayerUnit(parent.states.unit)
            owner = UnitName(owner)
            if CELL_SHOW_GROUP_PET_OWNER_NAME == "VEHICLE" then
                F.UpdateTextWidth(nameText.vehicle, owner, nameText.width, parent.widgets.healthBar)
            elseif CELL_SHOW_GROUP_PET_OWNER_NAME == "NAME" then
                F.UpdateTextWidth(nameText.name, owner, nameText.width, parent.widgets.healthBar)
            end
        end

        if nameText.name:GetText() then
            if nameText.isPreview then
                if nameText.showGroupNumber then
                    nameText.name:SetText("|cffbbbbbb7-|r" .. nameText.name:GetText())
                end
            else
                if IsInRaid() and nameText.showGroupNumber then
                    local raidIndex = UnitInRaid(parent.states.unit)
                    if raidIndex then
                        local subgroup = select(3, GetRaidRosterInfo(raidIndex))
                        nameText.name:SetText("|cffbbbbbb" .. subgroup .. "-|r" .. nameText.name:GetText())
                    end
                end
            end
        end

        nameText:SetSize(nameText.name:GetWidth(), nameText.name:GetHeight())
    end

    for _, unitButtonTable in pairs(unitButtonTables) do
        for _, unitButton in pairs(unitButtonTable) do
            if type(unitButton) == "table" then
                local OriginalFunction = unitButton.indicators and unitButton.indicators.nameText and
                                             unitButton.indicators.nameText.UpdateName
                if OriginalFunction then
                    unitButton.indicators.nameText.UpdateName = function()
                        local unit = unitButton == CellSoloFramePlayer and "player" or unitButton.unit
                        local useNickname = ACT_AccountDB and ACT_AccountDB.nickname_integrations and
                                                ACT_AccountDB.nickname_integrations.Cell and ACT:HasNickname(unit)

                        if useNickname then
                            NicknameFunction(unitButton)
                        else
                            OriginalFunction()
                        end
                    end
                end
            end
        end
    end

    UpdateAll()
end

NicknameModule.nicknameFunctions["Cell"] = {
    Enable = Enable,
    Disable = Disable,
    Update = Update,
    Init = Init
}
