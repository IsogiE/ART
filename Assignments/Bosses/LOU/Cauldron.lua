AssignmentBossUI = AssignmentBossUI or {}
AssignmentBossUI["cauldron"] = function(parentFrame, rosterList)
    local frame = CreateFrame("Frame", nil, parentFrame)
    frame:SetAllPoints(parentFrame)
    local leftLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    leftLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 150, -70)
    leftLabel:SetText("Left Side")
    local rightLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 340, -70)
    rightLabel:SetText("Right Side")

    local leftSlots, rightSlots = {}, {}
    frame.bossSlots = {leftSlots, rightSlots}

    for i = 1, 10 do
        local slot = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        slot:SetSize(150, 20)
        if i == 1 then
            slot:SetPoint("TOPLEFT", leftLabel, "BOTTOMLEFT", 0, -5)
        else
            slot:SetPoint("TOPLEFT", leftSlots[i - 1]:GetParent(), "BOTTOMLEFT", 0, -5)
        end
        slot:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1
        })
        slot:SetBackdropColor(0.1, 0.1, 0.1, 1)
        slot:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        local editBox = CreateFrame("EditBox", nil, slot)
        editBox:SetAllPoints(slot)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetText("")
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        editBox.usedName = nil
        leftSlots[i] = editBox
    end

    for j = 1, 10 do
        local slot = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        slot:SetSize(150, 20)
        if j == 1 then
            slot:SetPoint("TOPLEFT", rightLabel, "BOTTOMLEFT", 0, -5)
        else
            slot:SetPoint("TOPLEFT", rightSlots[j - 1]:GetParent(), "BOTTOMLEFT", 0, -5)
        end
        slot:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1
        })
        slot:SetBackdropColor(0.1, 0.1, 0.1, 1)
        slot:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        local editBox = CreateFrame("EditBox", nil, slot)
        editBox:SetAllPoints(slot)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetText("")
        editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        editBox.usedName = nil
        rightSlots[j] = editBox
    end

    AssignmentModule.allowDuplicates = false

    frame:SetScript("OnShow", function(self)
        AssignmentModule.currentSlots = self.bossSlots
        if AssignmentModule.UpdateRosterList then
            AssignmentModule:UpdateRosterList()
        end
    end)

    local bossID = "cauldron"
    VACT = VACT or {}
    VACT.BossPresets = VACT.BossPresets or {}
    VACT.BossPresets[bossID] = VACT.BossPresets[bossID] or {}
    local isRenamePopupOpen, isGenerateNotePopupOpen, presetDropdown
    _G["Update" .. bossID .. "PresetDropdown"] = function()
        local options = {}
        for idx, preset in ipairs(VACT.BossPresets[bossID]) do
            table.insert(options, {
                text = preset.name,
                value = idx,
                onClick = function()
                    presetDropdown.button.text:SetText(preset.name)
                end
            })
        end
        if presetDropdown then
            UI:SetDropdownOptions(presetDropdown, options)
        end
    end

    local function GetCauldronAssignmentState()
        local hasData, data = false, {}
        if frame.bossSlots then
            for i, group in ipairs(frame.bossSlots) do
                data[i] = {}
                for j, editBox in ipairs(group) do
                    local name = editBox.usedName or ""
                    if name ~= "" then
                        hasData = true
                    end
                    data[i][j] = name
                end
            end
        end
        if not hasData then
            return nil
        end
        return {
            data = data
        }
    end
    AssignmentModule:RegisterGetStateFunction(GetCauldronAssignmentState)

    local function capFirst(str)
        if str and str ~= "" then
            return str:sub(1, 1):upper() .. str:sub(2)
        end
        return str
    end
    local noteButton = UI:CreateButton(frame, "Generate Note", 120, 25, function()
        if isGenerateNotePopupOpen then
            return
        end
        isGenerateNotePopupOpen = true
        local note, leftNames, rightNames = "Boss Groups\n", {}, {}
        for _, slot in ipairs(leftSlots) do
            if slot.usedName then
                local name = slot.usedName
                if LiquidAPI and LiquidAPI.GetName then
                    local nick = LiquidAPI:GetName(name)
                    if nick and nick ~= "" then
                        name = nick
                    end
                end
                table.insert(leftNames, capFirst(name))
            end
        end
        if #leftNames > 0 then
            note = note .. "Left Flarendo " .. table.concat(leftNames, " ") .. "\n"
        end
        for _, slot in ipairs(rightSlots) do
            if slot.usedName then
                local name = slot.usedName
                if LiquidAPI and LiquidAPI.GetName then
                    local nick = LiquidAPI:GetName(name)
                    if nick and nick ~= "" then
                        name = nick
                    end
                end
                table.insert(rightNames, capFirst(name))
            end
        end
        if #rightNames > 0 then
            note = note .. "Right Torq " .. table.concat(rightNames, " ") .. "\n"
        end
        local popup, editBox = UI:CreatePopupWithEditBox("Assignment Note - Cauldron", 400, 300, note, function(text)
            isGenerateNotePopupOpen = false
        end, function()
            isGenerateNotePopupOpen = false
        end)
        popup:SetScript("OnHide", function()
            isGenerateNotePopupOpen = false
        end)
        popup:Show()
        editBox:ClearFocus()
    end)

    noteButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -155, 35)

    local spacing = 10

    local loadPresetButton = UI:CreateButton(frame, "Load Preset", 100, 25, function()
        local selectedText = presetDropdown.button.text:GetText()
        for _, preset in ipairs(VACT.BossPresets[bossID]) do
            if preset.name == selectedText then
                if preset.data and frame.bossSlots then
                    for i, group in ipairs(frame.bossSlots) do
                        if preset.data[i] then
                            for j, presetName in ipairs(preset.data[i]) do
                                local editBox = group[j]
                                if editBox then
                                    if presetName and presetName ~= "" then
                                        local color = GetPlayerClassColorByName(presetName) or {1, 1, 1, 1}
                                        editBox:SetText(string.format("|cff%02x%02x%02x%s|r", color[1] * 255,
                                            color[2] * 255, color[3] * 255, presetName))
                                        editBox.usedName = presetName
                                    else
                                        editBox:SetText("")
                                        editBox.usedName = nil
                                    end
                                end
                            end
                        end
                    end
                    if AssignmentModule.UpdateRosterList then
                        AssignmentModule:UpdateRosterList()
                    end
                end
                break
            end
        end
    end)
    loadPresetButton:SetPoint("RIGHT", noteButton, "LEFT", -spacing, 0)

    local deletePresetButton = UI:CreateButton(frame, "Delete Preset", 100, 25, function()
        local selectedText, selectedIndex = presetDropdown.button.text:GetText()
        for idx, preset in ipairs(VACT.BossPresets[bossID]) do
            if preset.name == selectedText then
                selectedIndex = idx
                break
            end
        end
        if selectedIndex then
            table.remove(VACT.BossPresets[bossID], selectedIndex)
            _G["Update" .. bossID .. "PresetDropdown"]()
            presetDropdown.button.text:SetText("Select Preset")
        end
    end)
    deletePresetButton:SetPoint("RIGHT", loadPresetButton, "LEFT", -spacing, 0)

    local renamePresetButton = UI:CreateButton(frame, "Rename Preset", 100, 25, function()
        if isRenamePopupOpen then
            return
        end
        local selectedText, selectedIndex = presetDropdown.button.text:GetText()
        for idx, preset in ipairs(VACT.BossPresets[bossID]) do
            if preset.name == selectedText then
                selectedIndex = idx
                break
            end
        end
        if selectedIndex then
            isRenamePopupOpen = true
            local currentPreset = VACT.BossPresets[bossID][selectedIndex]
            local popup = UI:CreatePopupWithEditBox("Rename Preset", 320, 150, currentPreset.name or "",
                function(newName)
                    if newName and newName:trim() ~= "" then
                        currentPreset.name = newName
                        _G["Update" .. bossID .. "PresetDropdown"]()
                        presetDropdown.button.text:SetText(newName)
                    end
                    isRenamePopupOpen = false
                end, function()
                    isRenamePopupOpen = false
                end)
            popup:Show()
        end
    end)
    renamePresetButton:SetPoint("RIGHT", deletePresetButton, "LEFT", -spacing, 0)

    presetDropdown = UI:CreateDropdown(frame, 200, 25)
    presetDropdown:SetPoint("RIGHT", renamePresetButton, "LEFT", -spacing, 0)
    presetDropdown.button.text:SetText("Select Preset")
    _G["Update" .. bossID .. "PresetDropdown"]()
    local savePresetButton = UI:CreateButton(frame, "Save Preset", 100, 25, function()
        if isRenamePopupOpen then
            return
        end
        local assignmentState = GetCauldronAssignmentState()
        if not assignmentState then
            return
        end
        isRenamePopupOpen = true
        local popup = UI:CreatePopupWithEditBox("Save Preset", 320, 150, "", function(newName)
            if newName and newName:trim() ~= "" then
                table.insert(VACT.BossPresets[bossID], {
                    name = newName,
                    data = assignmentState.data
                })
                _G["Update" .. bossID .. "PresetDropdown"]()
                presetDropdown.button.text:SetText(newName)
            end
            isRenamePopupOpen = false
        end, function()
            isRenamePopupOpen = false
        end)
        popup:Show()
    end)
    savePresetButton:SetPoint("RIGHT", presetDropdown, "LEFT", -spacing, 0)

    local clearUIButton = UI:CreateButton(frame, "Clear UI", 100, 25, function()
        for _, group in ipairs(frame.bossSlots) do
            for _, editBox in ipairs(group) do
                editBox:SetText("")
                editBox.usedName = nil
            end
        end
        AssignmentModule:UpdateRosterList()
    end)
    clearUIButton:SetPoint("RIGHT", savePresetButton, "LEFT", -spacing, 0)
    return frame
end
