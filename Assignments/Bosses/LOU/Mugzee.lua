AssignmentBossUI = AssignmentBossUI or {}
AssignmentBossUI["mugzee"] = function(parentFrame, rosterList)
    local frame = CreateFrame("Frame", nil, parentFrame)
    frame:SetAllPoints(parentFrame)

    AssignmentModule.allowDuplicates = true

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -190, 90)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth())
    scrollFrame:SetScrollChild(content)

    local yOffset = -10

    local mugzeeGaolRows = {}
    local mugzeeGripRows = {}
    local mugzeeGoblinGroups = {{}, {}}
    local mugzeeFrostRows = {}
    local allSlots = {}

    local function CreateMugzeeEditBox(parent)
        local slot = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        slot:SetSize(100, 20)
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
        return editBox, slot
    end

    local function CreateRow(parent, numBoxes, boxWidth, boxHeight, spacing)
        local rowFrame = CreateFrame("Frame", nil, parent)
        rowFrame:SetSize((boxWidth * numBoxes) + spacing * (numBoxes - 1), boxHeight)
        local boxes = {}
        for i = 1, numBoxes do
            local editBox, slot = CreateMugzeeEditBox(rowFrame)
            slot:SetSize(boxWidth, boxHeight)
            if i == 1 then
                slot:SetPoint("LEFT", rowFrame, "LEFT", 0, 0)
            else
                slot:SetPoint("LEFT", boxes[i - 1].slot, "RIGHT", spacing, 0)
            end
            boxes[i] = {
                editBox = editBox,
                slot = slot
            }
        end
        return rowFrame, boxes
    end

    AssignmentModule.allowDuplicates = true

    local boxWidth = 100
    local boxHeight = 20
    local spacing = 10

    local gaolTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gaolTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    gaolTitle:SetText("Gaol Assignments")
    yOffset = yOffset - 25

    local gaolRowDefs = {{
        group = 1,
        label = "Gaol 1 - Left"
    }, {
        group = 1,
        label = "Gaol 1 - Right"
    }, {
        group = 2,
        label = "Gaol 2 - Left"
    }, {
        group = 2,
        label = "Gaol 2 - Far Left"
    }, {
        group = 2,
        label = "Gaol 2 - Right"
    }, {
        group = 3,
        label = "Gaol 3 - Left"
    }, {
        group = 3,
        label = "Gaol 3 - Far Left"
    }, {
        group = 3,
        label = "Gaol 3 - Right"
    }, {
        group = 3,
        label = "Gaol 3 - Far Right"
    }}

    for i, def in ipairs(gaolRowDefs) do
        local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        label:SetText(def.label)
        yOffset = yOffset - 15

        local rowFrame, boxes = CreateRow(content, 4, boxWidth, boxHeight, spacing)
        rowFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        yOffset = yOffset - (boxHeight + 10)
        local rowEditBoxes = {}
        for _, b in ipairs(boxes) do
            table.insert(rowEditBoxes, b.editBox)
        end
        table.insert(mugzeeGaolRows, {
            group = def.group,
            editBoxes = rowEditBoxes
        })
        table.insert(allSlots, rowEditBoxes)
    end

    local gripTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gripTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    gripTitle:SetText("Grip Assignments for Gaols")
    yOffset = yOffset - 25

    local gripLabels = {"Grip Target Priority", "Gripper Priority"}
    for i, labelText in ipairs(gripLabels) do
        local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        label:SetText(labelText)
        yOffset = yOffset - 15

        local rowFrame, boxes = CreateRow(content, 5, boxWidth, boxHeight, spacing)
        rowFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        yOffset = yOffset - (boxHeight + 10)
        local rowEditBoxes = {}
        for _, b in ipairs(boxes) do
            table.insert(rowEditBoxes, b.editBox)
        end
        table.insert(mugzeeGripRows, rowEditBoxes)
        table.insert(allSlots, rowEditBoxes)
    end

    local rocketTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rocketTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    rocketTitle:SetText("Goblin Guided Rocket Assign")
    yOffset = yOffset - 25

    local rocketGroupDefs = {{
        title = "Soak 1 & 3",
        rows = 3
    }, {
        title = "Soak 2 & 4",
        rows = 3
    }}
    for groupIndex, groupDef in ipairs(rocketGroupDefs) do
        local groupLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        groupLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        groupLabel:SetText(groupDef.title)
        yOffset = yOffset - 15
        for r = 1, groupDef.rows do
            local rowFrame, boxes = CreateRow(content, 5, boxWidth, boxHeight, spacing)
            rowFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
            yOffset = yOffset - (boxHeight + 5)
            for _, b in ipairs(boxes) do
                table.insert(mugzeeGoblinGroups[groupIndex], b.editBox)
            end
        end
        yOffset = yOffset - 10
    end
    table.insert(allSlots, mugzeeGoblinGroups[1])
    table.insert(allSlots, mugzeeGoblinGroups[2])

    local frostTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frostTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    frostTitle:SetText("Frost Shatter Assignments")
    yOffset = yOffset - 25

    local numFrostRows = 4
    for i = 1, numFrostRows do
        local rowFrame, boxes = CreateRow(content, 5, boxWidth, boxHeight, spacing)
        rowFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
        yOffset = yOffset - (boxHeight + 5)
        for _, b in ipairs(boxes) do
            table.insert(mugzeeFrostRows, b.editBox)
        end
    end
    table.insert(allSlots, mugzeeFrostRows)

    content:SetHeight(-yOffset + 20)

    frame.bossSlots = allSlots

    frame:SetScript("OnShow", function(self)
        AssignmentModule.currentSlots = self.bossSlots
        if AssignmentModule.UpdateRosterList then
            AssignmentModule:UpdateRosterList()
        end
    end)

    local bossID = "mugzee"
    VACT = VACT or {}
    VACT.BossPresets = VACT.BossPresets or {}
    VACT.BossPresets[bossID] = VACT.BossPresets[bossID] or {}

    local isRenamePopupOpen = false
    local isGenerateNotePopupOpen = false

    local presetDropdown

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

    local function GetMugzeeAssignmentState()
        local hasData = false
        local data = {}
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

    AssignmentModule:RegisterGetStateFunction(GetMugzeeAssignmentState)

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
        local note = ""

        note = note .. "liquidStart\n"
        local currentGroup = nil
        for i, row in ipairs(mugzeeGaolRows) do
            if not currentGroup then
                currentGroup = row.group
            elseif row.group ~= currentGroup then
                note = note .. "\n"
                currentGroup = row.group
            end
            local names = {}
            for _, editBox in ipairs(row.editBoxes) do
                if editBox.usedName and editBox.usedName ~= "" then
                    local name = editBox.usedName
                    if LiquidAPI and LiquidAPI.GetName then
                        local nick = LiquidAPI:GetName(name)
                        if nick and nick ~= "" then
                            name = nick
                        end
                    end
                    name = capFirst(name)
                    table.insert(names, name)
                end
            end
            note = note .. table.concat(names, " ") .. "\n"
        end
        note = note .. "liquidEnd\n\n"

        note = note .. "liquidStart3\n"
        for i, row in ipairs(mugzeeGripRows) do
            local names = {}
            for _, editBox in ipairs(row) do
                if editBox.usedName and editBox.usedName ~= "" then
                    local name = editBox.usedName
                    if LiquidAPI and LiquidAPI.GetName then
                        local nick = LiquidAPI:GetName(name)
                        if nick and nick ~= "" then
                            name = nick
                        end
                    end
                    name = capFirst(name)
                    table.insert(names, name)
                end
            end
            note = note .. table.concat(names, " ") .. "\n"
        end
        note = note .. "liquidEnd3\n\n"

        note = note .. "liquidStart2\n"
        for groupIndex, group in ipairs(mugzeeGoblinGroups) do
            local names = {}
            for _, editBox in ipairs(group) do
                if editBox.usedName and editBox.usedName ~= "" then
                    local name = editBox.usedName
                    if LiquidAPI and LiquidAPI.GetName then
                        local nick = LiquidAPI:GetName(name)
                        if nick and nick ~= "" then
                            name = nick
                        end
                    end
                    name = capFirst(name)
                    table.insert(names, name)
                end
            end
            note = note .. table.concat(names, " ") .. "\n"
        end
        note = note .. "liquidEnd2\n\n"

        note = note .. "liquidStart4\n"
        local names = {}
        for _, editBox in ipairs(mugzeeFrostRows) do
            if editBox.usedName and editBox.usedName ~= "" then
                local name = editBox.usedName
                if LiquidAPI and LiquidAPI.GetName then
                    local nick = LiquidAPI:GetName(name)
                    if nick and nick ~= "" then
                        name = nick
                    end
                end
                name = capFirst(name)
                table.insert(names, name)
            end
        end
        note = note .. table.concat(names, " ") .. "\n"
        note = note .. "liquidEnd4"

        local popup, editBox = UI:CreatePopupWithEditBox("Assignment Note - Mugzee", 400, 300, note, function(text)
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
                                        local r, g, b = color[1], color[2], color[3]
                                        local hexColor = string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
                                        editBox:SetText("|cff" .. hexColor .. presetName .. "|r")
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
        local selectedText = presetDropdown.button.text:GetText()
        local selectedIndex = nil
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
        local selectedText = presetDropdown.button.text:GetText()
        local selectedIndex = nil
        for idx, preset in ipairs(VACT.BossPresets[bossID]) do
            if preset.name == selectedText then
                selectedIndex = idx
                break
            end
        end
        if selectedIndex then
            isRenamePopupOpen = true
            local currentPreset = VACT.BossPresets[bossID][selectedIndex]
            local popup, editBox = UI:CreatePopupWithEditBox("Rename Preset", 320, 150, currentPreset.name or "",
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

        local assignmentState = GetMugzeeAssignmentState()
        if not assignmentState then
            return
        end

        isRenamePopupOpen = true
        local popup, editBox = UI:CreatePopupWithEditBox("Save Preset", 320, 150, "", function(newName)
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
        if frame.bossSlots then
            for _, group in ipairs(frame.bossSlots) do
                for _, editBox in ipairs(group) do
                    editBox:SetText("")
                    editBox.usedName = nil
                end
            end
            AssignmentModule:UpdateRosterList()
        end
    end)
    clearUIButton:SetPoint("RIGHT", savePresetButton, "LEFT", -spacing, 0)
    return frame
end
