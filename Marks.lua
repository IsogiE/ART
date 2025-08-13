local RaidMarksModule = {}
RaidMarksModule.title = "Marks"

local function CreateCustomEditBox(parent, width, height)
    local edit = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    edit:SetSize(width, height)
    edit:SetAutoFocus(false)
    edit:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    edit:SetJustifyH("LEFT")

    edit:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    edit:SetBackdropColor(0, 0, 0, 0)
    edit:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    edit:SetText("")
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    return edit
end

function RaidMarksModule:GetConfigSize()
    return 800, 600
end

function RaidMarksModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        return self.configPanel
    end

    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetAllPoints()

    local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    title:SetText(self.title)

    local toggleButton = UI:CreateButton(configPanel, "Enable", 140, 30)
    toggleButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)

    local clearButton = UI:CreateButton(configPanel, "Clear UI", 140, 30)
    clearButton:SetPoint("LEFT", toggleButton, "RIGHT", 10, 0)

    toggleButton:SetScript("OnClick", function(self)
        if not RaidMarksModule.Enabled then
            RaidMarksModule:Enable()
            self.text:SetText("Disable")
        else
            RaidMarksModule:Disable()
            self.text:SetText("Enable")
        end
    end)

    clearButton:SetScript("OnClick", function()
        RaidMarksModule:ClearMarks()
    end)

    self.rows = {}
    local rowSpacing = 8
    local rowStartY = -10
    for i = 1, 8 do
        local icon = configPanel:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i)
        icon:SetPoint("TOPLEFT", toggleButton, "BOTTOMLEFT", 0, rowStartY - (i - 1) * (24 + rowSpacing))

        local editBox = CreateCustomEditBox(configPanel, 300, 24)
        editBox:SetPoint("LEFT", icon, "RIGHT", 10, 0)

        self.rows[i] = {
            icon = icon,
            editBox = editBox
        }
    end

    self.configPanel = configPanel
    return configPanel
end

function RaidMarksModule:Enable()
    self.Enabled = true
    if not self.timerFrame then
        self.timerFrame = CreateFrame("Frame")
        self.timerFrame:SetScript("OnUpdate", function(frame, elapsed)
            self:OnUpdate(elapsed)
        end)
    end
end

function RaidMarksModule:Disable()
    self.Enabled = false
    if self.timerFrame then
        self.timerFrame:SetScript("OnUpdate", nil)
        self.timerFrame = nil
    end
end

function RaidMarksModule:ClearMarks()
    for i = 1, 8 do
        local row = self.rows[i]
        if row and row.editBox then
            row.editBox:SetText("")
        end
    end
end

function RaidMarksModule:OnUpdate(elapsed)
    self.tmr = (self.tmr or 0) + elapsed
    if self.tmr < 0.5 then
        return
    end
    self.tmr = 0

    local function resolveUnit(nameText)
        if UnitExists(nameText) then
            return nameText
        end

        local characters = NicknameAPI:GetAllCharactersByNickname(nameText)
        if not characters or #characters == 0 then
            local charactersTable = LiquidAPI:GetCharacters(nameText)
            if charactersTable then
                characters = {}
                for charName, _ in pairs(charactersTable) do
                    table.insert(characters, charName)
                end
            else
                return nil
            end
        end

        local function findUnitInGroup(unitId)
            if not UnitExists(unitId) then
                return nil
            end

            local unitName = UnitName(unitId)
            if not unitName then
                return nil
            end

            local fullUnitName, realm = UnitFullName(unitId)
            if not fullUnitName then
                return nil
            end

            for _, charName in ipairs(characters) do
                local charNameLower = charName:lower()
                local unitNameLower = unitName:lower()
                local fullUnitNameLower = fullUnitName:lower()

                if charNameLower == unitNameLower then
                    return unitId
                end

                if realm then
                    local fullNameWithRealm = (fullUnitName .. "-" .. realm):lower()
                    if charNameLower == fullNameWithRealm then
                        return unitId
                    end
                end

                if charNameLower == fullUnitNameLower then
                    return unitId
                end

                local simpleCharName = charNameLower:match("^([^-]+)")
                if simpleCharName and simpleCharName == unitNameLower then
                    return unitId
                end
            end

            return nil
        end

        local playerUnit = findUnitInGroup("player")
        if playerUnit then
            return playerUnit
        end

        if IsInRaid() then
            for i = 1, 40 do
                local unit = findUnitInGroup("raid" .. i)
                if unit then
                    return unit
                end
            end
        elseif IsInGroup() then
            for i = 1, 4 do
                local unit = findUnitInGroup("party" .. i)
                if unit then
                    return unit
                end
            end
        end

        return nil
    end

    for i = 1, 8 do
        local row = self.rows[i]
        if row and row.editBox then
            local text = row.editBox:GetText()
            if text and text ~= "" then
                if text:find("[, ]") then
                    for name in text:gmatch("([^,%s]+)") do
                        local unit = resolveUnit(name)
                        if unit and GetRaidTargetIndex(unit) ~= i then
                            SetRaidTargetIcon(unit, i)
                            break
                        end
                    end
                else
                    local unit = resolveUnit(text)
                    if unit and GetRaidTargetIndex(unit) ~= i then
                        SetRaidTargetIcon(unit, i)
                    end
                end
            end
        end
    end
end

function RaidMarksModule:OnEnable()
    self:Enable()
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(RaidMarksModule)
end

return RaidMarksModule
