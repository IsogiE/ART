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
        if not nameText or nameText == "" then
            return nil
        end

        -- Normalize for comparisons
        local lowerName = nameText:lower()

        -- 1. If it's a valid unit ID already
        if UnitExists(nameText) then
            return nameText
        end

        -- 2. Try resolving via ACT fast-path (may require exact match)
        local nicknameUnit = ACT:GetCharacterInGroup(nameText)
        if nicknameUnit and UnitExists(nicknameUnit) then
            return nicknameUnit
        end

        -- 3. Case-insensitive scan of group using ACT:GetRawNickname(unit)
        local function scanGroupForRawNickname()
            -- check player
            if UnitExists("player") then
                local rn = ACT:GetRawNickname("player")
                if rn and rn:lower() == lowerName then
                    return "player"
                end
            end

            if IsInRaid() then
                for i = 1, 40 do
                    local unit = "raid" .. i
                    if UnitExists(unit) then
                        local rn = ACT:GetRawNickname(unit)
                        if rn and rn:lower() == lowerName then
                            return unit
                        end
                    end
                end
            elseif IsInGroup() then
                for i = 1, 4 do
                    local unit = "party" .. i
                    if UnitExists(unit) then
                        local rn = ACT:GetRawNickname(unit)
                        if rn and rn:lower() == lowerName then
                            return unit
                        end
                    end
                end
            end

            return nil
        end

        local rawNickUnit = scanGroupForRawNickname()
        if rawNickUnit then
            return rawNickUnit
        end

        -- 4. Try resolving as a direct character name in the group (case-insensitive)
        local function scanGroupForCharacterName()
            if UnitExists("player") then
                local fullName = UnitNameUnmodified("player")
                if fullName and fullName:lower() == lowerName then
                    return "player"
                end
            end

            if IsInRaid() then
                for i = 1, 40 do
                    local unit = "raid" .. i
                    if UnitExists(unit) then
                        local fullName = UnitNameUnmodified(unit)
                        if fullName and fullName:lower() == lowerName then
                            return unit
                        end
                    end
                end
            elseif IsInGroup() then
                for i = 1, 4 do
                    local unit = "party" .. i
                    if UnitExists(unit) then
                        local fullName = UnitNameUnmodified(unit)
                        if fullName and fullName:lower() == lowerName then
                            return unit
                        end
                    end
                end
            end

            return nil
        end

        local charUnit = scanGroupForCharacterName()
        if charUnit then
            return charUnit
        end

        -- 5. Optional LiquidAPI fallback (legacy support)
        if LiquidAPI and LiquidAPI.GetCharacters then
            local charactersTable = LiquidAPI:GetCharacters(nameText)
            if charactersTable then
                for charName, _ in pairs(charactersTable) do
                    local unit = resolveUnit(charName)
                    if unit then
                        return unit
                    end
                end
            end
        end

        return nil
    end

    -- 6. Iterate over the 8 mark slots
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
