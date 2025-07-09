local RaidGroups = {}
local classColorCache = {}

RaidGroups.title = "Raid Groups"
RaidGroups.currentListType = nil
RaidGroups.listPopulated = false
RaidGroups.guildCache = nil
RaidGroups.lastGuildUpdate = 0
RaidGroups.rosterMapping = {}
RaidGroups.selectedPresetIndex = nil
RaidGroups.isClassic = false
RaidGroups.keepPosInGroup = true
RaidGroups.nameFrames = {}
RaidGroups.nameFramePool = {}
RaidGroups.massImportPopup = nil
RaidGroups.massDeletePopup = nil
RaidGroups.exportPopup = nil
RaidGroups.massDeletePopupCheckboxes = {}
RaidGroups.massDeleteCheckboxPool = {}
RaidGroups.availablePlayerList = {}

local function GetClassColor(class)
    if class and classColorCache[class] then
        return classColorCache[class]
    end

    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    if colors and class and type(class) == "string" then
        local token = tostring(class):upper()
        if colors[token] then
            local c = colors[token]
            local colorTable = {c.r, c.g, c.b, 1}
            classColorCache[class] = colorTable
            return colorTable
        end
    end

    if not classColorCache["default"] then
        classColorCache["default"] = {1, 1, 1, 1}
    end
    return classColorCache["default"]
end

local function GetPlayerClassColorByName(playerName)
    local normalizedPlayerName = RaidGroups:NormalizeCharacterName(playerName)
    if RaidGroups.rosterMapping and RaidGroups.rosterMapping[normalizedPlayerName] then
        return RaidGroups.rosterMapping[normalizedPlayerName]
    end

    local currentRealm = GetRealmName()
    local lowerInput = normalizedPlayerName:lower()

    if IsInGroup() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, classToken = GetRaidRosterInfo(i)
            if name then
                local normalizedAPIName = RaidGroups:NormalizeCharacterName(name)
                if normalizedAPIName:lower() == lowerInput then
                    return GetClassColor(classToken)
                end
            end
        end
    end

    local numGuild = GetNumGuildMembers() or 0
    if numGuild > 0 then
        for i = 1, numGuild do
            local name, _, _, _, _, _, _, _, _, _, classToken = GetGuildRosterInfo(i)
            if name then
                local normalizedAPIName = RaidGroups:NormalizeCharacterName(name)
                if normalizedAPIName:lower() == lowerInput then
                    return GetClassColor(classToken)
                end
            end
        end
    end

    return GetClassColor(nil)
end

function RaidGroups:NormalizeCharacterName(name)
    local trimmed = name:match("^%s*(.-)%s*$")
    local dashPos = trimmed:find("-", 1, true)
    if dashPos then
        local basePart = trimmed:sub(1, dashPos - 1)
        local realmPart = trimmed:sub(dashPos)
        local lowerBase = string.lower(basePart)
        local normalizedBase = lowerBase:gsub("^%l", string.upper)
        return normalizedBase .. realmPart
    else
        local lower = string.lower(trimmed)
        return lower:gsub("^%l", string.upper)
    end
end

local DragContainer = CreateFrame("Frame", "RaidGroups_DragContainer", UIParent)
DragContainer:SetAllPoints(UIParent)
DragContainer:SetFrameStrata("HIGH")
DragContainer:SetFrameLevel(400)

local function ClearAllEditFocus()
    local focus = GetCurrentKeyBoardFocus()
    if focus then
        focus:ClearFocus()
    end
    if RaidGroups.groupSlots then
        for _, group in ipairs(RaidGroups.groupSlots) do
            for _, editBox in ipairs(group) do
                if editBox then
                    editBox:ClearFocus()
                end
            end
        end
    end
end

local function CreateCustomEditBox(parent, width, height, defaultText)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(width, height)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    container:SetBackdropColor(0.1, 0.1, 0.1, 1)
    container:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local editBox = CreateFrame("EditBox", nil, container)
    editBox:SetAllPoints(container)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetText(defaultText or "")
    editBox:SetJustifyH("LEFT")
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    local originalSetText = editBox.SetText
    editBox.SetText = function(self, text)
        originalSetText(self, text)
        self:SetJustifyH("LEFT")
    end

    container.editBox = editBox
    return container, editBox
end

function RaidGroups:ValidateAndNormalizePresetString(text)
    if type(text) ~= "string" then
        return nil, "Preset text must be a string."
    end

    local groups = {}
    for groupPart in string.gmatch(text, "([^;]+)") do
        table.insert(groups, groupPart)
    end

    if #groups > 8 then
        return nil, "Preset must contain at most 8 groups separated by ';'."
    elseif #groups < 1 then
        return nil, "Preset must contain at least 1 group."
    end

    local normalizedGroups = {}
    for i, groupStr in ipairs(groups) do
        local groupNum, namesStr = string.match(groupStr, "^%s*Group(%d+):%s*(.*)%s*$")
        if not groupNum then
            return nil, "Formatting error in group " .. i .. "."
        end
        groupNum = tonumber(groupNum)
        if groupNum ~= i then
            return nil, "Expected Group " .. i .. " but found Group " .. groupNum .. "."
        end

        local names = {}
        for name in string.gmatch(namesStr, "([^,]+)") do
            local trimmed = name:match("^%s*(.-)%s*$")
            if trimmed ~= "" then
                local normalized = self:NormalizeCharacterName(trimmed)
                table.insert(names, normalized)
            end
        end
        if #names > 5 then
            return nil, "Too many names in Group " .. i .. "."
        end
        while #names < 5 do
            table.insert(names, "")
        end
        normalizedGroups[i] = {
            group = i,
            names = names
        }
    end

    for i = #groups + 1, 8 do
        local names = {}
        for j = 1, 5 do
            table.insert(names, "")
        end
        normalizedGroups[i] = {
            group = i,
            names = names
        }
    end

    local seenNames = {}
    for i, group in ipairs(normalizedGroups) do
        for j, name in ipairs(group.names) do
            if name ~= "" then
                if seenNames[name] then
                    return nil, "Error: Duplicate character '" .. name .. "' detected in preset."
                else
                    seenNames[name] = true
                end
            end
        end
    end

    local presetParts = {}
    for _, grp in ipairs(normalizedGroups) do
        table.insert(presetParts, "Group" .. grp.group .. ": " .. table.concat(grp.names, ","))
    end
    local normalizedText = table.concat(presetParts, ";")
    return normalizedText
end

local function IsCursorInEditBox(editBox, marginY, marginX)
    marginY = marginY or 8
    marginX = marginX or 115
    local cx, cy = GetCursorPosition()
    local scale = editBox:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    local left, top = editBox:GetLeft(), editBox:GetTop()
    local right, bottom = editBox:GetRight(), editBox:GetBottom()
    return (cx >= left - marginX and cx <= right + marginX and cy <= top + marginY and cy >= bottom - marginY)
end

local function IsCursorInFrame(frame, margin)
    margin = margin or 10
    local cx, cy = GetCursorPosition()
    local scale = frame:GetEffectiveScale()

    if not scale or scale == 0 then
        return false
    end

    cx, cy = cx / scale, cy / scale
    local left, top = frame:GetLeft(), frame:GetTop()
    local right, bottom = frame:GetRight(), frame:GetBottom()

    if not left or not top or not right or not bottom then
        return false
    end

    return (cx >= left - margin and cx <= right + margin and cy <= top + margin and cy >= bottom - margin)
end

local function NameFrame_OnMouseDown(self, button)
    if button == "LeftButton" then
        ClearAllEditFocus()
        self:SetParent(DragContainer)
        self:SetFrameLevel(400)
        self:ClearAllPoints()
        self:StartMoving()
    end
end

local function NameFrame_OnMouseUp(self, button)
    if button == "LeftButton" then
        self:StopMovingOrSizing()
        local dropped = false
        local dropTargetBox = nil

        for _, group in ipairs(RaidGroups.groupSlots or {}) do
            for _, editBox in ipairs(group) do
                if editBox and IsCursorInEditBox(editBox, 8, 15) then
                    dropTargetBox = editBox
                    dropped = true
                    break
                end
            end
            if dropped then
                break
            end
        end

        self:SetParent(self.originalParent)

        if dropped then
            local r, g, b = unpack(self.classColor or {1, 1, 1, 1})
            local hexColor = string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
            local name = self.playerName or (self.nameText and self.nameText:GetText()) or ""
            dropTargetBox:SetText("|cff" .. hexColor .. name .. "|r")
            dropTargetBox:SetJustifyH("LEFT")
            dropTargetBox:SetCursorPosition(0)
            dropTargetBox.usedName = name

            self:Hide()
            RaidGroups:UpdateNameList(RaidGroups.currentListType or "raid")
        else
            if self.originalPoint and self.originalRelPoint then
                self:ClearAllPoints()
                self:SetPoint(self.originalPoint, self.originalParent, self.originalRelPoint, self.originalX,
                    self.originalY)
            end
            self:Show()
        end
    end
end

local function EnableGroupEditBoxDrag(editBox)
    editBox:EnableMouse(true)
    editBox:RegisterForDrag("LeftButton")

    editBox:SetScript("OnDragStart", function(self)
        if self:HasFocus() then
            self:ClearFocus()
            C_Timer.After(0.01, function()
                self.dragStartX, self.dragStartY = GetCursorPosition()
                self.isDragging = false
                self:SetScript("OnUpdate", function(self)
                    if not IsCursorInEditBox(self, 0, 0) then
                        self.isDragging = true
                        self:SetScript("OnUpdate", nil)
                        if self.usedName and self.usedName ~= "" then
                            local dragFrame = CreateFrame("Frame", nil, DragContainer, "BackdropTemplate")
                            dragFrame:SetSize(self:GetWidth(), self:GetHeight())
                            dragFrame:SetFrameStrata("TOOLTIP")
                            dragFrame:SetBackdrop({
                                bgFile = "Interface\\Buttons\\WHITE8x8",
                                edgeFile = "Interface\\Buttons\\WHITE8x8",
                                edgeSize = 1
                            })
                            dragFrame:SetBackdropBorderColor(1, 1, 1, 1)
                            dragFrame.text = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                            dragFrame.text:SetPoint("CENTER")
                            dragFrame.text:SetText(self.usedName)
                            dragFrame:EnableMouse(false)
                            dragFrame:SetScript("OnUpdate", function(frame)
                                local cx, cy = GetCursorPosition()
                                local scale = UIParent:GetEffectiveScale()
                                frame:ClearAllPoints()
                                frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
                            end)
                            self.dragFrame = dragFrame
                        end
                    end
                end)
            end)
        else
            self.dragStartX, self.dragStartY = GetCursorPosition()
            self.isDragging = false
            self:SetScript("OnUpdate", function(self)
                if not IsCursorInEditBox(self, 0, 0) then
                    self.isDragging = true
                    self:SetScript("OnUpdate", nil)
                    if self.usedName and self.usedName ~= "" then
                        local dragFrame = CreateFrame("Frame", nil, DragContainer, "BackdropTemplate")
                        dragFrame:SetSize(self:GetWidth(), self:GetHeight())
                        dragFrame:SetFrameStrata("TOOLTIP")
                        dragFrame:SetBackdrop({
                            bgFile = "Interface\\Buttons\\WHITE8x8",
                            edgeFile = "Interface\\Buttons\\WHITE8x8",
                            edgeSize = 1
                        })
                        dragFrame:SetBackdropBorderColor(1, 1, 1, 1)
                        dragFrame.text = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        dragFrame.text:SetPoint("CENTER")
                        dragFrame.text:SetText(self.usedName)
                        dragFrame:EnableMouse(false)
                        dragFrame:SetScript("OnUpdate", function(frame)
                            local cx, cy = GetCursorPosition()
                            local scale = UIParent:GetEffectiveScale()
                            frame:ClearAllPoints()
                            frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
                        end)
                        self.dragFrame = dragFrame
                    end
                end
            end)
        end
    end)

    editBox:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self.dragFrame then
            local dragFrame = self.dragFrame
            dragFrame:SetScript("OnUpdate", nil)
            dragFrame:Hide()

            local dropTarget = nil
            for g = 1, 8 do
                for s = 1, 5 do
                    local target = RaidGroups.groupSlots[g][s]
                    if target and IsCursorInEditBox(target, 8, 15) then
                        dropTarget = target
                        break
                    end
                end
                if dropTarget then
                    break
                end
            end

            local sourceEditBox = self
            local sourceText = sourceEditBox.usedName
            if dropTarget then
                local targetText = dropTarget.usedName or
                                       dropTarget:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                if dropTarget ~= sourceEditBox then
                    if targetText and targetText ~= "" then
                        local sourceColor = RaidGroups.rosterMapping[sourceText] or
                                                GetPlayerClassColorByName(sourceText) or {1, 1, 1, 1}
                        local targetColor = RaidGroups.rosterMapping[targetText] or
                                                GetPlayerClassColorByName(targetText) or {1, 1, 1, 1}
                        local sourceHex = string.format("%02x%02x%02x", sourceColor[1] * 255, sourceColor[2] * 255,
                            sourceColor[3] * 255)
                        local targetHex = string.format("%02x%02x%02x", targetColor[1] * 255, targetColor[2] * 255,
                            targetColor[3] * 255)
                        sourceEditBox:SetText("|cff" .. targetHex .. targetText .. "|r")
                        sourceEditBox:SetJustifyH("LEFT")
                        sourceEditBox:SetCursorPosition(0)
                        sourceEditBox.usedName = targetText
                        dropTarget:SetText("|cff" .. sourceHex .. sourceText .. "|r")
                        dropTarget:SetJustifyH("LEFT")
                        dropTarget:SetCursorPosition(0)
                        dropTarget.usedName = sourceText
                    else
                        local sourceColor = RaidGroups.rosterMapping[sourceText] or
                                                GetPlayerClassColorByName(sourceText) or {1, 1, 1, 1}
                        local sourceHex = string.format("%02x%02x%02x", sourceColor[1] * 255, sourceColor[2] * 255,
                            sourceColor[3] * 255)
                        dropTarget:SetText("|cff" .. sourceHex .. sourceText .. "|r")
                        dropTarget:SetJustifyH("LEFT")
                        dropTarget:SetCursorPosition(0)
                        dropTarget.usedName = sourceText
                        sourceEditBox:SetText("")
                        sourceEditBox:SetJustifyH("LEFT")
                        sourceEditBox:SetCursorPosition(0)
                        sourceEditBox.usedName = nil
                    end
                end
            else
                if IsCursorInFrame(RaidGroups.listScroll) then
                    sourceEditBox:SetText("")
                    sourceEditBox:SetJustifyH("LEFT")
                    sourceEditBox:SetCursorPosition(0)
                    sourceEditBox.usedName = nil
                    RaidGroups:UpdateNameList(RaidGroups.currentListType)
                else
                    local plain = sourceText or ""
                    if plain ~= "" then
                        local color = RaidGroups.rosterMapping[plain] or GetPlayerClassColorByName(plain)
                        if color then
                            local hexColor = string.format("%02x%02x%02x", color[1] * 255, color[2] * 255,
                                color[3] * 255)
                            sourceEditBox:SetText("|cff" .. hexColor .. plain .. "|r")
                        else
                            sourceEditBox:SetText(plain)
                        end
                    else
                        sourceEditBox:SetText("")
                    end
                    sourceEditBox:SetJustifyH("LEFT")
                    sourceEditBox:SetCursorPosition(0)
                end
            end
            self.dragFrame = nil
        end
        self.isDragging = nil
        RaidGroups:UpdateNameList(RaidGroups.currentListType)
    end)
end

function RaidGroups:GetConfigSize()
    return 1100, 600
end

function RaidGroups:CreateMassDeletePopup(parent)
    if self.massDeletePopup then
        return
    end

    local popup = CreateFrame("Frame", "RaidGroupsMassDeletePopupFrame", parent, "BackdropTemplate")
    popup:SetSize(420, 480)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("HIGH")
    popup:SetFrameLevel(249)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    popup:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
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
    title:SetText("Select Presets to Delete")

    local closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        popup:Hide()
    end)

    local scrollFrame = CreateFrame("ScrollFrame", "RaidGroupsMassDeleteListScrollFrame", popup,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -35, 70)
    popup.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", "RaidGroupsMassDeleteListScrollChild", scrollFrame)
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
        if RaidGroups.confirmDeleteAllPopupInstance and RaidGroups.confirmDeleteAllPopupInstance:IsShown() then
            return
        end
        RaidGroups.confirmDeleteAllPopupInstance = UI:CreateTextPopup("Confirm Delete All",
            "Are you sure you want to delete ALL presets? This action cannot be undone.", "Delete All", "Cancel",
            function()
                RaidGroups.Presets = {}
                VACT.RaidGroupsPresets = RaidGroups.Presets
                RaidGroups.selectedPresetIndex = nil
                if RaidGroups.presetsDropdown and RaidGroups.presetsDropdown.button then
                    RaidGroups.presetsDropdown.button.text:SetText("Select Preset")
                end
                RaidGroups:UpdatePresetsDropdown()
                if RaidGroups.massDeletePopup then
                    RaidGroups.massDeletePopup:Hide()
                end
                local reportPopup = UI:CreateTextPopup("Mass Delete", "All presets have been deleted.", "OK", "Close")
                reportPopup:SetFrameStrata("HIGH");
                reportPopup:SetFrameLevel(255);
                reportPopup:Show()
                RaidGroups.confirmDeleteAllPopupInstance = nil
            end, function()
                RaidGroups.confirmDeleteAllPopupInstance = nil
            end)
        RaidGroups.confirmDeleteAllPopupInstance:SetFrameStrata("HIGH")
        RaidGroups.confirmDeleteAllPopupInstance:SetFrameLevel(450)
        RaidGroups.confirmDeleteAllPopupInstance:SetScript("OnHide", function()
            RaidGroups.confirmDeleteAllPopupInstance = nil
        end)
        RaidGroups.confirmDeleteAllPopupInstance:Show()
    end)

    local deleteSelectedButton = UI:CreateButton(popup, "Delete Selected", 120, 25)
    deleteSelectedButton:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -20, 20)
    deleteSelectedButton:SetScript("OnClick", function()
        if RaidGroups.confirmDeleteSelectedPopupInstance and RaidGroups.confirmDeleteSelectedPopupInstance:IsShown() then
            return
        end
        local presetsToDeleteNames = {}
        for _, cb in ipairs(RaidGroups.massDeletePopupCheckboxes) do
            if cb:GetChecked() then
                table.insert(presetsToDeleteNames, cb.presetName)
            end
        end
        if #presetsToDeleteNames == 0 then
            return
        end
        RaidGroups.confirmDeleteSelectedPopupInstance = UI:CreateTextPopup("Confirm Deletion",
            "Are you sure you want to delete " .. #presetsToDeleteNames .. " preset(s)? This cannot be undone.",
            "Delete", "Cancel", function()
                local currentSelectedPresetName = (RaidGroups.selectedPresetIndex and
                                                      RaidGroups.Presets[RaidGroups.selectedPresetIndex]) and
                                                      RaidGroups.Presets[RaidGroups.selectedPresetIndex].name or nil
                local newPresetsList = {}
                local currentSelectionStillExists = false
                for _, presetData in ipairs(RaidGroups.Presets) do
                    local deleteThis = false
                    for _, nameToDelete in ipairs(presetsToDeleteNames) do
                        if presetData.name == nameToDelete then
                            deleteThis = true;
                            break
                        end
                    end
                    if not deleteThis then
                        table.insert(newPresetsList, presetData)
                        if currentSelectedPresetName and presetData.name == currentSelectedPresetName then
                            currentSelectionStillExists = true
                        end
                    end
                end
                RaidGroups.Presets = newPresetsList
                VACT.RaidGroupsPresets = RaidGroups.Presets
                if not currentSelectionStillExists then
                    RaidGroups.selectedPresetIndex = nil
                    if RaidGroups.presetsDropdown and RaidGroups.presetsDropdown.button then
                        RaidGroups.presetsDropdown.button.text:SetText("Select Preset")
                    end
                end
                RaidGroups:UpdatePresetsDropdown()
                if RaidGroups.massDeletePopup then
                    RaidGroups.massDeletePopup:Hide()
                end
                local reportPopup = UI:CreateTextPopup("Mass Delete", #presetsToDeleteNames .. " preset(s) deleted.",
                    "OK", "Close")
                reportPopup:SetFrameStrata("HIGH");
                reportPopup:SetFrameLevel(450);
                reportPopup:Show()
                RaidGroups.confirmDeleteSelectedPopupInstance = nil
            end, function()
                RaidGroups.confirmDeleteSelectedPopupInstance = nil
            end)
        RaidGroups.confirmDeleteSelectedPopupInstance:SetFrameStrata("HIGH");
        RaidGroups.confirmDeleteSelectedPopupInstance:SetFrameLevel(450)
        RaidGroups.confirmDeleteSelectedPopupInstance:SetScript("OnHide", function()
            RaidGroups.confirmDeleteSelectedPopupInstance = nil
        end)
        RaidGroups.confirmDeleteSelectedPopupInstance:Show()
    end)
    popup:Hide()
end

function RaidGroups:ShowMassDeletePopup()
    if not self.massDeletePopup or not self.massDeletePopup.scrollChild then
        return
    end
    if #self.Presets == 0 then
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

    for index, preset in ipairs(self.Presets) do
        local cb = table.remove(self.massDeleteCheckboxPool)
        if not cb then
            cb = CreateFrame("CheckButton", "RaidGroupsMassDeleteCB" .. index, scrollChild, "UICheckButtonTemplate")
            cb:SetSize(checkboxSize, checkboxSize)
            cb.text:SetFontObject(GameFontNormal)
            cb.text:SetJustifyH("LEFT")
            cb.text:ClearAllPoints()
            cb.text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
        end
        cb:SetPoint("TOPLEFT", 5, yOffset)
        cb.text:SetText(preset.name)
        cb.presetName = preset.name
        cb:SetChecked(false)
        cb:Show()
        table.insert(self.massDeletePopupCheckboxes, cb)
        yOffset = yOffset - checkboxSize - checkboxSpacing
    end
    scrollChild:SetHeight(math.max(self.massDeletePopup.scrollFrame:GetHeight() + 10, -yOffset + checkboxSpacing))
    self.massDeletePopup:Show()
end

function RaidGroups:CreateConfigPanel(parent)
    if self.configPanel then
        self.fullPlayerList = {}
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        self.Presets = VACT.RaidGroupsPresets or {}
        self:UpdatePresetsDropdown()
        return self.configPanel
    end

    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetAllPoints(parent)

    configPanel:SetScript("OnHide", function(self)
        RaidGroups:ClearNameList()
        RaidGroups.listPopulated = false
        RaidGroups.rosterMapping = {}
        if self.raidCheck then
            self.raidCheck:SetChecked(false)
        end
        if self.guildCheck then
            self.guildCheck:SetChecked(false)
        end
        RaidGroups.currentListType = nil
    end)

    local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    title:SetText("Raid Groups")

    local part1Frame = CreateFrame("Frame", nil, configPanel)
    part1Frame:SetSize(220, 500)
    part1Frame:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, -40)

    local raidCheck = CreateFrame("CheckButton", nil, part1Frame, "UICheckButtonTemplate")
    raidCheck:SetPoint("TOPLEFT", part1Frame, "TOPLEFT", 0, 0)
    raidCheck.text = raidCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidCheck.text:SetPoint("LEFT", raidCheck, "RIGHT", 5, 0)
    raidCheck.text:SetText("Raid")
    raidCheck:SetChecked(false)

    local guildCheck = CreateFrame("CheckButton", nil, part1Frame, "UICheckButtonTemplate")
    guildCheck:SetPoint("LEFT", raidCheck.text, "RIGHT", 10, 0)
    guildCheck.text = guildCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guildCheck.text:SetPoint("LEFT", guildCheck, "RIGHT", 5, 0)
    guildCheck.text:SetText("Guild")
    guildCheck:SetChecked(false)

    configPanel.raidCheck = raidCheck
    configPanel.guildCheck = guildCheck

    raidCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            if RaidGroups.currentListType == "raid" then
                return
            end
            guildCheck:SetChecked(false)
            RaidGroups.currentListType = "raid"
            RaidGroups.listPopulated = false
            RaidGroups:UpdateNameList("raid")
        else
            RaidGroups.currentListType = nil
            RaidGroups:ClearNameList()
        end
    end)
    guildCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            if RaidGroups.currentListType == "guild" then
                return
            end
            raidCheck:SetChecked(false)
            RaidGroups.currentListType = "guild"
            RaidGroups.listPopulated = false
            RaidGroups:UpdateNameList("guild")
        else
            RaidGroups.currentListType = nil
            RaidGroups:ClearNameList()
        end
    end)

    local listScroll = CreateFrame("ScrollFrame", nil, part1Frame, "UIPanelScrollFrameTemplate")
    self.listScroll = listScroll
    listScroll:SetScript("OnVerticalScroll", function(self, offset)
        RaidGroups:RefreshVisibleNames()
    end)
    listScroll:SetSize(210, 420)
    listScroll:SetPoint("TOPLEFT", raidCheck, "BOTTOMLEFT", 0, -10)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(210, 420)
    listContent:SetClipsChildren(true)
    listContent:EnableMouse(true)
    listContent:SetScript("OnMouseDown", function(self, button)
        ClearAllEditFocus()
    end)
    listScroll:SetScrollChild(listContent)
    self.nameListContent = listContent

    local part2Frame = CreateFrame("Frame", nil, configPanel)
    part2Frame:SetSize(600, 500)
    part2Frame:SetPoint("TOPLEFT", part1Frame, "TOPRIGHT", 40, 0)

    self.groupSlots = {}
    for group = 1, 8 do
        local groupFrame = CreateFrame("Frame", nil, part2Frame)
        groupFrame:SetSize(580, 50)
        groupFrame:SetPoint("TOPLEFT", part2Frame, "TOPLEFT", 10, -(group - 1) * 60)

        local header = groupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", groupFrame, "TOPLEFT", 0, 0)
        header:SetText("Group " .. group)

        self.groupSlots[group] = {}
        for slot = 1, 5 do
            local container, editBox = CreateCustomEditBox(groupFrame, 115, 20, "")
            container:SetPoint("TOPLEFT", groupFrame, "TOPLEFT", (slot - 1) * 115, -25)
            editBox.usedName = nil
            editBox:SetScript("OnEditFocusLost", function(self)
                local plain = self:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                if plain == "" then
                    self.usedName = nil
                else
                    local color = RaidGroups.rosterMapping[plain] or GetPlayerClassColorByName(plain)
                    if color then
                        local hexColor = string.format("%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
                        self:SetText("|cff" .. hexColor .. plain .. "|r")
                        self:SetCursorPosition(0)
                    end
                    self.usedName = plain
                end
                RaidGroups:UpdateNameList(RaidGroups.currentListType)
            end)
            EnableGroupEditBoxDrag(editBox)
            self.groupSlots[group][slot] = editBox
        end
    end

    local buttonWidth = 120
    local buttonHeight = 30
    local buttonSpacing = 15

    local setRosterButton = UI:CreateButton(configPanel, "Get Roster", buttonWidth, buttonHeight)
    setRosterButton:SetPoint("BOTTOMLEFT", part2Frame, "TOPLEFT", 10, 10)
    setRosterButton:SetScript("OnClick", function()
        local groups = {}
        local numRaid = GetNumGroupMembers() or 0
        for i = 1, numRaid do
            local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
            if name and subgroup then
                groups[subgroup] = groups[subgroup] or {}
                table.insert(groups[subgroup], {
                    name = name,
                    class = class
                })
            end
        end
        local currentRealm = GetRealmName()
        for group = 1, 8 do
            for slot = 1, 5 do
                local edit = RaidGroups.groupSlots[group][slot]
                local player = groups[group] and groups[group][slot]
                if player then
                    local baseName, realmName = player.name:match("^(.-)%-(.+)$")
                    local displayName = (baseName and realmName) and
                                            ((realmName == currentRealm) and baseName or (baseName .. "-" .. realmName)) or
                                            player.name
                    local color = GetClassColor(player.class)
                    local hexColor = string.format("%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
                    RaidGroups.rosterMapping[displayName] = color
                    edit:SetText("|cff" .. hexColor .. displayName .. "|r")
                    edit:SetCursorPosition(0)
                    edit.usedName = displayName
                else
                    edit:SetText("")
                    edit.usedName = nil
                end
            end
        end
        RaidGroups:UpdateNameList(RaidGroups.currentListType)
    end)

    local applyGroupsButton = UI:CreateButton(configPanel, "Apply Groups", buttonWidth, buttonHeight)
    applyGroupsButton:SetPoint("LEFT", setRosterButton, "RIGHT", buttonSpacing, 0)
    applyGroupsButton:SetScript("OnClick", function()
        local list = {}
        local nameCounts = {}
        local duplicateFound = false

        for group = 1, 8 do
            for slot = 1, 5 do
                local edit = RaidGroups.groupSlots[group][slot]
                local name = edit:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                name = name:match("^%s*(.-)%s*$")
                list[(group - 1) * 5 + slot] = name
                if name ~= "" then
                    if nameCounts[name] then
                        duplicateFound = true
                    else
                        nameCounts[name] = 1
                    end
                end
            end
        end

        if duplicateFound then
            if not applyGroupsButton.errorMsg then
                applyGroupsButton.errorMsg = applyGroupsButton:CreateFontString(nil, "OVERLAY", "GameFontRed")
                applyGroupsButton.errorMsg:SetPoint("TOP", applyGroupsButton, "BOTTOM", 0, -5)
            end
            applyGroupsButton.errorMsg:SetText("Error: Duplicate characters detected!")
            applyGroupsButton.errorMsg:Show()
            C_Timer.After(3, function()
                if applyGroupsButton.errorMsg then
                    applyGroupsButton.errorMsg:Hide()
                end
            end)
            return
        end
        RaidGroups:ApplyGroups(list)
    end)

    local clearGroupsButton = UI:CreateButton(configPanel, "Clear Groups", buttonWidth, buttonHeight)
    clearGroupsButton:SetPoint("LEFT", applyGroupsButton, "RIGHT", buttonSpacing, 0)
    clearGroupsButton:SetScript("OnClick", function()
        for group = 1, 8 do
            for slot = 1, 5 do
                local editBox = RaidGroups.groupSlots[group][slot]
                editBox:SetText("")
                editBox.usedName = nil
            end
        end
        RaidGroups:UpdateNameList(RaidGroups.currentListType)
    end)

    local exportGroupButton = UI:CreateButton(configPanel, "Export Group", buttonWidth, buttonHeight)
    exportGroupButton:SetPoint("LEFT", clearGroupsButton, "RIGHT", buttonSpacing, 0)
    exportGroupButton:SetScript("OnClick", function()
        if RaidGroups.exportPopup and RaidGroups.exportPopup:IsShown() then
            RaidGroups.exportPopup:Raise()
            return
        end

        if not IsInGroup() then
            return
        end

        local rosterList = {}
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, _, _, _, _, _, _, _, server = GetRaidRosterInfo(i)
            if name then
                local baseName, realmName = name:match("^(.-)%-(.+)$")
                if not baseName then
                    baseName = name
                    realmName = GetRealmName()
                end
                table.insert(rosterList, baseName .. " - " .. realmName)
            end
        end
        local rosterString = table.concat(rosterList, "\n")

        if not RaidGroups.exportPopup then
            local popup = CreateFrame("Frame", "RaidGroupsExportPopup", configPanel, "BackdropTemplate")
            popup:SetSize(400, 450)
            popup:SetPoint("CENTER")
            popup:SetFrameStrata("HIGH")
            popup:SetFrameLevel(500)
            popup:SetMovable(true)
            popup:EnableMouse(true)
            popup:RegisterForDrag("LeftButton")
            popup:SetScript("OnDragStart", function(self)
                self:StartMoving()
            end)
            popup:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
            end)
            popup:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1
            })
            popup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
            popup:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

            local title = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            title:SetPoint("TOP", 0, -12)
            title:SetText("Exported Roster")

            local xButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
            xButton:SetPoint("TOPRIGHT", -5, -5)
            xButton:SetScript("OnClick", function()
                popup:Hide()
            end)

            local boxContainer, editBox = UI:CreateReadOnlyBox(popup, 360, 350, "")
            boxContainer:SetPoint("TOP", title, "BOTTOM", 0, -10)
            popup.textDisplay = editBox

            boxContainer:EnableMouse(true)
            boxContainer:SetScript("OnMouseDown", function()
                editBox:SetFocus()
            end)

            local scrollFrame = editBox:GetParent()
            if scrollFrame and scrollFrame:IsObjectType("ScrollFrame") then
                scrollFrame:EnableMouse(true)
                scrollFrame:SetScript("OnMouseDown", function()
                    editBox:SetFocus()
                end)
            end

            editBox:SetScript("OnEditFocusGained", function(self)
                boxContainer:SetBackdropColor(0.2, 0.2, 0.2, 1)
                boxContainer:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
                self:HighlightText()
            end)

            editBox:SetScript("OnEditFocusLost", function(self)
                boxContainer:SetBackdropColor(0.1, 0.1, 0.1, 1)
                boxContainer:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            end)

            local closeButton = UI:CreateButton(popup, "Close", 100, 25)
            closeButton:SetPoint("BOTTOM", 0, 20)
            closeButton:SetScript("OnClick", function()
                popup:Hide()
            end)

            RaidGroups.exportPopup = popup
        end

        RaidGroups.exportPopup.textDisplay:SetText(rosterString)
        RaidGroups.exportPopup.textDisplay:GetParent():SetVerticalScroll(0)
        RaidGroups.exportPopup:Show()
        RaidGroups.exportPopup:Raise()
    end)

    local part3Frame = CreateFrame("Frame", nil, configPanel)
    part3Frame:SetSize(960, 60)
    part3Frame:SetPoint("BOTTOMLEFT", configPanel, "BOTTOMLEFT", 20, 20)

    local savePresetButton = UI:CreateButton(configPanel, "Save Preset", 100, 30)
    savePresetButton:SetPoint("TOPLEFT", part3Frame, "TOPLEFT", 0, 0)
    savePresetButton:SetScript("OnClick", function()
        if isRenamePopupOpen then
            return
        end

        local hasData = false
        local presetParts = {}
        for group = 1, 8 do
            local names = {}
            for slot = 1, 5 do
                local name = RaidGroups.groupSlots[group][slot].usedName or ""
                if name ~= "" then
                    hasData = true
                end
                table.insert(names, name)
            end
            table.insert(presetParts, "Group" .. group .. ": " .. table.concat(names, ","))
        end
        if not hasData then
            return
        end

        local presetData = table.concat(presetParts, ";")

        isRenamePopupOpen = true
        local popup, editBox = UI:CreatePopupWithEditBox("Save Preset", 320, 150, "", function(newName)
            if newName and newName:trim() ~= "" then
                local presetName = newName
                table.insert(RaidGroups.Presets, {
                    name = presetName,
                    data = presetData
                })
                VACT.RaidGroupsPresets = RaidGroups.Presets
                RaidGroups:UpdatePresetsDropdown()
                RaidGroups.selectedPresetIndex = #RaidGroups.Presets
                RaidGroups.presetsDropdown.button.text:SetText(presetName)
            end
            isRenamePopupOpen = false
        end, function()
            isRenamePopupOpen = false
        end)
        popup:Show()
    end)

    function RaidGroups:ImportPresetWithCustomName(normalizedText)
        local function onNameEntered(customName)
            customName = customName and customName:trim() or ""
            if customName == "" then
                customName = "Imported Preset " .. (#self.Presets + 1)
            end
            table.insert(self.Presets, {
                name = customName,
                data = normalizedText
            })
            VACT.RaidGroupsPresets = self.Presets
            self:UpdatePresetsDropdown()
            self.presetsDropdown.button.text:SetText(customName)
            self.selectedPresetIndex = #self.Presets
        end
        local popup, editBox = UI:CreatePopupWithEditBox("Enter Preset Name", 320, 150, "", onNameEntered)
        popup:Show()
    end

    local importPresetButton = UI:CreateButton(configPanel, "Import Preset", 100, 30)
    importPresetButton:SetPoint("LEFT", savePresetButton, "RIGHT", 20, 0)
    importPresetButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            if RaidGroups.massImportPopup and RaidGroups.massImportPopup:IsShown() then
                return
            end

            local popup, editBox = UI:CreatePopupWithEditBox("Mass Import Presets", 550, 450,
                "Enter presets one per line in the format:\nPreset Name:PresetString\n\nExample:\nMugzee:Group1:PlayerA,PlayerB;Group2:PlayerC\nGallywix:Group1:PlayerX,PlayerY",
                function(text)
                    if RaidGroups.massImportPopup then
                        RaidGroups.massImportPopup:Hide()
                    end
                    RaidGroups.massImportPopup = nil

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
                    local tempNewPresetNames = {}

                    for i, lineData in ipairs(lines) do
                        local processThisLine = true
                        local currentLine = lineData:match("^%s*(.-)%s*$")
                        if currentLine ~= "" then
                            local presetName = currentLine:match("^(.-):")
                            local presetString = currentLine:match(":(.*)$")

                            if presetName and presetString then
                                presetName = presetName:match("^%s*(.-)%s*$")
                                presetString = presetString:match("^%s*(.-)%s*$")

                                if presetName == "" then
                                    table.insert(errors, "Line " .. i .. ": Preset name cannot be empty.")
                                    processThisLine = false
                                end

                                if processThisLine then
                                    for _, newNameInBatch in ipairs(tempNewPresetNames) do
                                        if newNameInBatch == presetName then
                                            table.insert(errors, "Line " .. i .. ": Preset name '" .. presetName ..
                                                "' is duplicated in this import batch.")
                                            processThisLine = false
                                            break
                                        end
                                    end
                                end

                                if processThisLine then
                                    local nameExists = false
                                    for _, existingPreset in ipairs(RaidGroups.Presets) do
                                        if existingPreset.name == presetName then
                                            nameExists = true
                                            break
                                        end
                                    end
                                    if nameExists then
                                        table.insert(errors, "Line " .. i .. ": Preset name '" .. presetName ..
                                            "' already exists.")
                                        processThisLine = false
                                    end
                                end

                                if processThisLine then
                                    local normalizedText, err =
                                        RaidGroups:ValidateAndNormalizePresetString(presetString)
                                    if normalizedText then
                                        table.insert(RaidGroups.Presets, {
                                            name = presetName,
                                            data = normalizedText
                                        })
                                        table.insert(tempNewPresetNames, presetName)
                                        importedCount = importedCount + 1
                                    else
                                        table.insert(errors, "Line " .. i .. " (Name: '" .. presetName .. "'): " ..
                                            (err or "Invalid preset string format."))
                                    end
                                else
                                    table.insert(errors, "Line " .. i ..
                                        ": Invalid format. Expected 'Preset Name:PresetString'.")
                                end
                            end
                        end
                    end

                    VACT.RaidGroupsPresets = RaidGroups.Presets
                    RaidGroups:UpdatePresetsDropdown()

                    local feedbackMsg = importedCount .. " preset(s) imported successfully."
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
                            DEFAULT_CHAT_FRAME:AddMessage("|cffffd100ACT Mass Import Errors:|r")
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
                    if RaidGroups.massImportPopup then
                        RaidGroups.massImportPopup:Hide()
                    end
                    RaidGroups.massImportPopup = nil
                end)
            RaidGroups.massImportPopup = popup

            RaidGroups.massImportPopup:SetScript("OnHide", function()
                RaidGroups.massImportPopup = nil
            end)
            RaidGroups.massImportPopup:Show()

        else
            if RaidGroups.importPopup and RaidGroups.importPopup:IsShown() then
                return
            end

            local popup, editBox = UI:CreatePopupWithEditBox("Import Preset String", 320, 150, "", nil, function()
                RaidGroups.importPopup = nil
            end)
            RaidGroups.importPopup = popup

            local acceptButton = nil
            for i = 1, RaidGroups.importPopup:GetNumChildren() do
                local child = select(i, RaidGroups.importPopup:GetChildren())
                if child:IsObjectType("Button") and child.text and child.text:GetText() == "Accept" then
                    acceptButton = child
                    break
                end
            end

            if not acceptButton then
                RaidGroups.importPopup:Hide()
                RaidGroups.importPopup = nil
                print("Error: Could not find Accept button in single import popup.")
                return
            end

            local originalPopupHeight = RaidGroups.importPopup:GetHeight()

            acceptButton:SetScript("OnClick", function()
                local text = editBox:GetText()
                if not (text and text:trim() ~= "") then
                    RaidGroups.importPopup:Hide()
                    RaidGroups.importPopup = nil
                    return
                end

                local normalizedText, err = RaidGroups:ValidateAndNormalizePresetString(text)
                if not normalizedText then
                    if not RaidGroups.importPopup.errorMsg then
                        RaidGroups.importPopup.errorMsg = RaidGroups.importPopup:CreateFontString(nil, "OVERLAY",
                            "GameFontRed")
                        RaidGroups.importPopup.errorMsg:SetWordWrap(true)
                        RaidGroups.importPopup.errorMsg:SetWidth(RaidGroups.importPopup:GetWidth() - 40)
                        RaidGroups.importPopup.errorMsg:SetJustifyH("CENTER")
                        local editFrameContainer = editBox:GetParent()
                        RaidGroups.importPopup.errorMsg:SetPoint("TOP", editFrameContainer, "BOTTOM", 0, -10)
                    end
                    RaidGroups.importPopup.errorMsg:SetText(err or "Invalid preset string format.")
                    RaidGroups.importPopup.errorMsg:Show()

                    local errorTextHeight = RaidGroups.importPopup.errorMsg:GetStringHeight() or 20
                    RaidGroups.importPopup:SetHeight(originalPopupHeight + errorTextHeight + 10)

                    C_Timer.After(3, function()
                        if RaidGroups.importPopup and RaidGroups.importPopup.errorMsg then
                            RaidGroups.importPopup.errorMsg:Hide()
                            RaidGroups.importPopup:SetHeight(originalPopupHeight)
                        end
                    end)
                    return false
                else
                    if RaidGroups.importPopup.errorMsg then
                        RaidGroups.importPopup.errorMsg:Hide()
                        RaidGroups.importPopup:SetHeight(originalPopupHeight)
                    end
                    RaidGroups:ImportPresetWithCustomName(normalizedText)
                    RaidGroups.importPopup:Hide()
                    RaidGroups.importPopup = nil
                end
            end)
            RaidGroups.importPopup:Show()
        end
    end)

    local presetsDropdown = UI:CreateDropdown(part3Frame, 200, 30)
    presetsDropdown:SetPoint("LEFT", importPresetButton, "RIGHT", 20, 0)
    presetsDropdown.button.text:SetText("Select Preset")
    self.presetsDropdown = presetsDropdown

    self.Presets = VACT.RaidGroupsPresets or {}
    RaidGroups:UpdatePresetsDropdown()

    local renamePresetButton = UI:CreateButton(part3Frame, "Rename Preset", 100, 30)
    renamePresetButton:SetPoint("LEFT", presetsDropdown, "RIGHT", 20, 0)
    renamePresetButton:SetScript("OnClick", function()
        if RaidGroups.renamePopup and RaidGroups.renamePopup:IsShown() then
            return
        end

        if not RaidGroups.selectedPresetIndex then
            return
        end

        local currentPreset = RaidGroups.Presets[RaidGroups.selectedPresetIndex]
        if not currentPreset then
            return
        end

        RaidGroups.renamePopup = UI:CreatePopupWithEditBox("Rename Preset", 320, 150, currentPreset.name or "",
            function(newName)
                if newName and newName:trim() ~= "" then
                    currentPreset.name = newName
                    VACT.RaidGroupsPresets = RaidGroups.Presets
                    RaidGroups:UpdatePresetsDropdown()
                    RaidGroups.presetsDropdown.button.text:SetText(newName)
                end
                RaidGroups.renamePopup = nil
            end, function()
                RaidGroups.renamePopup = nil
            end)
        RaidGroups.renamePopup:Show()
    end)

    local deletePresetButton = UI:CreateButton(part3Frame, "Delete Preset", 100, 30)
    deletePresetButton:SetPoint("LEFT", renamePresetButton, "RIGHT", 20, 0)
    deletePresetButton:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            RaidGroups:ShowMassDeletePopup()
        else
            if RaidGroups.confirmSingleDeletePopupInstance and RaidGroups.confirmSingleDeletePopupInstance:IsShown() then
                return
            end

            if not RaidGroups.selectedPresetIndex then
                if RaidGroups.noPresetsInfoPopupInstance and RaidGroups.noPresetsInfoPopupInstance:IsShown() then
                    return
                end
                RaidGroups.noPresetsInfoPopupInstance = UI:CreateTextPopup("Delete Preset",
                    "No preset selected to delete.", "OK", "Close", function()
                        if RaidGroups.noPresetsInfoPopupInstance then
                            RaidGroups.noPresetsInfoPopupInstance:Hide()
                        end
                    end, function()
                        if RaidGroups.noPresetsInfoPopupInstance then
                            RaidGroups.noPresetsInfoPopupInstance:Hide()
                        end
                    end)
                RaidGroups.noPresetsInfoPopupInstance:SetFrameStrata("HIGH")
                RaidGroups.noPresetsInfoPopupInstance:SetFrameLevel(250)
                RaidGroups.noPresetsInfoPopupInstance:SetScript("OnHide", function()
                    RaidGroups.noPresetsInfoPopupInstance = nil
                end)
                RaidGroups.noPresetsInfoPopupInstance:Show()
                return
            end

            local presetToDel = RaidGroups.Presets[RaidGroups.selectedPresetIndex]
            if not presetToDel then
                return
            end

            RaidGroups.confirmSingleDeletePopupInstance = true

            RaidGroups.confirmSingleDeletePopupInstance = UI:CreateTextPopup("Confirm Delete",
                "Are you sure you want to delete the preset '" .. presetToDel.name .. "'?", "Delete", "Cancel",
                function()
                    table.remove(RaidGroups.Presets, RaidGroups.selectedPresetIndex)
                    RaidGroups.selectedPresetIndex = nil
                    if RaidGroups.presetsDropdown and RaidGroups.presetsDropdown.button then
                        RaidGroups.presetsDropdown.button.text:SetText("Select Preset")
                    end
                    VACT.RaidGroupsPresets = RaidGroups.Presets
                    RaidGroups:UpdatePresetsDropdown()
                    RaidGroups.confirmSingleDeletePopupInstance = nil
                end, function()
                    RaidGroups.confirmSingleDeletePopupInstance = nil
                end)
            RaidGroups.confirmSingleDeletePopupInstance:SetFrameStrata("HIGH")
            RaidGroups.confirmSingleDeletePopupInstance:SetFrameLevel(450)
            RaidGroups.confirmSingleDeletePopupInstance:SetScript("OnHide", function()
                RaidGroups.confirmSingleDeletePopupInstance = nil
            end)
            RaidGroups.confirmSingleDeletePopupInstance:Show()
        end
    end)

    local setPresetButton = UI:CreateButton(configPanel, "Set Preset", 100, 30)
    setPresetButton:SetPoint("LEFT", deletePresetButton, "RIGHT", 20, 0)
    setPresetButton:SetScript("OnClick", function()
        if not RaidGroups.selectedPresetIndex then
            return
        end
        local preset = RaidGroups.Presets[RaidGroups.selectedPresetIndex]
        if preset and preset.data then
            RaidGroups:ApplyPreset(preset.data)
        end
    end)

    self:CreateMassDeletePopup(configPanel)

    self.configPanel = configPanel
    return configPanel
end

function RaidGroups:UpdatePresetsDropdown()
    local options = {}
    for i, preset in ipairs(self.Presets or {}) do
        table.insert(options, {
            text = preset.name,
            value = i,
            onClick = function()
                self.selectedPresetIndex = i
                self.presetsDropdown.button.text:SetText(preset.name)
            end
        })
    end
    UI:SetDropdownOptions(self.presetsDropdown, options)
end

function RaidGroups:ClearNameList()
    self.fullPlayerList = {}
    self.availablePlayerList = {}
    for _, frame in ipairs(self.nameFrames or {}) do
        frame:Hide()
        table.insert(self.nameFramePool, frame)
    end
    self.nameFrames = {}
    if self.nameListContent then
        self.nameListContent:SetHeight(420)
    end
end

function RaidGroups:GetUsedNames()
    local used = {}
    for _, group in ipairs(self.groupSlots or {}) do
        for _, editBox in ipairs(group) do
            if editBox.usedName then
                used[editBox.usedName] = true
            end
        end
    end
    return used
end

function RaidGroups:RefreshVisibleNames()
    if not self.listScroll or not self.nameListContent then
        return
    end

    local scrollOffset = self.listScroll:GetVerticalScroll()
    local viewHeight = self.listScroll:GetHeight()
    local lineHeight = 22

    local firstVisibleIndex = math.floor(scrollOffset / lineHeight) + 1
    local lastVisibleIndex = math.ceil((scrollOffset + viewHeight) / lineHeight)

    for _, frame in ipairs(self.nameFrames or {}) do
        frame:Hide()
        table.insert(self.nameFramePool, frame)
    end
    self.nameFrames = {}

    firstVisibleIndex = math.max(1, firstVisibleIndex)
    lastVisibleIndex = math.min(#self.availablePlayerList, lastVisibleIndex)

    for i = firstVisibleIndex, lastVisibleIndex do
        local player = self.availablePlayerList[i]
        if player then
            local frame = table.remove(self.nameFramePool)
            if not frame then
                frame = self:CreateDraggableNameFrame(self.nameListContent, "", {1, 1, 1, 1}, "")
            end

            local color = GetClassColor(player.class)
            frame.playerName = player.name
            frame.classColor = color or {1, 1, 1, 1}
            frame.class = player.class
            frame.nameText:SetText(player.name)
            frame.nameText:SetTextColor(unpack(color or {1, 1, 1, 1}))
            frame.originalParent = self.nameListContent

            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", self.nameListContent, "TOPLEFT", 0, -(i - 1) * lineHeight)
            frame.originalPoint = "TOPLEFT"
            frame.originalRelPoint = "TOPLEFT"
            frame.originalX = 0
            frame.originalY = -(i - 1) * lineHeight

            frame:SetParent(self.nameListContent)
            frame:Show()
            table.insert(self.nameFrames, frame)
        end
    end
end

function RaidGroups:UpdateNameList(listType)
    local namesForList = {}
    self.rosterMapping = {}
    local currentRealm = GetRealmName()

    if listType == "raid" and (IsInRaid() or IsInGroup()) then
        local numRaid = GetNumGroupMembers() or 0
        for i = 1, numRaid do
            local name, _, _, _, _, class = GetRaidRosterInfo(i)
            if name then
                local baseName, realmName = name:match("^(.-)%-(.+)$")
                local displayName = (baseName and realmName) and
                                        ((realmName == currentRealm) and baseName or (baseName .. "-" .. realmName)) or
                                        name
                local normalizedName = self:NormalizeCharacterName(displayName)
                table.insert(namesForList, {
                    name = displayName,
                    class = class,
                    order = i
                })
                self.rosterMapping[normalizedName] = GetClassColor(class)
            end
        end
    elseif listType == "guild" then
        if not self.guildCache or (GetTime() - self.lastGuildUpdate) > 300 then
            self.guildCache = {}
            local numGuild = GetNumGuildMembers() or 0
            for i = 1, numGuild do
                local name, _, rankIndex, _, _, _, _, _, _, _, classToken = GetGuildRosterInfo(i)
                if name then
                    rankIndex = rankIndex or i
                    local baseName, realmName = name:match("^(.-)%-(.+)$")
                    local displayName = (baseName and realmName) and
                                            ((realmName == currentRealm) and baseName or (baseName .. "-" .. realmName)) or
                                            name
                    local normalizedName = self:NormalizeCharacterName(displayName)
                    table.insert(self.guildCache, {
                        name = displayName,
                        class = classToken,
                        rankIndex = rankIndex
                    })
                    if not self.rosterMapping[normalizedName] then
                        self.rosterMapping[normalizedName] = GetClassColor(classToken)
                    end
                end
            end
            self.lastGuildUpdate = GetTime()
            table.sort(self.guildCache, function(a, b)
                return a.rankIndex < b.rankIndex
            end)
        end
        namesForList = self.guildCache
    end

    self.fullPlayerList = namesForList

    local used = self:GetUsedNames()
    self.availablePlayerList = {}
    for _, player in ipairs(self.fullPlayerList) do
        if not used[player.name] then
            table.insert(self.availablePlayerList, player)
        end
    end

    if not self.nameListContent then
        return
    end

    local totalEntries = #self.availablePlayerList
    local lineHeight = 22
    self.nameListContent:SetHeight(totalEntries * lineHeight)

    if self.currentListType ~= listType then
        self.listScroll:SetVerticalScroll(0)
    end

    self:RefreshVisibleNames()
    self.listPopulated = true
    self.currentListType = listType
end

function RaidGroups:CreateDraggableNameFrame(parent, playerName, classColor, class)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame.isNameFrame = true
    frame:SetSize(200, 20)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
        bgFile = nil,
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    frame:SetBackdropBorderColor(1, 1, 1, 1)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame.nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.nameText:SetPoint("CENTER")

    if playerName and playerName ~= "" then
        frame.nameText:SetText(playerName)
        frame.nameText:SetTextColor(unpack(classColor or {1, 1, 1, 1}))
    end

    frame.class = class
    frame.playerName = playerName
    frame.classColor = classColor or {1, 1, 1, 1}
    frame.originalParent = parent
    frame.originalPoint, frame.originalRelPoint = nil, nil
    frame.originalX, frame.originalY = nil, nil

    frame:SetScript("OnMouseDown", NameFrame_OnMouseDown)
    frame:SetScript("OnMouseUp", NameFrame_OnMouseUp)
    frame:SetScript("OnDragStart", function(self, button)
        if button == "LeftButton" then
            ClearAllEditFocus()
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    return frame
end

function RaidGroups:ApplyGroups(list)
    if not IsInRaid() then
        return
    end

    local UnitsInCombat = ""
    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitAffectingCombat(unit) then
            UnitsInCombat = UnitsInCombat .. (UnitsInCombat ~= "" and "," or "") .. UnitName(unit)
        end
    end
    if UnitsInCombat ~= "" then
        return
    end

    self.db = self.db or {}
    local needGroup = {}
    local needPosInGroup = {}
    local lockedUnit = {}

    local RLName, _, RLGroup = GetRaidRosterInfo(1)
    local isRLfound = false
    for i = 1, 8 do
        local pos = 1
        for j = 1, 5 do
            local name = list[(i - 1) * 5 + j]
            if name == RLName then
                needGroup[name] = i
                needPosInGroup[name] = pos
                pos = pos + 1
                isRLfound = true
                break
            end
        end
        for j = 1, 5 do
            local name = list[(i - 1) * 5 + j]
            if name and name ~= RLName and UnitName(name) then
                needGroup[name] = i
                needPosInGroup[name] = pos
                pos = pos + 1
            end
        end
    end

    if self.isClassic and not self.keepPosInGroup then
        needPosInGroup = {}
    end

    self.db.needGroup = needGroup
    self.db.needPosInGroup = needPosInGroup
    self.db.lockedUnit = lockedUnit
    self.db.groupsReady = false
    self.db.groupWithRL = isRLfound and 0 or RLGroup

    self:ProcessRoster()
end

function RaidGroups:ProcessRoster()
    if InCombatLockdown() then
        self.db.needGroup = nil
        return
    end

    local needGroup = self.db.needGroup
    local needPosInGroup = self.db.needPosInGroup
    local lockedUnit = self.db.lockedUnit
    if not needGroup then
        return
    end

    local currentGroup, currentPos, nameToID, groupSize = {}, {}, {}, {}
    for i = 1, 8 do
        groupSize[i] = 0
    end

    for i = 1, GetNumGroupMembers() do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name then
            local checkName = name
            if not needGroup[checkName] and checkName:find("%-") and needGroup[strsplit("-", checkName)] then
                checkName = strsplit("-", checkName)
            end
            currentGroup[name] = subgroup
            nameToID[name] = i
            groupSize[subgroup] = groupSize[subgroup] + 1
            currentPos[name] = groupSize[subgroup]
        end
    end

    if not self.db.groupsReady then
        local waitForGroup = false
        for unit, group in pairs(needGroup) do
            if currentGroup[unit] and currentGroup[unit] ~= group and nameToID[unit] then
                if groupSize[group] < 5 then
                    SetRaidSubgroup(nameToID[unit], group)
                    waitForGroup = true
                end
            end
        end
        if waitForGroup then
            return
        end

        local setToSwap, waitForSwap = {}, false
        for unit, group in pairs(needGroup) do
            if not setToSwap[unit] and currentGroup[unit] and currentGroup[unit] ~= group and nameToID[unit] then
                local unitToSwap
                for unit2, group2 in pairs(currentGroup) do
                    if not setToSwap[unit2] and group2 == group and needGroup[unit2] ~= group2 and nameToID[unit2] then
                        unitToSwap = unit2
                        break
                    end
                end
                if unitToSwap then
                    SwapRaidSubgroup(nameToID[unit], nameToID[unitToSwap])
                    waitForSwap = true
                    setToSwap[unit] = true
                    setToSwap[unitToSwap] = true
                end
            end
        end
        if waitForSwap then
            return
        end

        self.db.groupsReady = true
    end

    do
        local setToSwap, waitForSwap = {}, false
        for unit, pos in pairs(needPosInGroup) do
            if not lockedUnit[unit] and currentPos[unit] and currentPos[unit] ~= pos and nameToID[unit] and
                nameToID[unit] ~= 1 and not setToSwap[unit] then
                local unitToSwap, unitToSwapBridge

                for unit2, pos2 in pairs(currentPos) do
                    if currentGroup[unit2] == currentGroup[unit] and pos2 == pos and nameToID[unit2] and nameToID[unit2] ~=
                        1 and not setToSwap[unit2] then
                        unitToSwap = unit2
                        break
                    end
                end

                for unit2, group2 in pairs(currentGroup) do
                    if group2 ~= currentGroup[unit] and nameToID[unit2] and nameToID[unit2] ~= 1 and
                        not setToSwap[unit2] then
                        unitToSwapBridge = unit2
                        break
                    end
                end

                if unitToSwap and unitToSwapBridge then
                    lockedUnit[unit] = true

                    SwapRaidSubgroup(nameToID[unit], nameToID[unitToSwapBridge])
                    SwapRaidSubgroup(nameToID[unitToSwapBridge], nameToID[unitToSwap])
                    SwapRaidSubgroup(nameToID[unit], nameToID[unitToSwapBridge])

                    waitForSwap = true
                    setToSwap[unit] = true
                    setToSwap[unitToSwap] = true
                    setToSwap[unitToSwapBridge] = true
                end
            end
        end
        if waitForSwap then
            return
        end
    end

    self.db.needGroup = nil
    self.db.processTimer = nil
end

function RaidGroups:GeneratePresetString()
    local presetParts = {}
    for group = 1, 8 do
        local names = {}
        for slot = 1, 5 do
            local name = self.groupSlots[group][slot].usedName or ""
            table.insert(names, name)
        end
        table.insert(presetParts, "Group" .. group .. ": " .. table.concat(names, ", "))
    end
    return table.concat(presetParts, "; ")
end

function RaidGroups:ApplyPreset(presetString)
    for group = 1, 8 do
        for slot = 1, 5 do
            local editBox = self.groupSlots[group][slot]
            editBox:SetText("")
            editBox.usedName = nil
        end
    end
    for part in string.gmatch(presetString, "Group%d+:%s*[^;]+") do
        local groupNum, namesStr = part:match("Group(%d+):%s*(.*)")
        groupNum = tonumber(groupNum)
        if groupNum and self.groupSlots[groupNum] then
            local names = {}
            for name in string.gmatch(namesStr, "([^,]+)") do
                local trimmed = name:match("^%s*(.-)%s*$")
                table.insert(names, trimmed)
            end
            for slot = 1, 5 do
                local editBox = self.groupSlots[groupNum][slot]
                local newName = names[slot] or ""
                if newName ~= "" then
                    local color = self.rosterMapping[newName] or GetPlayerClassColorByName(newName)
                    if color then
                        local hexColor = string.format("%02x%02x%02x", color[1] * 255, color[2] * 255, color[3] * 255)
                        editBox:SetText("|cff" .. hexColor .. newName .. "|r")
                        editBox:SetCursorPosition(0)
                    else
                        editBox:SetText(newName)
                        editBox:SetCursorPosition(0)
                    end
                    editBox.usedName = newName
                else
                    editBox:SetText("")
                    editBox.usedName = nil
                end
            end
        end
    end
    self:UpdateNameList(self.currentListType)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" and RaidGroups then
        if RaidGroups.configPanel and RaidGroups.configPanel:IsShown() and RaidGroups.currentListType then
            RaidGroups:UpdateNameList(RaidGroups.currentListType)
        end

        if RaidGroups.db and RaidGroups.db.needGroup then
            if RaidGroups.db.processTimer then
                RaidGroups.db.processTimer:Cancel()
            end
            RaidGroups.db.processTimer = C_Timer.NewTimer(0.6, function()
                RaidGroups.db.processTimer = nil
                RaidGroups:ProcessRoster()
            end)
        end
    end
end)

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(RaidGroups)
end

return RaidGroups
