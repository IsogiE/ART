local CircleModule = {}
CircleModule.title = "Character Marker"

local defaults = {
    enabled = false,
    shape = "Circle",
    size = 60,
    alpha = 0.5,
    color = {1, 0, 0, 1},
    posX = 0,
    posY = 0,
    border = false,
    borderWidth = 2,
    borderColor = {0, 0, 0, 1},
}

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

function CircleModule:GetConfigSize()
    return 800, 600
end

function CircleModule:ApplySettings()
    if not ACT.db.profile.circle then
        ACT.db.profile.circle = {}
    end
    for k, v in pairs(defaults) do
        if ACT.db.profile.circle[k] == nil then
            ACT.db.profile.circle[k] = v
        end
    end
    
    local settings = ACT.db.profile.circle

    if not self.circleFrame then
        self.circleFrame = CreateFrame("Frame", "ACT_ScreenCircle", UIParent, "BackdropTemplate")
        self.circleFrame:SetIgnoreParentScale(true)
        self.circleFrame:SetFrameStrata("MEDIUM")
        
        self.circleFrame.texture = self.circleFrame:CreateTexture(nil, "ARTWORK")
        self.circleFrame.texture:SetAllPoints()
        
        self.circleFrame.borderTexture = self.circleFrame:CreateTexture(nil, "BACKGROUND")
    end

    if settings.enabled then
        self.circleFrame:Show()
        self.circleFrame:SetSize(settings.size, settings.size)
        self.circleFrame:SetAlpha(settings.alpha)
        
        self.circleFrame:ClearAllPoints()
        self.circleFrame:SetPoint("CENTER", UIParent, "CENTER", settings.posX, settings.posY)
        
        local r, g, b, _ = unpack(settings.color)
        self.circleFrame.texture:SetVertexColor(r, g, b)

        self.circleFrame:SetBackdrop(nil)

        if settings.border then
            self.circleFrame.borderTexture:Show()
            
            local br, bg, bb, ba = unpack(settings.borderColor or defaults.borderColor)
            local bWidth = settings.borderWidth or 2
            
            self.circleFrame.borderTexture:SetVertexColor(br, bg, bb, ba)
            
            local borderSize = settings.size + (bWidth * 2)
            self.circleFrame.borderTexture:SetSize(borderSize, borderSize)
            
            self.circleFrame.borderTexture:ClearAllPoints()
            self.circleFrame.borderTexture:SetPoint("CENTER", self.circleFrame, "CENTER", 0, 0)
        else
            self.circleFrame.borderTexture:Hide()
        end

        if settings.shape == "Square" then
            self.circleFrame.texture:SetTexture("Interface\\Buttons\\WHITE8x8")
            self.circleFrame.borderTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        else
            local circleTex = "Interface\\AddOns\\ACT\\media\\textures\\Aura72"
            self.circleFrame.texture:SetTexture(circleTex)
            self.circleFrame.borderTexture:SetTexture(circleTex)
        end

    else
        self.circleFrame:Hide()
    end
end

function CircleModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        return self.configPanel
    end

    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetAllPoints()

    local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    title:SetText("Character Marker")

    local yOffset = -20

    local enableCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    enableCheckbox:SetSize(24, 24)
    enableCheckbox:SetChecked(ACT.db.profile.circle and ACT.db.profile.circle.enabled)
    
    local enableLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableLabel:SetPoint("LEFT", enableCheckbox, "RIGHT", 5, 0)
    enableLabel:SetText("Enable Marker")

    enableCheckbox:SetScript("OnClick", function(self)
        ACT.db.profile.circle.enabled = self:GetChecked()
        CircleModule:ApplySettings()
    end)

    yOffset = yOffset - 50

    local sizeSlider, sizeInput 
    local currentSize = ACT.db.profile.circle and ACT.db.profile.circle.size or defaults.size

    local sizeLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    sizeLabel:SetText("Size")

    sizeInput = CreateNumBox(configPanel, 50, 20, currentSize, function(val)
        if val < 10 then val = 10 end
        if val > 300 then val = 300 end
        ACT.db.profile.circle.size = val
        sizeInput:SetText(val)
        if sizeSlider then sizeSlider:SetValue(val) end
        CircleModule:ApplySettings()
    end)
    sizeInput:SetPoint("LEFT", sizeLabel, "RIGHT", 10, 0)

    sizeSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -10)
    sizeSlider:SetMinMaxValues(10, 300)
    sizeSlider:SetValue(currentSize)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetWidth(200)
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        ACT.db.profile.circle.size = val
        if sizeInput and not sizeInput:HasFocus() then sizeInput:SetText(val) end
        CircleModule:ApplySettings()
    end)

    yOffset = yOffset - 60

    local xPosSlider, xPosInput
    local currentX = ACT.db.profile.circle and ACT.db.profile.circle.posX or defaults.posX

    local xPosLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xPosLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    xPosLabel:SetText("X Offset")

    xPosInput = CreateNumBox(configPanel, 60, 20, currentX, function(val)
        if val < -1000 then val = -1000 end
        if val > 1000 then val = 1000 end
        ACT.db.profile.circle.posX = val
        xPosInput:SetText(val)
        if xPosSlider then xPosSlider:SetValue(val) end
        CircleModule:ApplySettings()
    end)
    xPosInput:SetPoint("LEFT", xPosLabel, "RIGHT", 10, 0)

    xPosSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    xPosSlider:SetPoint("TOPLEFT", xPosLabel, "BOTTOMLEFT", 0, -10)
    xPosSlider:SetMinMaxValues(-1000, 1000)
    xPosSlider:SetValue(currentX)
    xPosSlider:SetValueStep(1)
    xPosSlider:SetObeyStepOnDrag(true)
    xPosSlider:SetWidth(200)
    xPosSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        ACT.db.profile.circle.posX = val
        if xPosInput and not xPosInput:HasFocus() then xPosInput:SetText(val) end
        CircleModule:ApplySettings()
    end)

    yOffset = yOffset - 60

    local yPosSlider, yPosInput
    local currentY = ACT.db.profile.circle and ACT.db.profile.circle.posY or defaults.posY

    local yPosLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    yPosLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    yPosLabel:SetText("Y Offset")

    yPosInput = CreateNumBox(configPanel, 60, 20, currentY, function(val)
        if val < -1000 then val = -1000 end
        if val > 1000 then val = 1000 end
        ACT.db.profile.circle.posY = val
        yPosInput:SetText(val)
        if yPosSlider then yPosSlider:SetValue(val) end
        CircleModule:ApplySettings()
    end)
    yPosInput:SetPoint("LEFT", yPosLabel, "RIGHT", 10, 0)

    yPosSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    yPosSlider:SetPoint("TOPLEFT", yPosLabel, "BOTTOMLEFT", 0, -10)
    yPosSlider:SetMinMaxValues(-1000, 1000)
    yPosSlider:SetValue(currentY)
    yPosSlider:SetValueStep(1)
    yPosSlider:SetObeyStepOnDrag(true)
    yPosSlider:SetWidth(200)
    yPosSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        ACT.db.profile.circle.posY = val
        if yPosInput and not yPosInput:HasFocus() then yPosInput:SetText(val) end
        CircleModule:ApplySettings()
    end)

    yOffset = yOffset - 60

    local alphaSlider, alphaInput
    local currentAlpha = ACT.db.profile.circle and ACT.db.profile.circle.alpha or defaults.alpha

    local alphaLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alphaLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    alphaLabel:SetText("Opacity")

    alphaInput = CreateNumBox(configPanel, 50, 20, math.ceil(currentAlpha * 100), function(val)
        if val < 10 then val = 10 end
        if val > 100 then val = 100 end
        local floatVal = val / 100
        ACT.db.profile.circle.alpha = floatVal
        alphaInput:SetText(val)
        if alphaSlider then alphaSlider:SetValue(floatVal) end
        CircleModule:ApplySettings()
    end)
    alphaInput:SetPoint("LEFT", alphaLabel, "RIGHT", 10, 0)

    alphaSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", alphaLabel, "BOTTOMLEFT", 0, -10)
    alphaSlider:SetMinMaxValues(0.1, 1.0)
    alphaSlider:SetValue(currentAlpha)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetWidth(200)
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        ACT.db.profile.circle.alpha = value
        if alphaInput and not alphaInput:HasFocus() then alphaInput:SetText(math.ceil(value * 100)) end
        CircleModule:ApplySettings()
    end)

    yOffset = yOffset - 60

    local colorLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    colorLabel:SetText("Shape Color")

    local colorButton = CreateFrame("Button", nil, configPanel, "BackdropTemplate")
    colorButton:SetSize(40, 24)
    colorButton:SetPoint("LEFT", colorLabel, "RIGHT", 20, 0)
    colorButton:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1})
    colorButton:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local function UpdateButtonColor()
        local c = ACT.db.profile.circle.color or defaults.color
        if c then colorButton:SetBackdropColor(c[1], c[2], c[3], 1) end
    end
    UpdateButtonColor()

    colorButton:SetScript("OnClick", function()
        local c = ACT.db.profile.circle.color or defaults.color
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c[1], g = c[2], b = c[3],
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                ACT.db.profile.circle.color = {r, g, b, 1}
                UpdateButtonColor()
                CircleModule:ApplySettings()
            end,
            cancelFunc = function(restore)
                ACT.db.profile.circle.color = {restore.r, restore.g, restore.b, 1}
                UpdateButtonColor()
                CircleModule:ApplySettings()
            end
        })
    end)

    yOffset = yOffset - 50

    local shapeLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    shapeLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    shapeLabel:SetText("Shape")

    local circleCheck = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    circleCheck:SetPoint("LEFT", shapeLabel, "RIGHT", 20, 0)
    circleCheck:SetSize(20, 20)
    local circleLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    circleLabel:SetPoint("LEFT", circleCheck, "RIGHT", 5, 0)
    circleLabel:SetText("Circle")

    local squareCheck = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    squareCheck:SetPoint("LEFT", circleLabel, "RIGHT", 20, 0)
    squareCheck:SetSize(20, 20)
    local squareLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    squareLabel:SetPoint("LEFT", squareCheck, "RIGHT", 5, 0)
    squareLabel:SetText("Square")

    local function UpdateShapeChecks()
        local s = ACT.db.profile.circle.shape or defaults.shape
        circleCheck:SetChecked(s == "Circle")
        squareCheck:SetChecked(s == "Square")
    end
    UpdateShapeChecks()

    circleCheck:SetScript("OnClick", function()
        ACT.db.profile.circle.shape = "Circle"
        UpdateShapeChecks()
        CircleModule:ApplySettings()
    end)
    squareCheck:SetScript("OnClick", function()
        ACT.db.profile.circle.shape = "Square"
        UpdateShapeChecks()
        CircleModule:ApplySettings()
    end)

    yOffset = yOffset - 40

    local borderCheck = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    borderCheck:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    borderCheck:SetSize(24, 24)
    borderCheck:SetChecked(ACT.db.profile.circle and ACT.db.profile.circle.border)
    
    local borderLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    borderLabel:SetPoint("LEFT", borderCheck, "RIGHT", 5, 0)
    borderLabel:SetText("Enable Border")

    borderCheck:SetScript("OnClick", function(self)
        ACT.db.profile.circle.border = self:GetChecked()
        CircleModule:ApplySettings()
    end)

    yOffset = yOffset - 40

    local bWidthSlider, bWidthInput
    local currentBWidth = ACT.db.profile.circle and ACT.db.profile.circle.borderWidth or defaults.borderWidth

    local bWidthLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bWidthLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    bWidthLabel:SetText("Border Width")

    bWidthInput = CreateNumBox(configPanel, 50, 20, currentBWidth, function(val)
        if val < 1 then val = 1 end
        if val > 20 then val = 20 end
        ACT.db.profile.circle.borderWidth = val
        bWidthInput:SetText(val)
        if bWidthSlider then bWidthSlider:SetValue(val) end
        CircleModule:ApplySettings()
    end)
    bWidthInput:SetPoint("LEFT", bWidthLabel, "RIGHT", 10, 0)

    bWidthSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    bWidthSlider:SetPoint("TOPLEFT", bWidthLabel, "BOTTOMLEFT", 0, -10)
    bWidthSlider:SetMinMaxValues(1, 20)
    bWidthSlider:SetValue(currentBWidth)
    bWidthSlider:SetValueStep(1)
    bWidthSlider:SetObeyStepOnDrag(true)
    bWidthSlider:SetWidth(200)
    bWidthSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        ACT.db.profile.circle.borderWidth = val
        if bWidthInput and not bWidthInput:HasFocus() then bWidthInput:SetText(val) end
        CircleModule:ApplySettings()
    end)

    yOffset = yOffset - 50

    local bColorLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bColorLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    bColorLabel:SetText("Border Color")

    local bColorButton = CreateFrame("Button", nil, configPanel, "BackdropTemplate")
    bColorButton:SetSize(40, 24)
    bColorButton:SetPoint("LEFT", bColorLabel, "RIGHT", 20, 0)
    bColorButton:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1})
    bColorButton:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local function UpdateBorderButtonColor()
        local c = ACT.db.profile.circle.borderColor or defaults.borderColor
        if c then bColorButton:SetBackdropColor(c[1], c[2], c[3], 1) end
    end
    UpdateBorderButtonColor()

    bColorButton:SetScript("OnClick", function()
        local c = ACT.db.profile.circle.borderColor or defaults.borderColor
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c[1], g = c[2], b = c[3],
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                ACT.db.profile.circle.borderColor = {r, g, b, 1}
                UpdateBorderButtonColor()
                CircleModule:ApplySettings()
            end,
            cancelFunc = function(restore)
                ACT.db.profile.circle.borderColor = {restore.r, restore.g, restore.b, 1}
                UpdateBorderButtonColor()
                CircleModule:ApplySettings()
            end
        })
    end)

    self.configPanel = configPanel
    return configPanel
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(CircleModule)
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        CircleModule:ApplySettings()
    end)
end