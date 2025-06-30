local AceComm = LibStub("AceComm-3.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")
local SHARE_PREFIX = "ACT_ASSIGNMENT"

AssignmentModule = {}
AssignmentModule.rosterLoaded = false
AssignmentModule.title = "Assignments"
AssignmentModule.GetAssignmentState = nil

AssignmentModule.bossFrameCache = {}
AssignmentModule.activeBossFrame = nil
AssignmentModule.nameFramePool = {}

local DragContainer = CreateFrame("Frame", "Assignment_DragContainer", UIParent)
DragContainer:SetAllPoints(UIParent)
DragContainer:SetFrameStrata("HIGH")
DragContainer:SetFrameLevel(400)

function AssignmentModule:RegisterGetStateFunction(func)
    AssignmentModule.GetAssignmentState = func
end

VACT = VACT or {}
VACT.BossPresets = VACT.BossPresets or {}

function AssignmentModule:GetDisplayName(name)
    if not name then
        return ""
    end
    local trimmed = name:match("^%s*(.-)%s*$")
    local baseName = trimmed:match("^(.-)%-")
    return baseName or trimmed
end

function AssignmentModule:StripActiveRoster()
    if not self.activeRoster then
        return
    end
    for i, entry in ipairs(self.activeRoster) do
        if type(entry) == "table" and entry.name then
            entry.name = self:GetDisplayName(entry.name)
        elseif type(entry) == "string" then
            self.activeRoster[i] = self:GetDisplayName(entry)
        end
    end
end

AssignmentModule.raids = AssignmentData or {}
AssignmentModule.activeRoster = {}
AssignmentModule.selectedRaid = nil
AssignmentModule.selectedBoss = nil
AssignmentModule.selectedPresetIndex = nil
AssignmentModule.nameFrames = {}
AssignmentModule.currentSlots = nil

local function GetClassColor(classToken)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    if colors and classToken and colors[classToken] then
        local c = colors[classToken]
        return {c.r, c.g, c.b, 1}
    end
    return {1, 1, 1, 1}
end

function GetPlayerClassColorByName(playerName)
    local currentRealm = GetRealmName()
    for _, entry in ipairs(AssignmentModule.activeRoster or {}) do
        if type(entry) == "table" and entry.name and entry.class then
            if AssignmentModule:GetDisplayName(entry.name):lower() ==
                AssignmentModule:GetDisplayName(playerName):lower() then
                return GetClassColor(entry.class)
            end
        end
    end
    local numGuild = GetNumGuildMembers() or 0
    for i = 1, numGuild do
        local fullName, _, _, _, _, _, _, _, _, _, classToken = GetGuildRosterInfo(i)
        if fullName then
            local filteredName = AssignmentModule:GetDisplayName(fullName)
            if AssignmentModule:GetDisplayName(playerName):lower() == filteredName:lower() then
                return GetClassColor(classToken)
            end
        end
    end
    return {1, 1, 1, 1}
end

local function IsCursorInFrame(frame, margin)
    margin = margin or 10
    local cx, cy = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    cx = cx / scale
    cy = cy / scale
    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    return cx >= left - margin and cx <= right + margin and cy <= top + margin and cy >= bottom - margin
end

local function IsCursorInEditBox(editBox, marginY, marginX)
    marginY = marginY or 8
    marginX = marginX or 15
    local cx, cy = GetCursorPosition()
    local scale = editBox:GetEffectiveScale()
    cx = cx / scale
    cy = cy / scale
    local left, right = editBox:GetLeft(), editBox:GetRight()
    local top, bottom = editBox:GetTop(), editBox:GetBottom()
    return cx >= left - marginX and cx <= right + marginX and cy <= top + marginY and cy >= bottom - marginY
end

function AssignmentModule:CreateDraggableNameFrame(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
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
    frame.originalParent = parent
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if ClearAllEditFocus then
                ClearAllEditFocus()
            end
            self:SetParent(DragContainer)
            self:SetFrameLevel(400)
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self:StopMovingOrSizing()
            local dropped = false
            if AssignmentModule.currentSlots then
                for _, group in ipairs(AssignmentModule.currentSlots) do
                    for _, editBox in ipairs(group) do
                        if editBox and editBox:IsVisible() and IsCursorInEditBox(editBox) then
                            local name = AssignmentModule:GetDisplayName(self.playerName) or ""
                            local r, g, b = unpack(self.classColor or {1, 1, 1, 1})
                            local hexColor = string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
                            editBox:SetText("|cff" .. hexColor .. name .. "|r")
                            editBox.usedName = name
                            self:Hide()
                            dropped = true
                            break
                        end
                    end
                    if dropped then
                        break
                    end
                end
            end
            if not dropped then
                self:SetParent(self.originalParent)
                self:ClearAllPoints()
                self:SetPoint(self.originalPoint, self.originalParent, self.originalRelPoint, self.originalX,
                    self.originalY)
                self:Show()
            end
            AssignmentModule:UpdateRosterList()
        end
    end)
    return frame
end

function AssignmentModule:LoadBossUI(bossID)
    if self.activeBossFrame then
        self.activeBossFrame:Hide()
    end
    self.activeBossFrame = nil

    self.GetAssignmentState = nil
    self.selectedBoss = bossID

    if not bossID then
        if self.bossFrame then
            self.bossFrame:Hide()
        end
        self.currentSlots = nil
        self:UpdateRosterList()
        return
    end

    if not self.bossFrame then
        return
    end
    self.bossFrame:Show()

    local bossUI = self.bossFrameCache[bossID]
    local isNew = not bossUI

    if isNew then
        if AssignmentBossUI and AssignmentBossUI[bossID] then
            bossUI = AssignmentBossUI[bossID](self.bossFrame, self.activeRoster)
            if bossUI then
                self.bossFrameCache[bossID] = bossUI
            end
        end
    end

    if not bossUI then
        self.currentSlots = nil
        self:UpdateRosterList()
        return
    end

    self.currentSlots = bossUI.bossSlots or {}

    bossUI:Show()
    self.activeBossFrame = bossUI

    if isNew then
        for _, group in ipairs(self.currentSlots) do
            for _, editBox in ipairs(group) do
                editBox:SetScript("OnEditFocusLost", function(self)
                    local plain = self:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                    plain = plain:match("^%s*(.-)%s*$") or ""
                    if plain == "" then
                        self.usedName = nil
                    else
                        local filtered = AssignmentModule:GetDisplayName(plain)
                        local color = GetPlayerClassColorByName(filtered)
                        local r, g, b = color[1], color[2], color[3]
                        local hexColor = string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
                        self:SetText("|cff" .. hexColor .. filtered .. "|r")
                        self:SetCursorPosition(0)
                        self.usedName = filtered
                    end
                    AssignmentModule:UpdateRosterList()
                end)
                editBox:EnableMouse(true)
                editBox:RegisterForDrag("LeftButton")
                editBox:SetScript("OnDragStart", function(self)
                    local function createDragFrame()
                        if self.usedName and self.usedName ~= "" then
                            local dragFrame = CreateFrame("Frame", nil, DragContainer, "BackdropTemplate")
                            dragFrame:SetSize(self:GetWidth(), self:GetHeight())
                            dragFrame:SetFrameStrata("TOOLTIP")
                            dragFrame:SetBackdrop({
                                bgFile = "Interface\\Buttons\\WHITE8x8",
                                edgeFile = "Interface\\Buttons\\WHITE8x8",
                                edgeSize = 1
                            })
                            dragFrame.text = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                            dragFrame.text:SetPoint("CENTER")
                            dragFrame.text:SetText(self.usedName)
                            dragFrame:SetScript("OnUpdate", function(frame)
                                local cx, cy = GetCursorPosition()
                                frame:ClearAllPoints()
                                frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / UIParent:GetEffectiveScale(),
                                    cy / UIParent:GetEffectiveScale())
                            end)
                            self.dragFrame = dragFrame
                        end
                    end
                    if self:HasFocus() then
                        self:ClearFocus()
                        C_Timer.After(0.01, createDragFrame)
                    else
                        createDragFrame()
                    end
                end)
                editBox:SetScript("OnDragStop", function(self)
                    if self.dragFrame then
                        self.dragFrame:Hide()
                        local dropTarget
                        for _, tGroup in ipairs(AssignmentModule.currentSlots or {}) do
                            for _, target in ipairs(tGroup) do
                                if target and IsCursorInEditBox(target, 8, 15) then
                                    dropTarget = target
                                    break
                                end
                            end
                            if dropTarget then
                                break
                            end
                        end
                        local sourceText = AssignmentModule:GetDisplayName(self.usedName or "")
                        if dropTarget and dropTarget ~= self then
                            local targetText = AssignmentModule:GetDisplayName(dropTarget.usedName or "")
                            if targetText and targetText ~= "" then
                                local sourceColor = GetPlayerClassColorByName(sourceText)
                                local targetColor = GetPlayerClassColorByName(targetText)
                                self:SetText(string.format("|cff%02x%02x%02x%s|r", targetColor[1] * 255,
                                    targetColor[2] * 255, targetColor[3] * 255, targetText))
                                self.usedName = targetText
                                dropTarget:SetText(string.format("|cff%02x%02x%02x%s|r", sourceColor[1] * 255,
                                    sourceColor[2] * 255, sourceColor[3] * 255, sourceText))
                                dropTarget.usedName = sourceText
                            else
                                local sourceColor = GetPlayerClassColorByName(sourceText)
                                dropTarget:SetText(string.format("|cff%02x%02x%02x%s|r", sourceColor[1] * 255,
                                    sourceColor[2] * 255, sourceColor[3] * 255, sourceText))
                                dropTarget.usedName = sourceText
                                self:SetText("")
                                self.usedName = nil
                            end
                        elseif IsCursorInFrame(AssignmentModule.nameListContent) then
                            self:SetText("")
                            self.usedName = nil
                        end
                        self.dragFrame = nil
                        AssignmentModule:UpdateRosterList()
                    end
                end)
            end
        end
    end
    self:UpdateRosterList()
end

function AssignmentModule:UpdateRosterList()
    if not self.nameListContent then
        return
    end

    for _, frame in ipairs(self.nameFrames) do
        frame:Hide()
        table.insert(self.nameFramePool, frame)
    end
    self.nameFrames = {}

    local allowDuplicates = self.allowDuplicates
    local used = {}
    if self.currentSlots and not allowDuplicates then
        for _, group in ipairs(self.currentSlots) do
            for _, slot in ipairs(group) do
                if slot.usedName then
                    used[slot.usedName] = true
                end
            end
        end
    end

    local names = self.activeRoster or {}
    local yOffset = -2
    for _, entry in ipairs(names) do
        local playerName = (type(entry) == "table") and entry.name or entry
        if playerName and (allowDuplicates or not used[playerName]) then
            local frame = table.remove(self.nameFramePool)
            local color = (type(entry) == "table" and entry.class) and GetClassColor(entry.class) or
                              GetPlayerClassColorByName(playerName)

            if not frame then
                frame = self:CreateDraggableNameFrame(self.nameListContent)
            end

            frame:SetParent(self.nameListContent)
            frame.playerName = playerName
            frame.classColor = color or {1, 1, 1, 1}
            frame.nameText:SetText(self:GetDisplayName(playerName))
            frame.nameText:SetTextColor(unpack(color or {1, 1, 1, 1}))

            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", 0, yOffset)
            frame.originalPoint, frame.originalRelPoint, frame.originalX, frame.originalY = "TOPLEFT", "TOPLEFT", 0,
                yOffset
            frame:Show()

            table.insert(self.nameFrames, frame)
            yOffset = yOffset - 22
        end
    end

    local contentHeight = #self.nameFrames * 22 + 15
    self.nameListContent:SetHeight(math.max(420, contentHeight))

    if self.rosterScroll then
        self.rosterScroll:SetVerticalScroll(0)
    end
end

function AssignmentModule:GetConfigSize()
    return 1200, 600
end

function AssignmentModule:ShareAssignment()
    if not self.selectedBoss then
        print("Please select a boss first.")
        return
    end

    if not self.GetAssignmentState then
        print("Boss does not support assignment sharing.")
        return
    end

    local assignmentState = self:GetAssignmentState()
    if not assignmentState then
        print("Cannot share an empty assignment.")
        return
    end

    local payload = {
        bossID = self.selectedBoss,
        state = assignmentState
    }

    local serialized = LibSerialize:Serialize(payload)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)

    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
    if channel then
        AceComm:SendCommMessage(SHARE_PREFIX, encoded, channel)
        print("Assignment shared.")
    else
        print("You must be in a party or raid to share assignments.")
    end
end

AceComm:RegisterComm(SHARE_PREFIX, function(prefix, message, distribution, sender)
    if sender == UnitName("player") then
        return
    end

    local decoded = LibDeflate:DecodeForWoWAddonChannel(message)
    if not decoded then
        return
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return
    end

    local success, payload = LibSerialize:Deserialize(decompressed)
    if not success or type(payload) ~= "table" or not payload.bossID or not payload.state then
        return
    end

    local bossID = payload.bossID
    local assignmentState = payload.state

    local bossName
    for _, raid in ipairs(AssignmentData) do
        for _, boss in ipairs(raid.bosses) do
            if boss.id == bossID then
                bossName = boss.name
                break
            end
        end
        if bossName then
            break
        end
    end

    if not bossName then
        return
    end

    local displayName = NicknameAPI:GetNicknameByCharacter(sender) or sender

    local popup = UI:CreateTextPopup("Incoming Assignment",
        string.format(
        "%s is sharing an assignment for %s.\nDo you want to import it?", displayName, bossName), "Import", "Cancel",
        function()
            VACT.BossPresets = VACT.BossPresets or {}
            VACT.BossPresets[bossID] = VACT.BossPresets[bossID] or {}

            local baseName = bossName .. " Import"
            local presetName = baseName
            local i = 1
            while true do
                local nameExists = false
                for _, preset in ipairs(VACT.BossPresets[bossID]) do
                    if preset.name == presetName then
                        nameExists = true
                        break
                    end
                end
                if not nameExists then
                    break
                end
                i = i + 1
                presetName = string.format("%s (%d)", baseName, i)
            end

            table.insert(VACT.BossPresets[bossID], {
                name = presetName,
                data = assignmentState.data,
                dropdowns = assignmentState.dropdowns
            })

            local updateFunc = _G["Update" .. bossID .. "PresetDropdown"]
            if type(updateFunc) == "function" then
                updateFunc()
            end

            print(string.format("Assignment for %s imported as preset '%s'.", bossName, presetName))
        end, function()
        end)
    popup:Show()
end)

function AssignmentModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:Show()
        return self.configPanel
    end
    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetAllPoints(parent)
    self.configPanel = configPanel
    local titleLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", 20, 16)
    titleLabel:SetText("Assignments")
    local raidDropdown = UI:CreateDropdown(configPanel, 180, 30)
    raidDropdown:SetPoint("TOPLEFT", 20, -40)
    raidDropdown.button.text:SetText("Select Raid")
    self.raidDropdown = raidDropdown
    local bossDropdown = UI:CreateDropdown(configPanel, 180, 30)
    bossDropdown:SetPoint("LEFT", raidDropdown, "RIGHT", 20, 0)
    bossDropdown.button.text:SetText("Select Boss")
    self.bossDropdown = bossDropdown
    local presetsDropdown = UI:CreateDropdown(configPanel, 200, 30)
    presetsDropdown:SetPoint("LEFT", bossDropdown, "RIGHT", 20, 0)
    presetsDropdown.button.text:SetText("Roster Preset")
    self.presetsDropdown = presetsDropdown
    local grabButton = UI:CreateButton(configPanel, "Grab Current Roster", 140, 30)
    grabButton:SetPoint("LEFT", presetsDropdown, "RIGHT", 20, 0)
    grabButton:SetScript("OnClick", function()
        self.selectedPresetIndex = nil
        self.presetsDropdown.button.text:SetText("Roster Preset")
        local rosterList = {}
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                local name, _, _, _, _, class = GetRaidRosterInfo(i)
                if name then
                    table.insert(rosterList, {
                        name = name,
                        class = class
                    })
                end
            end
        end
        self.activeRoster = rosterList
        self:StripActiveRoster()
        self.rosterLoaded = true
        self:UpdateRosterList()
    end)
    local clearButton = UI:CreateButton(configPanel, "Clear Roster", 140, 30)
    clearButton:SetPoint("BOTTOMLEFT", grabButton, "TOPLEFT", 0, 10)
    clearButton:SetScript("OnClick", function()
        self.selectedPresetIndex = nil
        if self.presetsDropdown then
            self.presetsDropdown.button.text:SetText("Roster Preset")
        end
        self.activeRoster = {}
        self.rosterLoaded = false
        self:UpdateRosterList()
    end)
    local shareButton = UI:CreateButton(configPanel, "Share Assignments", 120, 30)
    shareButton:SetPoint("LEFT", clearButton, "RIGHT", 20, 0)
    shareButton:SetScript("OnClick", function()
        self:ShareAssignment()
    end)
    local applyButton = UI:CreateButton(configPanel, "Apply Roster", 120, 30)
    applyButton:SetPoint("LEFT", grabButton, "RIGHT", 20, 0)
    applyButton:SetScript("OnClick", function()
        if not self.selectedPresetIndex then
            return
        end
        local preset = self.Presets[self.selectedPresetIndex]
        if preset and preset.data then
            local rosterList = {}
            for part in string.gmatch(preset.data, "Group%d+:%s*([^;]+)") do
                for name in string.gmatch(part, "([^,]+)") do
                    local trimmed = name:match("^%s*(.-)%s*$")
                    if trimmed and trimmed ~= "" then
                        table.insert(rosterList, trimmed)
                    end
                end
            end
            self.activeRoster = rosterList
            self:StripActiveRoster()
            self.rosterLoaded = true
            self:UpdateRosterList()
        end
    end)
    local rosterFrame = CreateFrame("Frame", nil, configPanel)
    rosterFrame:SetSize(220, 460)
    rosterFrame:SetPoint("TOPLEFT", 20, -80)
    local listScroll = CreateFrame("ScrollFrame", "AssignmentRosterScroll", rosterFrame, "UIPanelScrollFrameTemplate")
    listScroll:SetSize(210, 420)
    listScroll:SetPoint("TOPLEFT", 0, 0)
    self.rosterScroll = listScroll
    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(210, 420)
    listScroll:SetScrollChild(listContent)
    self.nameListContent = listContent
    local bossFrame = CreateFrame("Frame", nil, configPanel)
    bossFrame:SetSize(840, 500)
    bossFrame:SetPoint("TOPLEFT", rosterFrame, "TOPRIGHT", 40, 0)
    self.bossFrame = bossFrame
    self.bossFrame:Hide()
    local raidOptions = {}
    for i, raid in ipairs(self.raids) do
        table.insert(raidOptions, {
            text = raid.name,
            value = i,
            onClick = function()
                self.selectedRaid = i
                raidDropdown.button.text:SetText(raid.name)
                local bossOptions = {}
                for _, boss in ipairs(raid.bosses or {}) do
                    table.insert(bossOptions, {
                        text = boss.name,
                        value = boss.id,
                        onClick = function()
                            bossDropdown.button.text:SetText(boss.name)
                            self:LoadBossUI(boss.id)
                        end
                    })
                end
                UI:SetDropdownOptions(bossDropdown, bossOptions)
                bossDropdown.button.text:SetText("Select Boss")
                self:LoadBossUI(nil)
            end
        })
    end
    UI:SetDropdownOptions(raidDropdown, raidOptions)
    self.Presets = VACT.RaidGroupsPresets or {}
    function self:UpdatePresetsDropdown()
        local options = {}
        for idx, preset in ipairs(self.Presets or {}) do
            table.insert(options, {
                text = preset.name,
                value = idx,
                onClick = function()
                    self.selectedPresetIndex = idx
                    presetsDropdown.button.text:SetText(preset.name)
                end
            })
        end
        UI:SetDropdownOptions(presetsDropdown, options)
    end
    self:UpdatePresetsDropdown()
    self:UpdateRosterList()
    return configPanel
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(AssignmentModule)
end
