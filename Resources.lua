local PRDModule = {}

PRDModule.title = "Personal Resource Display"

local defaults = {
    enabled = false,
    powerWidth = 200,
    powerHeight = 20,
    showPower = true,
    showResourceText = false,
    showPowerAsPercent = false,
    texture = "",
    textureName = "Blizzard",
    frameStrata = "BACKGROUND",
    showPowerBorder = true,
    powerBorderColor = {0, 0, 0, 1},
    fontSize = 12,
    fontFace = "Friz Quadrata TT",
    classFramePosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0
    },
    showClassFrame = true
}

local function GetAvailableTextures()
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if not LSM then
        return {}
    end
    
    local textures = {}
    local textureList = LSM:List("statusbar")
    
    for _, textureName in ipairs(textureList) do
        table.insert(textures, {
            text = textureName,
            value = textureName
        })
    end
    
    return textures
end

local function GetAvailableFonts()
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if not LSM then
        return {{text = "Friz Quadrata TT", value = "Friz Quadrata TT"}}
    end
    
    local fonts = {}
    local fontList = LSM:List("font")
    
    for _, fontName in ipairs(fontList) do
        table.insert(fonts, {
            text = fontName,
            value = fontName
        })
    end
    
    return fonts
end

local function CreatePowerBarBorder(powerBar)
    if powerBar.customBorders then
        return
    end
    
    if powerBar.BorderLeft then powerBar.BorderLeft:Hide() end
    if powerBar.BorderRight then powerBar.BorderRight:Hide() end
    if powerBar.BorderTop then powerBar.BorderTop:Hide() end
    if powerBar.BorderBottom then powerBar.BorderBottom:Hide() end
    if powerBar.Border then powerBar.Border:Hide() end
    
    powerBar.customBorders = {}
    
    local top = powerBar:CreateTexture(nil, "OVERLAY")
    top:SetColorTexture(0, 0, 0, 1)
    top:SetPoint("TOPLEFT", powerBar, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", powerBar, "TOPRIGHT", 0, 0)
    top:SetHeight(1)
    powerBar.customBorders.top = top
    
    local bottom = powerBar:CreateTexture(nil, "OVERLAY")
    bottom:SetColorTexture(0, 0, 0, 1)
    bottom:SetPoint("BOTTOMLEFT", powerBar, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", powerBar, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)
    powerBar.customBorders.bottom = bottom
    
    local left = powerBar:CreateTexture(nil, "OVERLAY")
    left:SetColorTexture(0, 0, 0, 1)
    left:SetPoint("TOPLEFT", powerBar, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", powerBar, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)
    powerBar.customBorders.left = left
    
    local right = powerBar:CreateTexture(nil, "OVERLAY")
    right:SetColorTexture(0, 0, 0, 1)
    right:SetPoint("TOPRIGHT", powerBar, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", powerBar, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)
    powerBar.customBorders.right = right
end

local function UpdatePowerBarBorder(powerBar, settings)
    if not powerBar.customBorders then
        return
    end
    
    local color = settings.powerBorderColor or {0, 0, 0, 1}
    
    if settings.showPowerBorder then
        for _, border in pairs(powerBar.customBorders) do
            border:SetColorTexture(color[1], color[2], color[3], color[4])
            border:Show()
        end
    else
        for _, border in pairs(powerBar.customBorders) do
            border:Hide()
        end
    end
end

local function CreatePowerText(powerBar, settings)
    local fontFace = settings.fontFace or "Friz Quadrata TT"
    local fontSize = settings.fontSize or 12
    local fontPath = nil
        
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        local success, result = pcall(function() return LSM:Fetch("font", fontFace) end)
        if success and result and type(result) == "string" then
            fontPath = result
        end
    end
    
    if not fontPath then
        fontPath = "Fonts\\FRIZQT__.TTF"
    end
    
    if powerBar.customPowerText then
        local currentFont = powerBar.customPowerText:GetFont()
        
        if currentFont ~= fontPath then
            powerBar.customPowerText:Hide()
            powerBar.customPowerText:SetText("")
            powerBar.customPowerText = nil
        else
            powerBar.customPowerText:SetFont(fontPath, fontSize, "OUTLINE")
            return powerBar.customPowerText
        end
    end
    
    local powerText = powerBar:CreateFontString(nil, "OVERLAY")
    powerText:SetPoint("CENTER", powerBar, "CENTER", 0, 0)
    powerText:SetFont(fontPath, fontSize, "OUTLINE")
    
    powerBar.customPowerText = powerText
    
    return powerText
end

local function UpdatePowerText(powerBar)
    if not powerBar.customPowerText then
        return
    end

    local settings = ACT.db.profile.prd
    local powerType = UnitPowerType("player")
    local max = UnitPowerMax("player", powerType)
    
    if max > 0 then
        if settings.showPowerAsPercent then
            local percent = UnitPowerPercent("player", powerType, false, true)
            powerBar.customPowerText:SetText(string.format("%.0f%%", percent))
        else
            local current = UnitPower("player", powerType)
            powerBar.customPowerText:SetText(string.format("%d / %d", current, max))
        end
    else
        powerBar.customPowerText:SetText("")
    end
end

local function SetupHealthBarHook()
    if PersonalResourceDisplayFrame and PersonalResourceDisplayFrame.HealthBarsContainer then
        if not PersonalResourceDisplayFrame.HealthBarsContainer.hooked then
            hooksecurefunc(PersonalResourceDisplayFrame.HealthBarsContainer, "Show", function(self)
                local settings = ACT.db.profile.prd
                if settings.enabled then
                    self:Hide()
                end
            end)
            PersonalResourceDisplayFrame.HealthBarsContainer.hooked = true
        end
    end
end

local function OnClassFramePositionChanged(frame, layoutName, point, x, y)
    local settings = ACT.db.profile.prd
    settings.classFramePosition = settings.classFramePosition or {}
    settings.classFramePosition.point = point
    settings.classFramePosition.x = x
    settings.classFramePosition.y = y
    
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, x, y)
end

local function ApplyClassFramePosition()
    if not prdClassFrame then
        return
    end
    
    local settings = ACT.db.profile.prd
    local position = settings.classFramePosition or defaults.classFramePosition
    
    if position.point and position.x and position.y then
        prdClassFrame:ClearAllPoints()
        prdClassFrame:SetPoint(position.point, UIParent, position.point, position.x, position.y)
    else
        prdClassFrame:ClearAllPoints()
        prdClassFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function SetupClassFrame()
    if not prdClassFrame then
        return
    end
    
    prdClassFrame:SetParent(UIParent)
    prdClassFrame:Show()
    
    ApplyClassFramePosition()
    
    if LibStub and LibStub("LibEditMode", true) then
        local LibEditMode = LibStub("LibEditMode")
        
        if not prdClassFrame.editModeRegistered then
            local point, _, relativePoint, x, y = prdClassFrame:GetPoint()
            local defaultPosition = {
                point = point or "CENTER",
                x = x or 0,
                y = y or 0
            }
            
            LibEditMode:AddFrame(
                prdClassFrame, 
                OnClassFramePositionChanged, 
                defaultPosition
            )
            
            prdClassFrame.editModeName = "Class Resource Frame"
            prdClassFrame.editModeRegistered = true
        end
    end
    
    if not prdClassFrame.hooked then
        hooksecurefunc(prdClassFrame, "Hide", function(self)
            local settings = ACT.db.profile.prd
            if settings.enabled and settings.showClassFrame and not self:IsShown() then
                self:Show()
            end
        end)
        prdClassFrame.hooked = true
    end
end

function PRDModule:GetConfigSize()
    return 800, 600
end

function PRDModule:ApplySettings()
    if not ACT.db.profile.prd then
        ACT.db.profile.prd = {}
    end
    for k, v in pairs(defaults) do
        if ACT.db.profile.prd[k] == nil then
            if type(v) == "table" then
                ACT.db.profile.prd[k] = CopyTable(v)
            else
                ACT.db.profile.prd[k] = v
            end
        end
    end

    if not InCombatLockdown() then
        local settings = ACT.db.profile.prd
        
        if settings.enabled then
            if PersonalResourceDisplayFrame then
                PersonalResourceDisplayFrame:SetFrameStrata(settings.frameStrata or "BACKGROUND")
                
                if PersonalResourceDisplayFrame.HealthBarsContainer then
                    PersonalResourceDisplayFrame.HealthBarsContainer:Hide()
                    SetupHealthBarHook()
                end
                
                if prdClassFrame then
                    if settings.showClassFrame then
                        SetupClassFrame()
                    else
                        prdClassFrame:Hide()
                        if LibStub then
                            local LibEditMode = LibStub("LibEditMode", true)
                            if LibEditMode and LibEditMode.RemoveFrame and prdClassFrame.editModeRegistered then
                                LibEditMode:RemoveFrame(prdClassFrame)
                                prdClassFrame.editModeRegistered = false
                            end
                        end
                    end
                end
                
                if PersonalResourceDisplayFrame.PowerBar then
                    if settings.showPower then
                        PersonalResourceDisplayFrame.PowerBar:Show()
                        if settings.powerWidth and settings.powerHeight then
                            PersonalResourceDisplayFrame.PowerBar:SetSize(settings.powerWidth, settings.powerHeight)
                        end
                        
                        CreatePowerBarBorder(PersonalResourceDisplayFrame.PowerBar)
                        UpdatePowerBarBorder(PersonalResourceDisplayFrame.PowerBar, settings)
                    else
                        PersonalResourceDisplayFrame.PowerBar:Hide()
                    end
                end
                
                if settings.textureName and settings.textureName ~= "" then
                    local LSM = LibStub("LibSharedMedia-3.0", true)
                    if LSM then
                        local texturePath = LSM:Fetch("statusbar", settings.textureName)
                        if texturePath then
                            if PersonalResourceDisplayFrame.PowerBar and PersonalResourceDisplayFrame.PowerBar.Texture then
                                PersonalResourceDisplayFrame.PowerBar.Texture:SetTexture(texturePath)
                            end
                            
                            if PersonalResourceDisplayFrame.HealthBarsContainer and PersonalResourceDisplayFrame.HealthBarsContainer.healthBar and PersonalResourceDisplayFrame.HealthBarsContainer.healthBar.barTexture then
                                PersonalResourceDisplayFrame.HealthBarsContainer.healthBar.barTexture:SetTexture(texturePath)
                            end
                        end
                    end
                end
                
                if settings.showResourceText and PersonalResourceDisplayFrame.PowerBar then
                    CreatePowerText(PersonalResourceDisplayFrame.PowerBar, settings)
                    UpdatePowerText(PersonalResourceDisplayFrame.PowerBar)
                    if PersonalResourceDisplayFrame.PowerBar.customPowerText then
                        PersonalResourceDisplayFrame.PowerBar.customPowerText:Show()
                    end
                else
                    if PersonalResourceDisplayFrame.PowerBar and PersonalResourceDisplayFrame.PowerBar.customPowerText then
                        PersonalResourceDisplayFrame.PowerBar.customPowerText:Hide()
                    end
                end
            end
        else
            if PersonalResourceDisplayFrame then
                PersonalResourceDisplayFrame:SetFrameStrata("MEDIUM")
                
                if PersonalResourceDisplayFrame.HealthBarsContainer then
                    PersonalResourceDisplayFrame.HealthBarsContainer:Show()
                end
                
                if prdClassFrame then
                    prdClassFrame:Show()
                    if LibStub then
                        local LibEditMode = LibStub("LibEditMode", true)
                        if LibEditMode and LibEditMode.RemoveFrame and prdClassFrame.editModeRegistered then
                            LibEditMode:RemoveFrame(prdClassFrame)
                            prdClassFrame.editModeRegistered = false
                        end
                    end
                end
                
                if PersonalResourceDisplayFrame.PowerBar then
                    PersonalResourceDisplayFrame.PowerBar:Show()
                    PersonalResourceDisplayFrame.PowerBar:SetSize(200, 20) 
                    
                    if PersonalResourceDisplayFrame.PowerBar.customBorders then
                        for _, border in pairs(PersonalResourceDisplayFrame.PowerBar.customBorders) do
                            border:Hide()
                        end
                    end
                    
                    if PersonalResourceDisplayFrame.PowerBar.customPowerText then
                        PersonalResourceDisplayFrame.PowerBar.customPowerText:Hide()
                    end
                    
                    if PersonalResourceDisplayFrame.PowerBar.BorderLeft then PersonalResourceDisplayFrame.PowerBar.BorderLeft:Show() end
                    if PersonalResourceDisplayFrame.PowerBar.BorderRight then PersonalResourceDisplayFrame.PowerBar.BorderRight:Show() end
                    if PersonalResourceDisplayFrame.PowerBar.BorderTop then PersonalResourceDisplayFrame.PowerBar.BorderTop:Show() end
                    if PersonalResourceDisplayFrame.PowerBar.BorderBottom then PersonalResourceDisplayFrame.PowerBar.BorderBottom:Show() end
                    if PersonalResourceDisplayFrame.PowerBar.Border then PersonalResourceDisplayFrame.PowerBar.Border:Show() end
                end

                if PersonalResourceDisplayFrame.PowerBar and PersonalResourceDisplayFrame.PowerBar.Texture then
                    PersonalResourceDisplayFrame.PowerBar.Texture:SetTexture(nil)
                end
                
                if PersonalResourceDisplayFrame.HealthBarsContainer and PersonalResourceDisplayFrame.HealthBarsContainer.healthBar and PersonalResourceDisplayFrame.HealthBarsContainer.healthBar.barTexture then
                    PersonalResourceDisplayFrame.HealthBarsContainer.healthBar.barTexture:SetTexture(nil)
                end
            end
        end
    end
end

function PRDModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        return
    end

    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetAllPoints()

    local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    title:SetText("Personal Resource Display")

    local yOffset = -20

    local enableCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    enableCheckbox:SetSize(24, 24)
    enableCheckbox:SetChecked(ACT.db.profile.prd.enabled)
    
    local enableLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableLabel:SetPoint("LEFT", enableCheckbox, "RIGHT", 5, 0)
    enableLabel:SetText("Enable PRD Modifications")
    
    enableCheckbox:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()

        if isChecked then
            ACT.db.profile.prd.enabled = true
            PRDModule:ApplySettings()
        else
            
            local function onAcceptReload()
                ACT.db.profile.prd.enabled = false
                PRDModule:ApplySettings()
                if PRDModule.reloadPopup then
                    PRDModule.reloadPopup:Hide()
                end
                ReloadUI()
            end
            
            local function onCancelReload()
                ACT.db.profile.prd.enabled = false
                PRDModule:ApplySettings()
                if PRDModule.reloadPopup then
                    PRDModule.reloadPopup:Hide()
                end
            end
            
            PRDModule.reloadPopup = UI:CreateTextPopup(
                "Reload Required",
                "Disabling this module requires a UI reload to fully restore Blizzard defaults. Reload now?",
                "Reload Now",
                "Later",
                onAcceptReload,
                onCancelReload,
                PRDModule.reloadPopup
            )
            
            PRDModule.reloadPopup:Show()
            
            self:SetChecked(true)
        end
    end)

    yOffset = yOffset - 40

    local powerHeader = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    powerHeader:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    powerHeader:SetText("|cff00ccffPower Bar|r")

    yOffset = yOffset - 30

    local powerCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    powerCheckbox:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    powerCheckbox:SetSize(24, 24)
    powerCheckbox:SetChecked(ACT.db.profile.prd.showPower)
    
    local powerLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    powerLabel:SetPoint("LEFT", powerCheckbox, "RIGHT", 5, 0)
    powerLabel:SetText("Show Power Bar")
    
    powerCheckbox:SetScript("OnClick", function(self)
        ACT.db.profile.prd.showPower = self:GetChecked()
        PRDModule:ApplySettings()
    end)

    local resourceTextCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    resourceTextCheckbox:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 250, yOffset)
    resourceTextCheckbox:SetSize(24, 24)
    resourceTextCheckbox:SetChecked(ACT.db.profile.prd.showResourceText)
    
    local resourceTextLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resourceTextLabel:SetPoint("LEFT", resourceTextCheckbox, "RIGHT", 5, 0)
    resourceTextLabel:SetText("Show Power Text")

    local powerPercentCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    powerPercentCheckbox:SetPoint("TOPLEFT", resourceTextLabel, "BOTTOMLEFT", 10, -5)
    powerPercentCheckbox:SetSize(24, 24)
    powerPercentCheckbox:SetChecked(ACT.db.profile.prd.showPowerAsPercent)
    
    local powerPercentLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    powerPercentLabel:SetPoint("LEFT", powerPercentCheckbox, "RIGHT", 5, 0)
    powerPercentLabel:SetText("Show as %")
    
    powerPercentCheckbox:SetEnabled(ACT.db.profile.prd.showResourceText)

    resourceTextCheckbox:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked()
        ACT.db.profile.prd.showResourceText = isChecked
        
        powerPercentCheckbox:SetEnabled(isChecked)
        
        if not isChecked then
            powerPercentCheckbox:SetChecked(false)
            ACT.db.profile.prd.showPowerAsPercent = false
        end
        
        PRDModule:ApplySettings()
    end)
    
    powerPercentCheckbox:SetScript("OnClick", function(self)
        ACT.db.profile.prd.showPowerAsPercent = self:GetChecked()
        PRDModule:ApplySettings()
    end)

    yOffset = yOffset - 20 - 30

    local powerBorderCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    powerBorderCheckbox:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    powerBorderCheckbox:SetSize(24, 24)
    powerBorderCheckbox:SetChecked(ACT.db.profile.prd.showPowerBorder)
    
    local powerBorderLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    powerBorderLabel:SetPoint("LEFT", powerBorderCheckbox, "RIGHT", 5, 0)
    powerBorderLabel:SetText("Show Power Bar Border")
    
    powerBorderCheckbox:SetScript("OnClick", function(self)
        ACT.db.profile.prd.showPowerBorder = self:GetChecked()
        PRDModule:ApplySettings()
    end)

    local classFrameCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    classFrameCheckbox:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 250, yOffset)
    classFrameCheckbox:SetSize(24, 24)
    classFrameCheckbox:SetChecked(ACT.db.profile.prd.showClassFrame)
    
    local classFrameLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classFrameLabel:SetPoint("LEFT", classFrameCheckbox, "RIGHT", 5, 0)
    classFrameLabel:SetText("Show Class Resources")
    
    classFrameCheckbox:SetScript("OnClick", function(self)
        ACT.db.profile.prd.showClassFrame = self:GetChecked()
        PRDModule:ApplySettings()
    end)

    yOffset = yOffset - 40

    local powerWidthLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    powerWidthLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    powerWidthLabel:SetText("Power Width: " .. ACT.db.profile.prd.powerWidth)

    local powerWidthSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    powerWidthSlider:SetPoint("TOPLEFT", powerWidthLabel, "BOTTOMLEFT", 0, -10)
    powerWidthSlider:SetMinMaxValues(50, 500)
    powerWidthSlider:SetValue(ACT.db.profile.prd.powerWidth)
    powerWidthSlider:SetValueStep(1)
    powerWidthSlider:SetObeyStepOnDrag(true)
    powerWidthSlider:SetWidth(300)
    
    powerWidthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        ACT.db.profile.prd.powerWidth = value
        powerWidthLabel:SetText("Power Width: " .. value)
        PRDModule:ApplySettings()
    end)

    yOffset = yOffset - 60

    local powerHeightLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    powerHeightLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    powerHeightLabel:SetText("Power Height: " .. ACT.db.profile.prd.powerHeight)

    local powerHeightSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    powerHeightSlider:SetPoint("TOPLEFT", powerHeightLabel, "BOTTOMLEFT", 0, -10)
    powerHeightSlider:SetMinMaxValues(10, 100)
    powerHeightSlider:SetValue(ACT.db.profile.prd.powerHeight)
    powerHeightSlider:SetValueStep(1)
    powerHeightSlider:SetObeyStepOnDrag(true)
    powerHeightSlider:SetWidth(300)
    
    powerHeightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        ACT.db.profile.prd.powerHeight = value
        powerHeightLabel:SetText("Power Height: " .. value)
        PRDModule:ApplySettings()
    end)

    yOffset = yOffset - 70

    local textureLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textureLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    textureLabel:SetText("Texture:")

    yOffset = yOffset - 30

    local textureDropdown = UI:CreateDropdown(configPanel, 300, 30)
    textureDropdown:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    
    local availableTextures = GetAvailableTextures()
    
    local dropdownOptions = {}
    for _, textureInfo in ipairs(availableTextures) do
        table.insert(dropdownOptions, {
            text = textureInfo.text,
            value = textureInfo.value,
            onClick = function()
                ACT.db.profile.prd.textureName = textureInfo.value
                PRDModule:ApplySettings()
            end
        })
    end
    
    UI:SetDropdownOptions(textureDropdown, dropdownOptions)
    
    local currentTextureName = ACT.db.profile.prd.textureName or "Blizzard"
    textureDropdown.button.text:SetText(currentTextureName)
    textureDropdown.selectedValue = currentTextureName

    yOffset = yOffset - 50

    local fontLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    fontLabel:SetText("Font Type:")

    yOffset = yOffset - 30

    local fontDropdown = UI:CreateDropdown(configPanel, 300, 30)
    fontDropdown:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    
    local availableFonts = GetAvailableFonts()
    
    local fontDropdownOptions = {}
    for _, fontInfo in ipairs(availableFonts) do
        table.insert(fontDropdownOptions, {
            text = fontInfo.text,
            value = fontInfo.value,
            onClick = function()
                ACT.db.profile.prd.fontFace = fontInfo.value
                fontDropdown.button.text:SetText(fontInfo.text)
                fontDropdown.selectedValue = fontInfo.value
                PRDModule:ApplySettings()
            end
        })
    end
    
    UI:SetDropdownOptions(fontDropdown, fontDropdownOptions)
    
    local currentFontFace = ACT.db.profile.prd.fontFace or "Friz Quadrata TT"
    fontDropdown.button.text:SetText(currentFontFace)
    fontDropdown.selectedValue = currentFontFace

    yOffset = yOffset - 50

    local fontSizeLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontSizeLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    fontSizeLabel:SetText("Font Size: " .. ACT.db.profile.prd.fontSize)

    local fontSizeSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", fontSizeLabel, "BOTTOMLEFT", 0, -10)
    fontSizeSlider:SetMinMaxValues(8, 32)
    fontSizeSlider:SetValue(ACT.db.profile.prd.fontSize)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider:SetWidth(300)
    
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        ACT.db.profile.prd.fontSize = value
        fontSizeLabel:SetText("Font Size: " .. value)
        PRDModule:ApplySettings()
    end)

    local warningText = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warningText:SetPoint("TOPLEFT", fontSizeSlider, "BOTTOMLEFT", 0, -20)
    warningText:SetText("|cffff0000Note:|r Changes must be applied out of combat")
    warningText:SetJustifyH("LEFT")

    self.configPanel = configPanel
        
    return configPanel
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(PRDModule)
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UNIT_POWER_UPDATE")
    eventFrame:RegisterEvent("UNIT_MAXPOWER")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_LOGIN" then
            if not ACT.db.profile.prd then
                ACT.db.profile.prd = {}
            end
            for k, v in pairs(defaults) do
                if ACT.db.profile.prd[k] == nil then
                    if type(v) == "table" then
                        ACT.db.profile.prd[k] = CopyTable(v)
                    else
                        ACT.db.profile.prd[k] = v
                    end
                end
            end
        end

        if not ACT or not ACT.db or not ACT.db.profile or not ACT.db.profile.prd then
            return
        end
        local settings = ACT.db.profile.prd

        if not settings.enabled then
            return
        end
        
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            PRDModule:ApplySettings()
            
        elseif (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER") then
            local unit = ...
            if unit == "player" then
                if PersonalResourceDisplayFrame and PersonalResourceDisplayFrame.PowerBar then
                    UpdatePowerText(PersonalResourceDisplayFrame.PowerBar)
                end
            end
            
        elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
            if settings.showClassFrame then
                SetupClassFrame()
            end
        end
    end)
end