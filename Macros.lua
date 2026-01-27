local MacrosModule = {}
MacrosModule.title = "Macros"

local listening = false
local keybindPopup = nil

local function GetIconString(texture, size)
    size = size or 16
    return "\124T" .. texture .. ":" .. size .. ":" .. size .. ":0:0:64:64:4:60:4:60\124t"
end

local function get_target_marker_options(dropdown)
    local options = {}
    for i = 1, 8 do
        local iconString = GetIconString("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i)
        table.insert(options, {
            value = i,
            text = iconString,
            onClick = function()
                ACT.db.profile.macros.focusMarker.marker = i
                dropdown.button.text:SetText(iconString)
                if MacrosModule:getMacroKeybind("MACRO ACT FocusMark") ~= "Unbound" then
                    MacrosModule:UpdateFocusMarkerMacro()
                end
            end
        })
    end
    return options
end

local function get_world_marker_options(dropdown)
    local options = {}
    local worldMarkerToIcon = {
        [1] = 6,
        [2] = 4,
        [3] = 3,
        [4] = 7,
        [5] = 1,
        [6] = 2,
        [7] = 5,
        [8] = 8
    }

    for i = 1, 8 do
        local markerID = i
        local iconID = worldMarkerToIcon[i]
        local iconString = GetIconString("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. iconID)
        table.insert(options, {
            value = markerID,
            text = iconString,
            onClick = function()
                ACT.db.profile.macros.worldMarker.marker = markerID
                dropdown.button.text:SetText(iconString)
                if MacrosModule:getMacroKeybind("MACRO ACT WorldMark") ~= "Unbound" then
                    MacrosModule:UpdateWorldMarkerMacro()
                end
            end
        })
    end
    return options
end

local function get_mark_target_options(dropdown)
    local options = {}
    for i = 1, 8 do
        local iconString = GetIconString("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i)
        table.insert(options, {
            value = i,
            text = iconString,
            onClick = function()
                ACT.db.profile.macros.markTarget.marker = i
                dropdown.button.text:SetText(iconString)
                if MacrosModule:getMacroKeybind("MACRO ACT MarkTarget") ~= "Unbound" then
                    MacrosModule:UpdateMarkTargetMacro()
                end
            end
        })
    end
    return options
end

function MacrosModule:DoesMacroExist(macroName)
    for i = 1, 120 do
        local name = C_Macro.GetMacroName(i)
        if not name then
            break
        end
        if name == macroName then
            return true
        end
    end
    return false
end

function MacrosModule:getMacroKeybind(macroName)
    local binding = GetBindingKey(macroName)

    local shortMacroName = macroName:gsub("^MACRO ", "")

    if binding and MacrosModule:DoesMacroExist(shortMacroName) then
        return binding
    else
        return "Unbound"
    end
end

function MacrosModule:bindKeybind(keyCombo, macroName)
    keyCombo = keyCombo:gsub("LeftButton", "BUTTON1"):gsub("RightButton", "BUTTON2"):gsub("MiddleButton", "BUTTON3")
        :gsub("Button4", "BUTTON4"):gsub("Button5", "BUTTON5")

    local existingBinding = GetBindingAction(keyCombo)
    if existingBinding and existingBinding ~= macroName and existingBinding ~= "" then
        SetBinding(keyCombo, nil)
    end

    local existingKeybind = GetBindingKey(macroName)
    if existingKeybind and existingKeybind ~= keyCombo then
        SetBinding(existingKeybind, nil)
    end

    local ok = SetBinding(keyCombo, macroName)
    if ok then
        SaveBindings(GetCurrentBindingSet())

        if macroName == "MACRO ACT FocusMark" then
            MacrosModule:UpdateFocusMarkerMacro()
        elseif macroName == "MACRO ACT WorldMark" then
            MacrosModule:UpdateWorldMarkerMacro()
        elseif macroName == "MACRO ACT MarkTarget" then
            MacrosModule:UpdateMarkTargetMacro()
        elseif macroName == "MACRO ACT FocusTarget" then
            MacrosModule:UpdateFocusTargetMacro()
        elseif macroName == "MACRO ACT Innervate" then
            MacrosModule:UpdateInnervateMacro()
        elseif macroName == "MACRO ACT PowerInfusion" then
            MacrosModule:UpdatePowerInfusionMacro()
        end

        return true
    else
        return false
    end
end

function MacrosModule:clearKeybinding(btn, _, macroName)
    local currentBinding = MacrosModule:getMacroKeybind(macroName)
    if currentBinding ~= "Unbound" then
        SetBinding(currentBinding, nil)
        SaveBindings(GetCurrentBindingSet())
    end

    MacrosModule:UpdateAllKeyBindsUI()
end

function MacrosModule:registerKeybinding(btn, macroName, keybindName)
    if listening then
        return
    end
    listening = true

    if not keybindPopup then
        keybindPopup = UI:CreateTextPopup("Keybinding", "", "Cancel", nil, nil, nil, nil)
        if not keybindPopup then
            listening = false
            return
        end

        keybindPopup:SetSize(300, 150)
        keybindPopup:EnableKeyboard(true)
        keybindPopup:SetPropagateKeyboardInput(false)

        keybindPopup:SetScript("OnKeyDown", function(self, key)
            if not listening then
                return
            end

            if key == "ESCAPE" then
                listening = false
                self:Hide()
                return
            end

            key = key:gsub("^LCTRL$", "CTRL"):gsub("^RCTRL$", "CTRL"):gsub("^LSHIFT$", "SHIFT")
                :gsub("^RSHIFT$", "SHIFT"):gsub("^LALT$", "ALT"):gsub("^RALT$", "ALT")

            if key == "CTRL" or key == "SHIFT" or key == "ALT" then
                return nil
            end
            local keyCombo = (function()
                local modifier = ""
                if IsControlKeyDown() then
                    modifier = modifier .. "CTRL-"
                end
                if IsShiftKeyDown() then
                    modifier = modifier .. "SHIFT-"
                end
                if IsAltKeyDown() then
                    modifier = modifier .. "ALT-"
                end
                return modifier .. key
            end)()

            if keyCombo == "LeftButton" or keyCombo == "RightButton" then
                return nil
            end

            local success = MacrosModule:bindKeybind(keyCombo, self.macroName)

            listening = false
            self:Hide()

            if success then
                MacrosModule:UpdateAllKeyBindsUI()
            end
        end)

        keybindPopup:SetScript("OnMouseDown", function(self, key)
            self:GetScript("OnKeyDown")(self, key)
        end)

        keybindPopup:SetScript("OnHide", function()
            listening = false
        end)
    end

    keybindPopup.titleLabel:SetText("Keybinding: " .. keybindName)
    keybindPopup.messageLabel:SetText("\nPress any key to bind...\n(Escape to cancel)")

    keybindPopup.cancelButton:Hide()
    keybindPopup.acceptButton:SetText("Cancel")
    keybindPopup.acceptButton:SetScript("OnClick", function()
        listening = false
        keybindPopup:Hide()
    end)

    keybindPopup.buttonToUpdate = btn
    keybindPopup.macroName = macroName

    keybindPopup:ClearAllPoints()
    keybindPopup:SetPoint("CENTER", UIParent, "CENTER")
    keybindPopup:Show()
end

function MacrosModule:UpdateMacro(macroName, icon, macroText)
    if C_AddOns.IsAddOnLoaded("MegaMacro") then
        print("|cFF00FFFFACT_Macros:|r MegaMacro is loaded. This won't work for you, figure it out yourself.")
        return
    end

    local macroFound = false
    local macroIndex = nil
    local macroCount = 0

    for i = 1, 120 do
        local name = C_Macro.GetMacroName(i)
        if not name then
            break
        end
        macroCount = i
        if name == macroName then
            macroFound = true
            macroIndex = i
            break
        end
    end

    if macroFound then
        EditMacro(macroIndex, macroName, icon, macroText, false)
    else
        if macroCount >= 120 then
        else
            CreateMacro(macroName, icon, macroText, false)
        end
    end
end

function MacrosModule:UpdateFocusMarkerMacro()
    if not ACT or not ACT.db or not ACT.db.profile or not ACT.db.profile.macros then return end
    local settings = ACT.db.profile.macros.focusMarker

    local target = "[@target]"
    if settings.useMouseover then
        target = "[@mouseover,exists,nodead][]"
    end

    local macroText = "/focus " .. target .. "\n/tm [@focus] " .. settings.marker
    local icon = 136062
    MacrosModule:UpdateMacro("ACT FocusMark", icon, macroText)
end

function MacrosModule:UpdateWorldMarkerMacro()
    if not ACT or not ACT.db or not ACT.db.profile or not ACT.db.profile.macros then return end
    local settings = ACT.db.profile.macros.worldMarker

    local cursorTarget = ""
    if settings.useCursor then
        cursorTarget = "[@cursor] "
    end

    local macroText = "/cwm " .. settings.marker .. "\n/wm " .. cursorTarget .. settings.marker
    local icon = 134400
    MacrosModule:UpdateMacro("ACT WorldMark", icon, macroText)
end

function MacrosModule:UpdateMarkTargetMacro()
    if not ACT or not ACT.db or not ACT.db.profile or not ACT.db.profile.macros then return end
    local settings = ACT.db.profile.macros.markTarget

    local target = "[@target] "
    if settings.useMouseover then
        target = "[@mouseover,exists,nodead][] "
    end

    local macroText = "/tm " .. target .. settings.marker
    local icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. settings.marker
    MacrosModule:UpdateMacro("ACT MarkTarget", icon, macroText)
end

function MacrosModule:UpdateFocusTargetMacro()
    if not ACT or not ACT.db or not ACT.db.profile or not ACT.db.profile.macros then return end
    local settings = ACT.db.profile.macros.focusTarget

    local target = "[@target]"
    if settings.useMouseover then
        target = "[@mouseover,exists,nodead][]"
    end

    local macroText = "/focus " .. target
    local icon = 136062
    MacrosModule:UpdateMacro("ACT FocusTarget", icon, macroText)
end

function MacrosModule:UpdateInnervateMacro()
    if not ACT or not ACT.db or not ACT.db.profile or not ACT.db.profile.macros then return end
    local settings = ACT.db.profile.macros.innervate

    local target = ""
    if settings.useMouseover then
        target = "[@mouseover,help,nodead][]"
    elseif settings.targetName and settings.targetName ~= "" then
        target = "[@" .. settings.targetName .. "]"
    end

    local macroText = "#showtooltip Innervate\n/cast " .. target .. " Innervate"
    MacrosModule:UpdateMacro("ACT Innervate", 136048, macroText)
end

function MacrosModule:UpdatePowerInfusionMacro()
    if not ACT or not ACT.db or not ACT.db.profile or not ACT.db.profile.macros then return end
    local settings = ACT.db.profile.macros.powerInfusion

    local target = ""
    if settings.useMouseover then
        target = "[@mouseover,help,nodead][]"
    elseif settings.targetName and settings.targetName ~= "" then
        target = "[@" .. settings.targetName .. "]"
    end

    local macroText = "#showtooltip Power Infusion\n"
    if settings.useTrinket1 then
        macroText = macroText .. "/use 13\n"
    end
    if settings.useTrinket2 then
        macroText = macroText .. "/use 14\n"
    end
    macroText = macroText .. "/cast " .. target .. " Power Infusion"
    
    MacrosModule:UpdateMacro("ACT PowerInfusion", 135939, macroText)
end

function MacrosModule:GetConfigSize()
    return 800, 600
end

local function SetDropdownIcon(dropdown, options, selectedValue)
    for _, opt in ipairs(options) do
        if opt.value == selectedValue then
            dropdown.button.text:SetText(opt.text)
            return
        end
    end
    if options and options[1] then
        dropdown.button.text:SetText(options[1].text)
    end
end

function MacrosModule:UpdateAllKeyBindsUI()
    if not self.configPanel then
        return
    end

    if self.configPanel.focusMacroKeybind then
        self.configPanel.focusMacroKeybind.text:SetText(MacrosModule:getMacroKeybind("MACRO ACT FocusMark"))
    end
    if self.configPanel.worldMarkerKeybind then
        self.configPanel.worldMarkerKeybind.text:SetText(MacrosModule:getMacroKeybind("MACRO ACT WorldMark"))
    end
    if self.configPanel.markTargetKeybind then
        self.configPanel.markTargetKeybind.text:SetText(MacrosModule:getMacroKeybind("MACRO ACT MarkTarget"))
    end
    if self.configPanel.focusTargetKeybind then
        self.configPanel.focusTargetKeybind.text:SetText(MacrosModule:getMacroKeybind("MACRO ACT FocusTarget"))
    end
    if self.configPanel.innervateKeybind then
        self.configPanel.innervateKeybind.text:SetText(MacrosModule:getMacroKeybind("MACRO ACT Innervate"))
    end
    if self.configPanel.powerInfusionKeybind then
        self.configPanel.powerInfusionKeybind.text:SetText(MacrosModule:getMacroKeybind("MACRO ACT PowerInfusion"))
    end
end

function MacrosModule:UpdateDropdownDefaults()
    if not self.configPanel then
        return
    end

    if not MacrosModule:DoesMacroExist("ACT FocusMark") then
        ACT.db.profile.macros.focusMarker.marker = 1
    end
    SetDropdownIcon(self.configPanel.focusMacroDropdown, self.configPanel.focusMarkerOptions,
        ACT.db.profile.macros.focusMarker.marker)

    if not MacrosModule:DoesMacroExist("ACT WorldMark") then
        ACT.db.profile.macros.worldMarker.marker = 1
    end
    SetDropdownIcon(self.configPanel.worldMarkerDropdown, self.configPanel.worldMarkerOptions,
        ACT.db.profile.macros.worldMarker.marker)

    if not MacrosModule:DoesMacroExist("ACT MarkTarget") then
        ACT.db.profile.macros.markTarget.marker = 1
    end
    SetDropdownIcon(self.configPanel.markTargetDropdown, self.configPanel.markTargetOptions,
        ACT.db.profile.macros.markTarget.marker)
end

function MacrosModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        self:UpdateAllKeyBindsUI()
        self:UpdateDropdownDefaults()
        return
    end

    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetAllPoints()
    self.configPanel = configPanel

    local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    title:SetText("Macros")

    local focusMacroLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    focusMacroLabel:SetPoint("TOPLEFT", 20, -50)
    focusMacroLabel:SetText("Set Focus + Target Marker")

    self.configPanel.focusMacroDropdown = UI:CreateDropdown(configPanel, 50, 20)
    self.configPanel.focusMacroDropdown:SetPoint("TOPLEFT", focusMacroLabel, "BOTTOMLEFT", 0, -10)
    self.configPanel.focusMarkerOptions = get_target_marker_options(self.configPanel.focusMacroDropdown)
    UI:SetDropdownOptions(self.configPanel.focusMacroDropdown, self.configPanel.focusMarkerOptions)

    local focusMouseoverCheck = CreateFrame("CheckButton", "ACTFocusMarkerMouseoverCheck", configPanel, "UICheckButtonTemplate")
    focusMouseoverCheck:SetPoint("LEFT", self.configPanel.focusMacroDropdown, "RIGHT", 10, 0)
    ACTFocusMarkerMouseoverCheckText:SetText("Use Mouseover?")
    focusMouseoverCheck:SetChecked(ACT.db.profile.macros.focusMarker.useMouseover)
    focusMouseoverCheck:SetScript("OnClick", function(self)
        ACT.db.profile.macros.focusMarker.useMouseover = self:GetChecked()
        if MacrosModule:getMacroKeybind("MACRO ACT FocusMark") ~= "Unbound" then
            MacrosModule:UpdateFocusMarkerMacro()
        end
    end)

    local focusMacroKeybindLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    focusMacroKeybindLabel:SetPoint("TOPLEFT", self.configPanel.focusMacroDropdown, "BOTTOMLEFT", 0, -10)
    focusMacroKeybindLabel:SetText("Set Keybind:")

    self.configPanel.focusMacroKeybind = UI:CreateButton(configPanel, "Loading...", 120, 20)
    self.configPanel.focusMacroKeybind:SetPoint("LEFT", focusMacroKeybindLabel, "RIGHT", 10, 0)
    self.configPanel.focusMacroKeybind:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            MacrosModule:clearKeybinding(self, nil, "MACRO ACT FocusMark")
        else
            MacrosModule:registerKeybinding(self, "MACRO ACT FocusMark", "Focus & Mark")
        end
    end)

    local worldMarkerLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    worldMarkerLabel:SetPoint("TOPLEFT", focusMacroLabel, "TOPLEFT", 300, 0)
    worldMarkerLabel:SetText("Place + Clear World Marker")

    self.configPanel.worldMarkerDropdown = UI:CreateDropdown(configPanel, 50, 20)
    self.configPanel.worldMarkerDropdown:SetPoint("TOPLEFT", worldMarkerLabel, "BOTTOMLEFT", 0, -10)
    self.configPanel.worldMarkerOptions = get_world_marker_options(self.configPanel.worldMarkerDropdown)
    UI:SetDropdownOptions(self.configPanel.worldMarkerDropdown, self.configPanel.worldMarkerOptions)

    local worldCursorCheck = CreateFrame("CheckButton", "ACTWorldMarkerCursorCheck", configPanel, "UICheckButtonTemplate")
    worldCursorCheck:SetPoint("LEFT", self.configPanel.worldMarkerDropdown, "RIGHT", 10, 0)
    ACTWorldMarkerCursorCheckText:SetText("Use Cursor?")
    worldCursorCheck:SetChecked(ACT.db.profile.macros.worldMarker.useCursor)
    worldCursorCheck:SetScript("OnClick", function(self)
        ACT.db.profile.macros.worldMarker.useCursor = self:GetChecked()
        if MacrosModule:getMacroKeybind("MACRO ACT WorldMark") ~= "Unbound" then
            MacrosModule:UpdateWorldMarkerMacro()
        end
    end)

    local worldMarkerKeybindLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    worldMarkerKeybindLabel:SetPoint("TOPLEFT", self.configPanel.worldMarkerDropdown, "BOTTOMLEFT", 0, -10)
    worldMarkerKeybindLabel:SetText("Set Keybind:")

    self.configPanel.worldMarkerKeybind = UI:CreateButton(configPanel, "Loading...", 120, 20)
    self.configPanel.worldMarkerKeybind:SetPoint("LEFT", worldMarkerKeybindLabel, "RIGHT", 10, 0)
    self.configPanel.worldMarkerKeybind:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            MacrosModule:clearKeybinding(self, nil, "MACRO ACT WorldMark")
        else
            MacrosModule:registerKeybinding(self, "MACRO ACT WorldMark", "World Marker")
        end
    end)

    local markTargetLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    markTargetLabel:SetPoint("TOPLEFT", focusMacroLabel, "TOPLEFT", 0, -130)
    markTargetLabel:SetText("Mark Target")

    self.configPanel.markTargetDropdown = UI:CreateDropdown(configPanel, 50, 20)
    self.configPanel.markTargetDropdown:SetPoint("TOPLEFT", markTargetLabel, "BOTTOMLEFT", 0, -10)
    self.configPanel.markTargetOptions = get_mark_target_options(self.configPanel.markTargetDropdown)
    UI:SetDropdownOptions(self.configPanel.markTargetDropdown, self.configPanel.markTargetOptions)

    local markTargetMouseoverCheck = CreateFrame("CheckButton", "ACTMarkTargetMouseoverCheck", configPanel, "UICheckButtonTemplate")
    markTargetMouseoverCheck:SetPoint("LEFT", self.configPanel.markTargetDropdown, "RIGHT", 10, 0)
    ACTMarkTargetMouseoverCheckText:SetText("Use Mouseover?")
    markTargetMouseoverCheck:SetChecked(ACT.db.profile.macros.markTarget.useMouseover)
    markTargetMouseoverCheck:SetScript("OnClick", function(self)
        ACT.db.profile.macros.markTarget.useMouseover = self:GetChecked()
        if MacrosModule:getMacroKeybind("MACRO ACT MarkTarget") ~= "Unbound" then
            MacrosModule:UpdateMarkTargetMacro()
        end
    end)

    local markTargetKeybindLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    markTargetKeybindLabel:SetPoint("TOPLEFT", self.configPanel.markTargetDropdown, "BOTTOMLEFT", 0, -10)
    markTargetKeybindLabel:SetText("Set Keybind:")

    self.configPanel.markTargetKeybind = UI:CreateButton(configPanel, "Loading...", 120, 20)
    self.configPanel.markTargetKeybind:SetPoint("LEFT", markTargetKeybindLabel, "RIGHT", 10, 0)
    self.configPanel.markTargetKeybind:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            MacrosModule:clearKeybinding(self, nil, "MACRO ACT MarkTarget")
        else
            MacrosModule:registerKeybinding(self, "MACRO ACT MarkTarget", "Mark Target")
        end
    end)

    local focusTargetLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    focusTargetLabel:SetPoint("TOPLEFT", worldMarkerLabel, "TOPLEFT", 0, -130)
    focusTargetLabel:SetText("Set Focus Target")

    local focusTargetMouseoverCheck = CreateFrame("CheckButton", "ACTFocusTargetMouseoverCheck", configPanel, "UICheckButtonTemplate")
    focusTargetMouseoverCheck:SetPoint("TOPLEFT", focusTargetLabel, "BOTTOMLEFT", -7, -7)
    ACTFocusTargetMouseoverCheckText:SetText("Use Mouseover?")
    focusTargetMouseoverCheck:SetChecked(ACT.db.profile.macros.focusTarget.useMouseover)
    focusTargetMouseoverCheck:SetScript("OnClick", function(self)
        ACT.db.profile.macros.focusTarget.useMouseover = self:GetChecked()
        if MacrosModule:getMacroKeybind("MACRO ACT FocusTarget") ~= "Unbound" then
            MacrosModule:UpdateFocusTargetMacro()
        end
    end)

    local focusTargetKeybindLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    focusTargetKeybindLabel:SetPoint("TOPLEFT", focusTargetLabel, "BOTTOMLEFT", 0, -40)
    focusTargetKeybindLabel:SetText("Set Keybind:")

    self.configPanel.focusTargetKeybind = UI:CreateButton(configPanel, "Loading...", 120, 20)
    self.configPanel.focusTargetKeybind:SetPoint("LEFT", focusTargetKeybindLabel, "RIGHT", 10, 0)
    self.configPanel.focusTargetKeybind:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            MacrosModule:clearKeybinding(self, nil, "MACRO ACT FocusTarget")
        else
            MacrosModule:registerKeybinding(self, "MACRO ACT FocusTarget", "Focus Target")
        end
    end)

    local innervateLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    innervateLabel:SetPoint("TOPLEFT", markTargetLabel, "TOPLEFT", 0, -130)
    innervateLabel:SetText("Cast Innervate")

    local innervateFrame, innervateBox = UI:CreateMultilineEditBox(configPanel, 120, 30, ACT.db.profile.macros.innervate.targetName, nil)
    innervateFrame:SetPoint("TOPLEFT", innervateLabel, "BOTTOMLEFT", 0, -10)
    
    innervateBox:SetScript("OnTextChanged", function(self)
        ACT.db.profile.macros.innervate.targetName = self:GetText()
        if MacrosModule:getMacroKeybind("MACRO ACT Innervate") ~= "Unbound" then
            MacrosModule:UpdateInnervateMacro()
        end
    end)
    
    local innervateMouseoverCheck = CreateFrame("CheckButton", "ACTInnervateMouseoverCheck", configPanel, "UICheckButtonTemplate")
    innervateMouseoverCheck:SetPoint("LEFT", innervateFrame, "RIGHT", 10, 0)
    ACTInnervateMouseoverCheckText:SetText("Use Mouseover?")
    innervateMouseoverCheck:SetChecked(ACT.db.profile.macros.innervate.useMouseover)
    innervateMouseoverCheck:SetScript("OnClick", function(self)
        ACT.db.profile.macros.innervate.useMouseover = self:GetChecked()
        if MacrosModule:getMacroKeybind("MACRO ACT Innervate") ~= "Unbound" then
            MacrosModule:UpdateInnervateMacro()
        end
    end)

    local innervateKeybindLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    innervateKeybindLabel:SetPoint("TOPLEFT", innervateFrame, "BOTTOMLEFT", 0, -10)
    innervateKeybindLabel:SetText("Set Keybind:")

    self.configPanel.innervateKeybind = UI:CreateButton(configPanel, "Loading...", 120, 20)
    self.configPanel.innervateKeybind:SetPoint("LEFT", innervateKeybindLabel, "RIGHT", 10, 0)
    self.configPanel.innervateKeybind:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            MacrosModule:clearKeybinding(self, nil, "MACRO ACT Innervate")
        else
            MacrosModule:registerKeybinding(self, "MACRO ACT Innervate", "Innervate")
        end
    end)

    local piLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    piLabel:SetPoint("TOPLEFT", focusTargetLabel, "TOPLEFT", 0, -130)
    piLabel:SetText("Cast Power Infusion")

    local piFrame, piBox = UI:CreateMultilineEditBox(configPanel, 120, 30, ACT.db.profile.macros.powerInfusion.targetName, nil)
    piFrame:SetPoint("TOPLEFT", piLabel, "BOTTOMLEFT", 0, -10)

    piBox:SetScript("OnTextChanged", function(self)
        ACT.db.profile.macros.powerInfusion.targetName = self:GetText()
        if MacrosModule:getMacroKeybind("MACRO ACT PowerInfusion") ~= "Unbound" then
            MacrosModule:UpdatePowerInfusionMacro()
        end
    end)

    local piMouseoverCheck = CreateFrame("CheckButton", "ACTPIMouseoverCheck", configPanel, "UICheckButtonTemplate")
    piMouseoverCheck:SetPoint("LEFT", piFrame, "RIGHT", 10, 0)
    ACTPIMouseoverCheckText:SetText("Use Mouseover?")
    piMouseoverCheck:SetChecked(ACT.db.profile.macros.powerInfusion.useMouseover)
    piMouseoverCheck:SetScript("OnClick", function(self)
        ACT.db.profile.macros.powerInfusion.useMouseover = self:GetChecked()
        if MacrosModule:getMacroKeybind("MACRO ACT PowerInfusion") ~= "Unbound" then
            MacrosModule:UpdatePowerInfusionMacro()
        end
    end)

    local piTrinket1Check = CreateFrame("CheckButton", "ACTPITrinket1Check", configPanel, "UICheckButtonTemplate")
    piTrinket1Check:SetPoint("TOPLEFT", piFrame, "BOTTOMLEFT", -7, -5)
    ACTPITrinket1CheckText:SetText("Trinket 1")
    piTrinket1Check:SetChecked(ACT.db.profile.macros.powerInfusion.useTrinket1)
    piTrinket1Check:SetScript("OnClick", function(self)
        ACT.db.profile.macros.powerInfusion.useTrinket1 = self:GetChecked()
        if MacrosModule:getMacroKeybind("MACRO ACT PowerInfusion") ~= "Unbound" then
            MacrosModule:UpdatePowerInfusionMacro()
        end
    end)

    local piTrinket2Check = CreateFrame("CheckButton", "ACTPITrinket2Check", configPanel, "UICheckButtonTemplate")
    piTrinket2Check:SetPoint("LEFT", piTrinket1Check, "RIGHT", 70, 0)
    ACTPITrinket2CheckText:SetText("Trinket 2")
    piTrinket2Check:SetChecked(ACT.db.profile.macros.powerInfusion.useTrinket2)
    piTrinket2Check:SetScript("OnClick", function(self)
        ACT.db.profile.macros.powerInfusion.useTrinket2 = self:GetChecked()
        if MacrosModule:getMacroKeybind("MACRO ACT PowerInfusion") ~= "Unbound" then
            MacrosModule:UpdatePowerInfusionMacro()
        end
    end)

    local piKeybindLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    piKeybindLabel:SetPoint("TOPLEFT", piTrinket1Check, "BOTTOMLEFT", 7, -5)
    piKeybindLabel:SetText("Set Keybind:")

    self.configPanel.powerInfusionKeybind = UI:CreateButton(configPanel, "Loading...", 120, 20)
    self.configPanel.powerInfusionKeybind:SetPoint("LEFT", piKeybindLabel, "RIGHT", 10, 0)
    self.configPanel.powerInfusionKeybind:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            MacrosModule:clearKeybinding(self, nil, "MACRO ACT PowerInfusion")
        else
            MacrosModule:registerKeybinding(self, "MACRO ACT PowerInfusion", "Power Infusion")
        end
    end)

    self:UpdateAllKeyBindsUI()
    self:UpdateDropdownDefaults()

    return configPanel
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(MacrosModule)
end