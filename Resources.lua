local PRDModule = {}

PRDModule.title = "Personal Resource Display"

local defaults = {
    enabled = false,
    powerWidth = 200,
    powerHeight = 20,
    showPower = true,
    showResourceText = false,
    texture = "",
    textureName = "Blizzard",
    frameStrata = "BACKGROUND",
    showPowerBorder = true,
    powerBorderColor = {0, 0, 0, 1}
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

function PRDModule:GetConfigSize()
    return 800, 600
end

function PRDModule:ApplySettings()
    if not InCombatLockdown() then
        local settings = ACT.db.profile.prd
        
        if settings.enabled then
            if PersonalResourceDisplayFrame then
                PersonalResourceDisplayFrame:SetFrameStrata(settings.frameStrata or "BACKGROUND")
                
                if PersonalResourceDisplayFrame.HealthBarsContainer then
                    PersonalResourceDisplayFrame.HealthBarsContainer:Hide()
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
                
                if settings.showResourceText then
                    if PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain 
                       and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea 
                       and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar 
                       and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar.ManaBarText then
                        local manaText = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar.ManaBarText
                        manaText:ClearAllPoints()
                        manaText:SetPoint("CENTER", PersonalResourceDisplayFrame.PowerBar, "CENTER", 0, 0)
                    end
                else
                    if PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain 
                       and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea 
                       and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar 
                       and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar.ManaBarText then
                        local manaText = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar.ManaBarText
                        manaText:ClearAllPoints()
                        manaText:SetPoint("CENTER", PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar, "CENTER", 0, 0)
                    end
                end
            end
        else
            if PersonalResourceDisplayFrame then
                PersonalResourceDisplayFrame:SetFrameStrata("MEDIUM")
                if PersonalResourceDisplayFrame.HealthBarsContainer then
                    PersonalResourceDisplayFrame.HealthBarsContainer:Show()
                    local currentWidth = PersonalResourceDisplayFrame.HealthBarsContainer:GetWidth()
                    PersonalResourceDisplayFrame.HealthBarsContainer:SetSize(currentWidth, 30)
                end
                if PersonalResourceDisplayFrame.PowerBar then
                    PersonalResourceDisplayFrame.PowerBar:Show()
                    PersonalResourceDisplayFrame.PowerBar:SetSize(200, 20)
                    
                    if PersonalResourceDisplayFrame.PowerBar.customBorders then
                        for _, border in pairs(PersonalResourceDisplayFrame.PowerBar.customBorders) do
                            border:Hide()
                        end
                    end
                    
                    if PersonalResourceDisplayFrame.PowerBar.BorderLeft then PersonalResourceDisplayFrame.PowerBar.BorderLeft:Show() end
                    if PersonalResourceDisplayFrame.PowerBar.BorderRight then PersonalResourceDisplayFrame.PowerBar.BorderRight:Show() end
                    if PersonalResourceDisplayFrame.PowerBar.BorderTop then PersonalResourceDisplayFrame.PowerBar.BorderTop:Show() end
                    if PersonalResourceDisplayFrame.PowerBar.BorderBottom then PersonalResourceDisplayFrame.PowerBar.BorderBottom:Show() end
                    if PersonalResourceDisplayFrame.PowerBar.Border then PersonalResourceDisplayFrame.PowerBar.Border:Show() end
                end
                
                if PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain then
                    if PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea 
                       and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar 
                       and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar.ManaBarText then
                        local manaText = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar.ManaBarText
                        manaText:ClearAllPoints()
                        manaText:SetPoint("CENTER", PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar, "CENTER", 0, 0)
                    end
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

    if not ACT.db.profile.prd then
        ACT.db.profile.prd = {}
    end
    
    for k, v in pairs(defaults) do
        if ACT.db.profile.prd[k] == nil then
            ACT.db.profile.prd[k] = v
        end
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
        ACT.db.profile.prd.enabled = self:GetChecked()
        PRDModule:ApplySettings()
    end)

    yOffset = yOffset - 50

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
    resourceTextCheckbox:SetPoint("LEFT", powerLabel, "RIGHT", 30, 0)
    resourceTextCheckbox:SetSize(24, 24)
    resourceTextCheckbox:SetChecked(ACT.db.profile.prd.showResourceText)
    
    local resourceTextLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resourceTextLabel:SetPoint("LEFT", resourceTextCheckbox, "RIGHT", 5, 0)
    resourceTextLabel:SetText("Show Power Text")
    
    resourceTextCheckbox:SetScript("OnClick", function(self)
        ACT.db.profile.prd.showResourceText = self:GetChecked()
        PRDModule:ApplySettings()
    end)

    yOffset = yOffset - 40

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

    yOffset = yOffset - 43

    local warningText = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warningText:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    warningText:SetText("|cffff0000Note:|r Changes are applied immediately (out of combat only)")
    warningText:SetJustifyH("LEFT")
    
    yOffset = yOffset - 20
    
    local textNote = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textNote:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    textNote:SetText("|cffffff00Tip:|r Set Status Text to 'Numeric Value' in Interface > Display options")
    textNote:SetJustifyH("LEFT")

    self.configPanel = configPanel
    
    PRDModule:ApplySettings()
    
    return configPanel
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(PRDModule)
    
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1, function()
                PRDModule:ApplySettings()
            end)
        end
    end)
end