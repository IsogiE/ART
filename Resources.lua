local PRDModule = {}

PRDModule.title = "Personal Resource Display"

local defaults = {
    enabled = false,
    enableHealer = true,
    enableTank = true,
    enableDPS = true,
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

function PRDModule:ShowReloadPopup()
    if self.reloadPopup then
        self.reloadPopup:Show()
        return
    end

    local function onAccept()
        ReloadUI()
    end

    local function onCancel()
        if self.reloadPopup then self.reloadPopup:Hide() end
    end

    self.reloadPopup = UI:CreateTextPopup(
        "Reload Required",
        "Disabling the PRD for this spec/role requires a UI reload to fully restore Blizzard defaults. Reload now?",
        "Reload Now",
        "Later",
        onAccept,
        onCancel,
        nil
    )
    self.reloadPopup:Show()
end

local function CreateNumBox(parent, width, height, initialValue, onCommit)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetJustifyH("CENTER")
    box:SetTextInsets(5, 5, 5, 5)
    
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    box:SetBackdropColor(0.1, 0.1, 0.1, 1)
    box:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    box:SetText(tostring(initialValue))

    box:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropColor(0.1, 0.1, 0.1, 1)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end)

    box:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            onCommit(val)
            self:ClearFocus()
        else
            self:ClearFocus()
        end
    end)
    
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return box
end

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

local function ShouldEnableForRole()
    local settings = ACT.db.profile.prd
    local specIndex = GetSpecialization()
    
    if not specIndex then return true end
    
    local role = GetSpecializationRole(specIndex)
    
    if role == "HEALER" then
        return settings.enableHealer
    elseif role == "TANK" then
        return settings.enableTank
    elseif role == "DAMAGER" then
        return settings.enableDPS
    end
    
    return true
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
    if not ACT.db.profile.prd.enabled or not ShouldEnableForRole() then
        if powerBar.customPowerText then powerBar.customPowerText:Hide() end
        return
    end

    if not powerBar.customPowerText then
        return
    end

    local settings = ACT.db.profile.prd
    
    local powerType = UnitPowerType("player")
    
    if settings.showPowerAsPercent and UnitPowerPercent and CurveConstants then
        local percent = UnitPowerPercent("player", powerType, false, CurveConstants.ScaleTo100)
        
        if percent then
            powerBar.customPowerText:SetText(string.format("%.0f%%", percent))
            return
        end
    end

    local max = UnitPowerMax("player", powerType)
    local current = UnitPower("player", powerType)
    
    if max and max > 0 then
        if settings.showPowerAsPercent then
            local success, percent = pcall(function() return (current / max) * 100 end)
            if success then
                powerBar.customPowerText:SetText(string.format("%.0f%%", percent))
            else
                powerBar.customPowerText:SetText("")
            end
        else
            powerBar.customPowerText:SetText(string.format("%d", current, max))
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
                if settings.enabled and ShouldEnableForRole() then
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
        
        local isActive = settings.enabled and ShouldEnableForRole()
        
        self.isActive = isActive

        if isActive then
            self.hooksInstalled = true

            if PersonalResourceDisplayFrame then
                PersonalResourceDisplayFrame:SetFrameStrata(settings.frameStrata or "BACKGROUND")
                
                if PersonalResourceDisplayFrame.HealthBarsContainer then
                    PersonalResourceDisplayFrame.HealthBarsContainer:Hide()
                    SetupHealthBarHook()
                end
                
                if prdClassFrame then
                    if not prdClassFrame.visibilityHooksRegistered then
                        hooksecurefunc(prdClassFrame, "Show", function(self)
                            local s = ACT.db.profile.prd
                            if s.enabled and ShouldEnableForRole() and not s.showClassFrame then
                                self:Hide()
                            end
                        end)
                        
                        hooksecurefunc(prdClassFrame, "Hide", function(self)
                            local s = ACT.db.profile.prd
                            if s.enabled and ShouldEnableForRole() and s.showClassFrame and not self:IsShown() then
                                self:Show()
                            end
                        end)
                        
                        prdClassFrame.visibilityHooksRegistered = true
                        prdClassFrame.hooked = true
                    end

                    if settings.showClassFrame then
                        SetupClassFrame()
                    else
                        prdClassFrame:Hide()
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
            if self.hooksInstalled and PersonalResourceDisplayFrame then
                PersonalResourceDisplayFrame:SetFrameStrata("MEDIUM")
                
                if PersonalResourceDisplayFrame.HealthBarsContainer then
                    PersonalResourceDisplayFrame.HealthBarsContainer:Show()
                end
                
                if prdClassFrame then
                    prdClassFrame:Show()
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
            ACT.db.profile.prd.enabled = false
            PRDModule:ApplySettings()
            PRDModule:ShowReloadPopup()
            self:SetChecked(true)
        end
    end)
    
    yOffset = yOffset - 30
    
    local roleLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    roleLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 25, yOffset)
    roleLabel:SetText("Enable for roles:")
    
    yOffset = yOffset - 15

    local function OnRoleCheckClick(self, roleKey)
        local wasActive = ACT.db.profile.prd.enabled and ShouldEnableForRole()
        
        ACT.db.profile.prd[roleKey] = self:GetChecked()
        
        local isActive = ACT.db.profile.prd.enabled and ShouldEnableForRole()
        
        PRDModule:ApplySettings()
        
        if wasActive and not isActive then
            PRDModule:ShowReloadPopup()
        end
    end

    local healCheck = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    healCheck:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 30, yOffset)
    healCheck:SetSize(20, 20)
    healCheck:SetChecked(ACT.db.profile.prd.enableHealer)
    
    local healLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    healLabel:SetPoint("LEFT", healCheck, "RIGHT", 5, 0)
    healLabel:SetText("Healer")
    
    healCheck:SetScript("OnClick", function(self) OnRoleCheckClick(self, "enableHealer") end)

    local tankCheck = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    tankCheck:SetPoint("LEFT", healLabel, "RIGHT", 20, 0)
    tankCheck:SetSize(20, 20)
    tankCheck:SetChecked(ACT.db.profile.prd.enableTank)
    
    local tankLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tankLabel:SetPoint("LEFT", tankCheck, "RIGHT", 5, 0)
    tankLabel:SetText("Tank")
    
    tankCheck:SetScript("OnClick", function(self) OnRoleCheckClick(self, "enableTank") end)

    local dpsCheck = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    dpsCheck:SetPoint("LEFT", tankLabel, "RIGHT", 20, 0)
    dpsCheck:SetSize(20, 20)
    dpsCheck:SetChecked(ACT.db.profile.prd.enableDPS)
    
    local dpsLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dpsLabel:SetPoint("LEFT", dpsCheck, "RIGHT", 5, 0)
    dpsLabel:SetText("DPS")
    
    dpsCheck:SetScript("OnClick", function(self) OnRoleCheckClick(self, "enableDPS") end)

    yOffset = yOffset - 30

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

    local powerWidthSlider, powerWidthInput
    local currentPowerWidth = ACT.db.profile.prd.powerWidth

    local powerWidthLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    powerWidthLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    powerWidthLabel:SetText("Power Width")

    powerWidthInput = CreateNumBox(configPanel, 50, 20, currentPowerWidth, function(val)
        if val < 50 then val = 50 end
        if val > 500 then val = 500 end
        
        ACT.db.profile.prd.powerWidth = val
        powerWidthInput:SetText(val)
        
        if powerWidthSlider then
            powerWidthSlider:SetValue(val)
        end
        PRDModule:ApplySettings()
    end)
    powerWidthInput:SetPoint("LEFT", powerWidthLabel, "RIGHT", 10, 0)

    powerWidthSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    powerWidthSlider:SetPoint("TOPLEFT", powerWidthLabel, "BOTTOMLEFT", 0, -10)
    powerWidthSlider:SetMinMaxValues(50, 500)
    powerWidthSlider:SetValue(currentPowerWidth)
    powerWidthSlider:SetValueStep(1)
    powerWidthSlider:SetObeyStepOnDrag(true)
    powerWidthSlider:SetWidth(300)
    
    powerWidthSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        ACT.db.profile.prd.powerWidth = value
        
        if powerWidthInput and not powerWidthInput:HasFocus() then
            powerWidthInput:SetText(value)
        end
        PRDModule:ApplySettings()
    end)

    yOffset = yOffset - 60

    local powerHeightSlider, powerHeightInput
    local currentPowerHeight = ACT.db.profile.prd.powerHeight

    local powerHeightLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    powerHeightLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    powerHeightLabel:SetText("Power Height")

    powerHeightInput = CreateNumBox(configPanel, 50, 20, currentPowerHeight, function(val)
        if val < 10 then val = 10 end
        if val > 100 then val = 100 end
        
        ACT.db.profile.prd.powerHeight = val
        powerHeightInput:SetText(val)
        
        if powerHeightSlider then
            powerHeightSlider:SetValue(val)
        end
        PRDModule:ApplySettings()
    end)
    powerHeightInput:SetPoint("LEFT", powerHeightLabel, "RIGHT", 10, 0)

    powerHeightSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    powerHeightSlider:SetPoint("TOPLEFT", powerHeightLabel, "BOTTOMLEFT", 0, -10)
    powerHeightSlider:SetMinMaxValues(10, 100)
    powerHeightSlider:SetValue(currentPowerHeight)
    powerHeightSlider:SetValueStep(1)
    powerHeightSlider:SetObeyStepOnDrag(true)
    powerHeightSlider:SetWidth(300)
    
    powerHeightSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        ACT.db.profile.prd.powerHeight = value
        
        if powerHeightInput and not powerHeightInput:HasFocus() then
            powerHeightInput:SetText(value)
        end
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

    yOffset = yOffset - 40

    local fontSizeSlider, fontSizeInput
    local currentFontSize = ACT.db.profile.prd.fontSize

    local fontSizeLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontSizeLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    fontSizeLabel:SetText("Font Size")

    fontSizeInput = CreateNumBox(configPanel, 50, 20, currentFontSize, function(val)
        if val < 8 then val = 8 end
        if val > 32 then val = 32 end
        
        ACT.db.profile.prd.fontSize = val
        fontSizeInput:SetText(val)
        
        if fontSizeSlider then
            fontSizeSlider:SetValue(val)
        end
        PRDModule:ApplySettings()
    end)
    fontSizeInput:SetPoint("LEFT", fontSizeLabel, "RIGHT", 10, 0)

    fontSizeSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    fontSizeSlider:SetPoint("TOPLEFT", fontSizeLabel, "BOTTOMLEFT", 0, -10)
    fontSizeSlider:SetMinMaxValues(8, 32)
    fontSizeSlider:SetValue(currentFontSize)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider:SetWidth(300)
    
    fontSizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        ACT.db.profile.prd.fontSize = value
        
        if fontSizeInput and not fontSizeInput:HasFocus() then
            fontSizeInput:SetText(value)
        end
        PRDModule:ApplySettings()
    end)

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
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    
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

        if event ~= "PLAYER_SPECIALIZATION_CHANGED" then
             if not settings.enabled or not ShouldEnableForRole() then
                 return
             end
        end
        
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            PRDModule:ApplySettings()
            
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            local wasActive = PRDModule.isActive
            
            PRDModule:ApplySettings()
            
            local nowActive = PRDModule.isActive
            
            if wasActive and not nowActive then
                PRDModule:ShowReloadPopup()
            end
            
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