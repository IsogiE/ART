local SplitHelper = {}

SplitHelper.characterRowPool = {}
SplitHelper.unexpectedCharacterRowPool = {}
SplitHelper.massDeletePopup = nil
SplitHelper.massDeletePopupCheckboxes = {}
SplitHelper.massDeleteCheckboxPool = {}
SplitHelper.confirmDeleteAllPopupInstance = nil
SplitHelper.confirmDeleteSelectedPopupInstance = nil

SplitHelper.characterRows = {}
SplitHelper.title = "Split Helper"

function SplitHelper:CreateMassDeletePopup(parent)
    if self.massDeletePopup then
        return
    end

    local popup = CreateFrame("Frame", "SplitHelperMassDeletePopupFrame", parent, "BackdropTemplate")
    popup:SetSize(420, 480)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("HIGH")
    popup:SetFrameLevel(249)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    popup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    popup:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    self.massDeletePopup = popup

    local title = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", popup, "TOP", 0, -12)
    title:SetText("Select Splits to Delete")

    local closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        popup:Hide()
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -35, 70)
    popup.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() - 15)
    scrollFrame:SetScrollChild(scrollChild)
    popup.scrollChild = scrollChild

    local cancelMassDeleteButton = UI:CreateButton(popup, "Cancel", 100, 25)
    cancelMassDeleteButton:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 20, 20)
    cancelMassDeleteButton:SetScript("OnClick", function()
        popup:Hide()
    end)

    local deleteAllButton = UI:CreateButton(popup, "Delete All", 100, 25)
    deleteAllButton:SetPoint("LEFT", cancelMassDeleteButton, "RIGHT", 10, 0)
    deleteAllButton:SetScript("OnClick", function()
        if SplitHelper.confirmDeleteAllPopupInstance and SplitHelper.confirmDeleteAllPopupInstance:IsShown() then
            return
        end

        SplitHelper.confirmDeleteAllPopupInstance = UI:CreateTextPopup("Confirm Delete All",
            "Are you sure you want to delete ALL splits? This action cannot be undone.", "Delete All", "Cancel",
            function()
                ACT.db.profile.splits.profiles = {}
                SplitHelper:UpdateDropdown()
                SplitHelper.selectedIndex = nil
                if SplitHelper.splitDropdown and SplitHelper.splitDropdown.button then
                    SplitHelper.splitDropdown.button.text:SetText("Select Split")
                end
                if SplitHelper.massDeletePopup then
                    SplitHelper.massDeletePopup:Hide()
                end
                local reportPopup = UI:CreateTextPopup("Mass Delete", "All splits have been deleted.", "OK", "Close")
                reportPopup:SetFrameStrata("HIGH")
                reportPopup:SetFrameLevel(255)
                reportPopup:Show()
                SplitHelper.confirmDeleteAllPopupInstance = nil
            end, function()
                SplitHelper.confirmDeleteAllPopupInstance = nil
            end)
        SplitHelper.confirmDeleteAllPopupInstance:SetFrameStrata("HIGH")
        SplitHelper.confirmDeleteAllPopupInstance:SetFrameLevel(450)
        SplitHelper.confirmDeleteAllPopupInstance:SetScript("OnHide", function()
            SplitHelper.confirmDeleteAllPopupInstance = nil
        end)
        SplitHelper.confirmDeleteAllPopupInstance:Show()
    end)

    local deleteSelectedButton = UI:CreateButton(popup, "Delete Selected", 120, 25)
    deleteSelectedButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -20, 20)
    deleteSelectedButton:SetScript("OnClick", function()
        if SplitHelper.confirmDeleteSelectedPopupInstance and SplitHelper.confirmDeleteSelectedPopupInstance:IsShown() then
            return
        end

        local splitsToDeleteNames = {}
        for _, cb in ipairs(SplitHelper.massDeletePopupCheckboxes) do
            if cb:GetChecked() then
                table.insert(splitsToDeleteNames, cb.splitName)
            end
        end

        if #splitsToDeleteNames == 0 then
            return
        end

        SplitHelper.confirmDeleteSelectedPopupInstance = UI:CreateTextPopup("Confirm Deletion",
            "Are you sure you want to delete " .. #splitsToDeleteNames .. " split(s)? This cannot be undone.", "Delete",
            "Cancel", function()
                local currentSelectedSplitName = (SplitHelper.selectedIndex and
                                                     ACT.db.profile.splits.profiles[SplitHelper.selectedIndex]) and
                                                     ACT.db.profile.splits.profiles[SplitHelper.selectedIndex].name or
                                                     nil

                local newSplitsList = {}
                local currentSelectionStillExists = false

                for _, splitData in ipairs(ACT.db.profile.splits.profiles) do
                    local deleteThis = false
                    for _, nameToDelete in ipairs(splitsToDeleteNames) do
                        if splitData.name == nameToDelete then
                            deleteThis = true
                            break
                        end
                    end

                    if not deleteThis then
                        table.insert(newSplitsList, splitData)
                        if currentSelectedSplitName and splitData.name == currentSelectedSplitName then
                            currentSelectionStillExists = true
                        end
                    end
                end

                ACT.db.profile.splits.profiles = newSplitsList

                if not currentSelectionStillExists then
                    SplitHelper.selectedIndex = nil
                    if SplitHelper.splitDropdown and SplitHelper.splitDropdown.button then
                        SplitHelper.splitDropdown.button.text:SetText("Select Split")
                    end
                end

                SplitHelper:UpdateDropdown()

                if SplitHelper.massDeletePopup then
                    SplitHelper.massDeletePopup:Hide()
                end

                local reportPopup = UI:CreateTextPopup("Mass Delete", #splitsToDeleteNames .. " split(s) deleted.",
                    "OK", "Close")
                reportPopup:SetFrameStrata("HIGH")
                reportPopup:SetFrameLevel(450)
                reportPopup:Show()
                SplitHelper.confirmDeleteSelectedPopupInstance = nil
            end, function()
                SplitHelper.confirmDeleteSelectedPopupInstance = nil
            end)
        SplitHelper.confirmDeleteSelectedPopupInstance:SetFrameStrata("HIGH")
        SplitHelper.confirmDeleteSelectedPopupInstance:SetFrameLevel(450)
        SplitHelper.confirmDeleteSelectedPopupInstance:SetScript("OnHide", function()
            SplitHelper.confirmDeleteSelectedPopupInstance = nil
        end)
        SplitHelper.confirmDeleteSelectedPopupInstance:Show()
    end)

    popup:Hide()
end

function SplitHelper:ShowMassDeletePopup()
    if not self.massDeletePopup or not self.massDeletePopup.scrollChild then
        return
    end

    if #ACT.db.profile.splits.profiles == 0 then
        return
    end

    for _, cb in ipairs(self.massDeletePopupCheckboxes) do
        cb:Hide()
        table.insert(self.massDeleteCheckboxPool, cb)
    end
    self.massDeletePopupCheckboxes = {}

    local scrollChild = self.massDeletePopup.scrollChild
    local yOffset = -10
    local checkboxSize = 32
    local checkboxSpacing = 5

    for index, split in ipairs(ACT.db.profile.splits.profiles) do
        local cb = table.remove(self.massDeleteCheckboxPool)
        if not cb then
            cb = CreateFrame("CheckButton", "SplitHelperMassDeleteCB" .. index, scrollChild, "UICheckButtonTemplate")
            cb:SetSize(checkboxSize, checkboxSize)
            cb.text:SetFontObject(GameFontNormal)
            cb.text:SetJustifyH("LEFT")
            cb.text:ClearAllPoints()
            cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        end
        cb:SetPoint("TOPLEFT", 5, yOffset)
        cb.text:SetText(split.name)
        cb.splitName = split.name
        cb:SetChecked(false)
        cb:Show()
        table.insert(self.massDeletePopupCheckboxes, cb)
        yOffset = yOffset - checkboxSize - checkboxSpacing
    end
    scrollChild:SetHeight(math.max(self.massDeletePopup.scrollFrame:GetHeight() + 10, -yOffset + checkboxSpacing))
    self.massDeletePopup:Show()
end

function SplitHelper:GetConfigSize()
    return 1000, 600
end

function SplitHelper:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        return self.configPanel
    end

    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetAllPoints(parent)

    local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    title:SetText("Split Helper")

    local importBoxFrame, importEditBox = UI:CreateMultilineEditBox(configPanel, 520, 60, "")
    importBoxFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    self.importBox = importEditBox

    errorHandler = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    errorHandler:SetPoint("TOPRIGHT", importBoxFrame, "BOTTOMRIGHT", 0, -5)

    local importButton = UI:CreateButton(configPanel, "Import", 120, 30)
    importButton:SetPoint("TOPLEFT", importBoxFrame, "BOTTOMLEFT", 0, -10)

    local scrollFrame = CreateFrame("ScrollFrame", nil, configPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(520, 400)
    scrollFrame:SetPoint("TOPLEFT", importButton, "BOTTOMLEFT", 0, -50)
    scrollbar = scrollFrame.ScrollBar
    scrollbar:Hide()

    self.scrollContent = CreateFrame("Frame", nil, scrollFrame)
    self.scrollContent:SetSize(520, 300)
    scrollFrame:SetScrollChild(self.scrollContent)

    self.resultText = self.scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.resultText:SetSize(500, 290)
    self.resultText:SetPoint("TOPLEFT", 10, -10)
    self.resultText:SetJustifyH("LEFT")
    self.resultText:SetJustifyV("TOP")
    self.resultText:SetWordWrap(true)

    local headerFrame = CreateFrame("Frame", nil, configPanel)
    headerFrame:SetSize(700, 20)
    headerFrame:SetPoint("TOPLEFT", importButton, "BOTTOMLEFT", 0, -30)

    local expectedHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    expectedHeader:SetPoint("LEFT", headerFrame, "LEFT", 0, -20)
    expectedHeader:SetText("Expected Characters:")

    local unexpectedHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    unexpectedHeader:SetPoint("RIGHT", headerFrame, "RIGHT", 0, -20)
    unexpectedHeader:SetText("Unexpected Characters:")

    self.splitDropdown = UI:CreateDropdown(configPanel, 520, 30)
    self.splitDropdown:SetPoint("TOPLEFT", importButton, "BOTTOMLEFT", 0, -10)
    self.splitDropdown.button.text:SetText("Select Split")

    local deleteButton = UI:CreateButton(configPanel, "Delete Split", 120, 30)
    deleteButton:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMLEFT", 0, 10)

    local renameButton = UI:CreateButton(configPanel, "Rename", 100, 30)
    renameButton:SetPoint("LEFT", self.splitDropdown, "RIGHT", 10, 0)

    local checkButton = UI:CreateButton(configPanel, "Refresh", 100, 30)
    checkButton:SetPoint("LEFT", renameButton, "RIGHT", 10, 0)

    local unexpectedScrollFrame = CreateFrame("ScrollFrame", nil, configPanel, "UIPanelScrollFrameTemplate")
    unexpectedScrollFrame:SetSize(140, 300)
    unexpectedScrollFrame:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 40, -30)

    self.unexpectedScrollContent = CreateFrame("Frame", nil, unexpectedScrollFrame)
    self.unexpectedScrollContent:SetSize(520, 300)
    unexpectedScrollFrame:SetScrollChild(self.unexpectedScrollContent)

    self.unexpectedResultText = self.unexpectedScrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.unexpectedResultText:SetSize(500, 290)
    self.unexpectedResultText:SetPoint("TOPLEFT", 10, -10)
    self.unexpectedResultText:SetJustifyH("LEFT")
    self.unexpectedResultText:SetJustifyV("TOP")
    self.unexpectedResultText:SetWordWrap(true)

    self:UpdateDropdown()

    importButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            if self.massImportPopup and self.massImportPopup:IsShown() then
                return
            end

            local popup, editBox = UI:CreatePopupWithEditBox("Mass Import Splits", 550, 450,
                "Enter splits one per line in the format:\nTitle: name1, name2, name3\n\nExample:\nEarly 1: Jafjitsu, Strikedhtwo, Soulpten\nEarly 2: Jafsham, Strikemonk, Soulpsix\nTonight raid: Wooiben, Gucciform",
                function(text)
                    if self.massImportPopup then
                        self.massImportPopup:Hide()
                    end
                    self.massImportPopup = nil

                    if not text or text:trim() == "" then
                        return
                    end

                    local processedText = text:trim()
                    if processedText:len() > 1 and processedText:sub(1, 1) == '"' and processedText:sub(-1) == '"' then
                        processedText = processedText:sub(2, -2)
                    end

                    local lines = {}
                    for line in string.gmatch(processedText, "[^\r\n]+") do
                        table.insert(lines, line)
                    end

                    local importedCount = 0
                    local errors = {}
                    local tempNewSplitNames = {}

                    for i, lineData in ipairs(lines) do
                        local currentLine = lineData:match("^%s*(.-)%s*$")
                        if currentLine ~= "" then
                            local title, namesStr = currentLine:match("^(.-)%s*:%s*(.*)$")

                            if not title or not namesStr then
                                table.insert(errors,
                                    "Line " .. i .. ": Invalid format. Expected 'Title: name1, name2, ...'")
                            else
                                title = title:match("^%s*(.-)%s*$")
                                namesStr = namesStr:match("^%s*(.-)%s*$")

                                if title == "" then
                                    table.insert(errors, "Line " .. i .. ": Title cannot be empty.")
                                else
                                    local duplicateInBatch = false
                                    for _, existing in ipairs(tempNewSplitNames) do
                                        if existing == title then
                                            table.insert(errors, "Line " .. i .. ": Title '" .. title ..
                                                "' is duplicated in this batch.")
                                            duplicateInBatch = true
                                            break
                                        end
                                    end

                                    if not duplicateInBatch then
                                        local nameExists = false
                                        for _, existingProfile in ipairs(ACT.db.profile.splits.profiles) do
                                            if existingProfile.name == title then
                                                nameExists = true
                                                break
                                            end
                                        end
                                        if nameExists then
                                            table.insert(errors,
                                                "Line " .. i .. ": Title '" .. title .. "' already exists.")
                                            duplicateInBatch = true
                                        end
                                    end

                                    if not duplicateInBatch then
                                        local characters = {}
                                        for char in string.gmatch(namesStr, '([^,]+)') do
                                            table.insert(characters, strtrim(char))
                                        end

                                        if #characters > 40 then
                                            table.insert(errors, "Line " .. i .. " (Title: '" .. title ..
                                                "'): Too many names (" .. #characters .. "/40 max).")
                                        elseif #characters == 0 then
                                            table.insert(errors,
                                                "Line " .. i .. " (Title: '" .. title .. "'): No names found.")
                                        else
                                            table.insert(ACT.db.profile.splits.profiles, {
                                                name = title,
                                                characters = characters
                                            })
                                            table.insert(tempNewSplitNames, title)
                                            importedCount = importedCount + 1
                                        end
                                    end
                                end
                            end
                        end
                    end

                    self:UpdateDropdown()

                    local feedbackMsg = importedCount .. " split(s) imported successfully."
                    if #errors > 0 then
                        local errorSummary = ""
                        for errIdx = 1, math.min(5, #errors) do
                            errorSummary = errorSummary .. errors[errIdx] .. "\n"
                        end
                        feedbackMsg = feedbackMsg .. "\n\nEncountered " .. #errors .. " error(s):\n" ..
                                          errorSummary:trim()
                        if #errors > 5 then
                            feedbackMsg = feedbackMsg .. "\n(And " .. (#errors - 5) ..
                                              " more errors... See chat for full list.)"
                            DEFAULT_CHAT_FRAME:AddMessage("|cffffd100ACT Split Helper Mass Import Errors:|r")
                            for _, errMsg in ipairs(errors) do
                                DEFAULT_CHAT_FRAME:AddMessage("|cffff2020 - " .. errMsg .. "|r")
                            end
                        end
                    end

                    local reportPopup = UI:CreateTextPopup("Mass Import Report", feedbackMsg, "OK", "Close", nil,
                        function()
                        end, nil)
                    local numReportLines = importedCount + #errors + 5
                    local newHeight = math.min(500, 100 + numReportLines * 14)
                    reportPopup:SetSize(450, newHeight)
                    reportPopup:Show()
                end, function()
                    if self.massImportPopup then
                        self.massImportPopup:Hide()
                    end
                    self.massImportPopup = nil
                end)
            self.massImportPopup = popup
            self.massImportPopup:SetScript("OnHide", function()
                self.massImportPopup = nil
            end)
            self.massImportPopup:Show()
        else
            local characterString = self.importBox:GetText()
            if characterString ~= "" then
                self:ProcessCharacterString(characterString)
                self.importBox:SetText("")
                self:UpdateDropdown()
                self:DisplayImportedCharacters()
            end
        end
    end)

    deleteButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            if not SplitHelper.massDeletePopup then
                SplitHelper:CreateMassDeletePopup(configPanel)
            end
            SplitHelper:ShowMassDeletePopup()
        else
            if SplitHelper.selectedIndex then
                SplitHelper:ClearData(SplitHelper.selectedIndex)
                SplitHelper:CheckCharacters()
            end
        end
    end)

    renameButton:SetScript("OnClick", function()
        if self.selectedIndex then
            self:ShowRenamePopup(self.selectedIndex)
        end
    end)

    checkButton:SetScript("OnClick", function()
        if self.selectedIndex then
            self:CheckCharacters()
        end
    end)

    if not ACT.db.profile.splits then
        ACT.db.profile.splits = {
            profiles = {},
            KeepPosInGroup = true
        }
    end

    self.configPanel = configPanel
    self:CreateMassDeletePopup(configPanel)
    return configPanel
end

function SplitHelper:DisplayImportedCharacters()
    if not self.selectedIndex then
        return
    end
    local profile = ACT.db.profile.splits.profiles[self.selectedIndex]
    if not profile then
        return
    end

    local inBoth, inSheetNotRaid, inRaidNotSheet, unexpectedPlayers =
        self:CompareAndColorCharacters(self:GetRaidCharacters(), profile.characters)
    self:PrintColoredCharacters(inBoth, inSheetNotRaid, inRaidNotSheet)
    self:PrintUnexpectedCharacters(unexpectedPlayers)
end

function SplitHelper:ProcessCharacterString(characterString)
    local characters = {}
    for char in string.gmatch(characterString, '([^,]+)') do
        table.insert(characters, strtrim(char))
    end

    if #characters > 40 then
        errorHandler:SetText("Error: You can only import up to 40 players!")
        return
    end

    errorHandler:SetText("")

    table.insert(ACT.db.profile.splits.profiles, {
        name = "Import " .. (#ACT.db.profile.splits.profiles + 1),
        characters = characters
    })
end

function SplitHelper:UpdateDropdown()
    local options = {}
    for i, profile in ipairs(ACT.db.profile.splits.profiles) do
        table.insert(options, {
            text = profile.name,
            value = i,
            onClick = function()
                self.selectedIndex = i
                self.splitDropdown.button.text:SetText(profile.name)
                self:DisplayImportedCharacters()
            end
        })
    end
    UI:SetDropdownOptions(self.splitDropdown, options)
end

function SplitHelper:GetRaidCharacters()
    local raidCharacters = {}
    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            table.insert(raidCharacters, strtrim(name))
        end
    end
    return raidCharacters
end

function SplitHelper:StripRealmNames(characters)
    local strippedCharacters = {}
    for _, character in ipairs(characters) do
        local baseName = strsplit("-", character)
        table.insert(strippedCharacters, baseName)
    end
    return strippedCharacters
end

function SplitHelper:CompareAndColorCharacters(raidCharacters, sheetCharacters)
    local inBoth = {}
    local inSheetNotRaid = {}
    local inRaidNotSheet = {}
    local unexpectedPlayers = {}

    local strippedRaidCharacters = self:StripRealmNames(raidCharacters)
    local strippedSheetCharacters = self:StripRealmNames(sheetCharacters)

    local raidSet = {}
    for _, character in ipairs(strippedRaidCharacters) do
        raidSet[strlower(character)] = true
    end

    for _, character in ipairs(strippedSheetCharacters) do
        local lowerCharacter = strlower(character)
        if raidSet[lowerCharacter] then
            table.insert(inBoth, character)
            raidSet[lowerCharacter] = nil
        else
            table.insert(inSheetNotRaid, character)
        end
    end

    for character, _ in pairs(raidSet) do
        table.insert(inRaidNotSheet, character)
    end

    for _, character in ipairs(strippedRaidCharacters) do
        local foundInSheet = false
        for _, sheetCharacter in ipairs(strippedSheetCharacters) do
            if strlower(character) == strlower(sheetCharacter) then
                foundInSheet = true
                break
            end
        end
        if not foundInSheet then
            table.insert(unexpectedPlayers, character)
        end
    end

    return inBoth, inSheetNotRaid, inRaidNotSheet, unexpectedPlayers
end

function SplitHelper:PrintColoredCharacters(inBoth, inSheetNotRaid, inRaidNotSheet, unexpectedPlayers)
    inBoth = inBoth or {}
    inSheetNotRaid = inSheetNotRaid or {}
    inRaidNotSheet = inRaidNotSheet or {}
    unexpectedPlayers = unexpectedPlayers or {}

    for _, row in ipairs(self.characterRows) do
        row:Hide()
        table.insert(self.characterRowPool, row)
    end
    self.characterRows = {}

    local yOffset = -30
    local xOffset = 0

    local function createRow(character, color)
        local row = table.remove(self.characterRowPool)
        if not row then
            row = CreateFrame("Frame", nil, self.scrollContent, "BackdropTemplate")
            row:SetSize(120, 30)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1
            })
            row:SetBackdropColor(0.15, 0.15, 0.15, 1)
            row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("CENTER")
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.scrollContent, "TOPLEFT", xOffset, yOffset)
        row.nameText:SetText(color .. character .. "|r")
        row:Show()

        yOffset = yOffset - 30 + 1
        if yOffset == -175 then
            yOffset = yOffset - 10
        end
        if yOffset <= -(30 * 10 + 10) then
            yOffset = -30
            xOffset = xOffset + 133
        end

        table.insert(self.characterRows, row)
    end

    for i, character in ipairs(inBoth) do
        createRow(character, "|cff00ff00")
    end

    for i, character in ipairs(inSheetNotRaid) do
        createRow(character, "|cffff0000")
    end

    local totalRows = math.ceil(#inBoth / 10) + math.ceil(#inSheetNotRaid / 10) + math.ceil(#inRaidNotSheet / 10)
    self.scrollContent:SetHeight(totalRows * 30)
end

function SplitHelper:PrintUnexpectedCharacters(unexpectedPlayers)
    unexpectedPlayers = unexpectedPlayers or {}

    for _, row in ipairs(self.unexpectedCharacterRows or {}) do
        row:Hide()
        table.insert(self.unexpectedCharacterRowPool, row)
    end
    self.unexpectedCharacterRows = {}

    local yOffset = 0
    local xOffset = 10

    local function createUnexpectedRow(character)
        local row = table.remove(self.unexpectedCharacterRowPool)
        if not row then
            row = CreateFrame("Frame", nil, self.unexpectedScrollContent, "BackdropTemplate")
            row:SetSize(120, 30)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1
            })
            row:SetBackdropColor(0.15, 0.15, 0.15, 1)
            row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("CENTER")
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.unexpectedScrollContent, "TOPLEFT", xOffset, yOffset)
        row.nameText:SetText("|cffffff00" .. character .. "|r")
        row:Show()

        yOffset = yOffset - 30

        table.insert(self.unexpectedCharacterRows, row)
    end

    for i, character in ipairs(unexpectedPlayers) do
        createUnexpectedRow(character)
    end

    local totalRows = math.ceil(#unexpectedPlayers / 10)
    self.unexpectedScrollContent:SetHeight(totalRows * 30)
end

function SplitHelper:CreateCharacterRow(character, colorText, yOffset)
    local row = CreateFrame("Frame", nil, self.scrollContent, "BackdropTemplate")
    row:SetSize(520, 30)
    row:SetPoint("TOPLEFT", self.scrollContent, "TOPLEFT", 0, yOffset)

    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    row:SetBackdropColor(0.15, 0.15, 0.15, 1)
    row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("CENTER")
    nameText:SetText(colorText)

    return row
end

function SplitHelper:ClearData(index)
    if index and ACT.db.profile.splits.profiles[index] then
        table.remove(ACT.db.profile.splits.profiles, index)
        self.selectedIndex = nil
        self.splitDropdown.button.text:SetText("Select Split")
        self.resultText:SetText("")
        self:UpdateDropdown()

        for _, row in ipairs(self.characterRows) do
            row:Hide()
        end
        self.characterRows = {}
    end
end

function SplitHelper:CheckCharacters()
    if not self.selectedIndex then
        self:PrintColoredCharacters({}, {}, {})
        self:PrintUnexpectedCharacters({})
        return
    end

    local profile = ACT.db.profile.splits.profiles[self.selectedIndex]
    if not profile then
        return
    end

    local inBoth, inSheetNotRaid, inRaidNotSheet, unexpectedPlayers =
        self:CompareAndColorCharacters(self:GetRaidCharacters(), profile.characters)

    self:PrintColoredCharacters(inBoth, inSheetNotRaid, inRaidNotSheet)
    self:PrintUnexpectedCharacters(unexpectedPlayers)
end

function SplitHelper:ShowRenamePopup(index)
    if self.renamePopup then
        self.renamePopup:Hide()
        self.renamePopup = nil
        self.renameEditBox = nil
    end
    local profile = ACT.db.profile.splits.profiles[index]
    local defaultName = profile.name or ""
    self.renamePopup, self.renameEditBox = UI:CreatePopupWithEditBox("Enter new split name:", 320, 150, defaultName,
        function(newName)
            if newName and newName ~= "" then
                ACT.db.profile.splits.profiles[index].name = newName
                self:UpdateDropdown()
                self.splitDropdown.button.text:SetText(newName)
            end
            if self.renamePopup then
                self.renamePopup:Hide()
            end
        end, function()
            if self.renamePopup then
                self.renamePopup:Hide()
            end
        end)
    self.renamePopup:SetScript("OnHide", function()
        self.renamePopup = nil
        self.renameEditBox = nil
    end)
    self.renamePopup:Show()
end

ACT:RegisterModule(SplitHelper)
