AssignmentBossUI = AssignmentBossUI or {}
AssignmentBossUI["plexus"] = function(parentFrame, rosterList)
    local frame = CreateFrame("Frame", nil, parentFrame)
    frame:SetAllPoints(parentFrame)

    AssignmentModule = AssignmentModule or {}
    AssignmentModule.allowDuplicates = false
    AssignmentModule.currentSlots = {} -- Placeholder stuff who knows what I need

    frame:SetScript("OnHide", function()
        AssignmentModule:UpdateRosterList()
    end)

    local bossID = "plexus"
    VACT = VACT or {}
    VACT.BossPresets = VACT.BossPresets or {}
    VACT.BossPresets[bossID] = VACT.BossPresets[bossID] or {}

    local isRenamePopupOpen = false
    local isGenerateNotePopupOpen = false

    local presetDropdown

    local function UpdatePresetDropdown()
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
        UI:SetDropdownOptions(presetDropdown, options)
    end

    local noteButton = UI:CreateButton(parentFrame, "Generate Note", 120, 25, function()
        if isGenerateNotePopupOpen then
            return
        end
        isGenerateNotePopupOpen = true
        -- function to be added later
        isGenerateNotePopupOpen = false
    end)
    noteButton:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -155, 35)

    local spacing = 10

    local loadPresetButton = UI:CreateButton(parentFrame, "Load Preset", 100, 25, function()
        local selectedText = presetDropdown.button.text:GetText()
        for _, preset in ipairs(VACT.BossPresets[bossID]) do
            if preset.name == selectedText and preset.data then
                if AssignmentModule.UpdateRosterList then
                    AssignmentModule:UpdateRosterList()
                end
                break
            end
        end
    end)
    loadPresetButton:SetPoint("RIGHT", noteButton, "LEFT", -spacing, 0)

    local deletePresetButton = UI:CreateButton(parentFrame, "Delete Preset", 100, 25, function()
        local selectedText = presetDropdown.button.text:GetText()
        for idx, preset in ipairs(VACT.BossPresets[bossID]) do
            if preset.name == selectedText then
                table.remove(VACT.BossPresets[bossID], idx)
                UpdatePresetDropdown()
                presetDropdown.button.text:SetText("Select Preset")
                break
            end
        end
    end)
    deletePresetButton:SetPoint("RIGHT", loadPresetButton, "LEFT", -spacing, 0)

    local renamePresetButton = UI:CreateButton(parentFrame, "Rename Preset", 100, 25, function()
        if isRenamePopupOpen then
            return
        end
        local selectedText = presetDropdown.button.text:GetText()
        for idx, preset in ipairs(VACT.BossPresets[bossID]) do
            if preset.name == selectedText then
                isRenamePopupOpen = true
                local popup, editBox = UI:CreatePopupWithEditBox("Rename Preset", 320, 150, preset.name or "",
                    function(newName)
                        if newName and newName:trim() ~= "" then
                            preset.name = newName
                            UpdatePresetDropdown()
                            presetDropdown.button.text:SetText(newName)
                        end
                        isRenamePopupOpen = false
                    end, function()
                        isRenamePopupOpen = false
                    end)
                popup:Show()
                break
            end
        end
    end)
    renamePresetButton:SetPoint("RIGHT", deletePresetButton, "LEFT", -spacing, 0)

    presetDropdown = UI:CreateDropdown(parentFrame, 200, 25)
    presetDropdown:SetPoint("RIGHT", renamePresetButton, "LEFT", -spacing, 0)
    presetDropdown.button.text:SetText("Select Preset")
    UpdatePresetDropdown()

    local savePresetButton = UI:CreateButton(parentFrame, "Save Preset", 100, 25, function()
        if isRenamePopupOpen then
            return
        end
        local data = {} -- Empty for now
        isRenamePopupOpen = true
        local popup, editBox = UI:CreatePopupWithEditBox("Save Preset", 320, 150, "", function(newName)
            if newName and newName:trim() ~= "" then
                table.insert(VACT.BossPresets[bossID], {
                    name = newName,
                    data = data
                })
                UpdatePresetDropdown()
                presetDropdown.button.text:SetText(newName)
            end
            isRenamePopupOpen = false
        end, function()
            isRenamePopupOpen = false
        end)
        popup:Show()
    end)
    savePresetButton:SetPoint("RIGHT", presetDropdown, "LEFT", -spacing, 0)

    local clearUIButton = UI:CreateButton(parentFrame, "Clear UI", 100, 25, function()
        if AssignmentModule.UpdateRosterList then
            AssignmentModule:UpdateRosterList()
        end
    end)
    clearUIButton:SetPoint("RIGHT", savePresetButton, "LEFT", -spacing, 0)
end
