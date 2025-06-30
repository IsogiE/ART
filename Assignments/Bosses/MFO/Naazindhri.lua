AssignmentBossUI = AssignmentBossUI or {}
AssignmentBossUI["naazindhri"] = function(parentFrame, rosterList)
    local frame = CreateFrame("Frame", nil, parentFrame)
    frame:SetAllPoints(parentFrame)

    AssignmentModule = AssignmentModule or {}
    AssignmentModule.allowDuplicates = false
    AssignmentModule.currentSlots = {} -- Placeholder

    -- Placeholder
    frame:SetScript("OnHide", function()
        AssignmentModule:UpdateRosterList()
    end)

    local bossID = "naazindhri"
    VACT = VACT or {}
    VACT.BossPresets = VACT.BossPresets or {}
    VACT.BossPresets[bossID] = VACT.BossPresets[bossID] or {}

    local isRenamePopupOpen = false
    local isGenerateNotePopupOpen = false

    local presetDropdown

    local function UpdatePresetDropdown()
    end

    local noteButton = UI:CreateButton(frame, "Generate Note", 120, 25, function()
        if isGenerateNotePopupOpen then
            return
        end
        isGenerateNotePopupOpen = true
        -- to be added later
        isGenerateNotePopupOpen = false
    end)
    noteButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -155, 35)

    local spacing = 10

    local loadPresetButton = UI:CreateButton(frame, "Load Preset", 100, 25, function()
        -- to be added later
    end)
    loadPresetButton:SetPoint("RIGHT", noteButton, "LEFT", -spacing, 0)

    local deletePresetButton = UI:CreateButton(frame, "Delete Preset", 100, 25, function()
        -- to be added later
    end)
    deletePresetButton:SetPoint("RIGHT", loadPresetButton, "LEFT", -spacing, 0)

    local renamePresetButton = UI:CreateButton(frame, "Rename Preset", 100, 25, function()
        -- to be added later
    end)
    renamePresetButton:SetPoint("RIGHT", deletePresetButton, "LEFT", -spacing, 0)

    presetDropdown = UI:CreateDropdown(frame, 200, 25)
    presetDropdown:SetPoint("RIGHT", renamePresetButton, "LEFT", -spacing, 0)
    presetDropdown.button.text:SetText("Select Preset")
    -- to be added later

    local savePresetButton = UI:CreateButton(frame, "Save Preset", 100, 25, function()
        -- to be added later
    end)
    savePresetButton:SetPoint("RIGHT", presetDropdown, "LEFT", -spacing, 0)

    local clearUIButton = UI:CreateButton(frame, "Clear UI", 100, 25, function()
        -- to be added later
    end)
    clearUIButton:SetPoint("RIGHT", savePresetButton, "LEFT", -spacing, 0)

    return frame
end
