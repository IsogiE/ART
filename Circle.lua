local CircleModule = {}
CircleModule.title = "Character Marker"

local defaults = {
    enabled = false,
    size = 60,
    alpha = 0.5,
    color = {1, 0, 0, 1},
    posX = 0,
    posY = 0,
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
        self.circleFrame = CreateFrame("Frame", "ACT_ScreenCircle", UIParent)
        self.circleFrame:SetIgnoreParentScale(true)
        self.circleFrame:SetFrameStrata("MEDIUM")
        
        self.circleFrame.texture = self.circleFrame:CreateTexture(nil, "ARTWORK")
        self.circleFrame.texture:SetAllPoints()
        self.circleFrame.texture:SetTexture("Interface\\AddOns\\ACT\\media\\Aura72")
    end

    if settings.enabled then
        self.circleFrame:Show()
        self.circleFrame:SetSize(settings.size, settings.size)
        self.circleFrame:SetAlpha(settings.alpha)
        
        self.circleFrame:ClearAllPoints()
        self.circleFrame:SetPoint("CENTER", UIParent, "CENTER", settings.posX, settings.posY)
        
        local r, g, b, a = unpack(settings.color)
        self.circleFrame.texture:SetVertexColor(r, g, b)
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
    enableLabel:SetText("Enable Circle")

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
        
        if sizeSlider then 
            sizeSlider:SetValue(val) 
        end
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
        
        if sizeInput and not sizeInput:HasFocus() then
            sizeInput:SetText(val)
        end
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
        
        if xPosSlider then 
            xPosSlider:SetValue(val) 
        end
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
        
        if xPosInput and not xPosInput:HasFocus() then
            xPosInput:SetText(val)
        end
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
        
        if yPosSlider then 
            yPosSlider:SetValue(val) 
        end
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
        
        if yPosInput and not yPosInput:HasFocus() then
            yPosInput:SetText(val)
        end
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
        
        if alphaSlider then 
            alphaSlider:SetValue(floatVal) 
        end
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
        
        if alphaInput and not alphaInput:HasFocus() then
            alphaInput:SetText(math.ceil(value * 100))
        end
        CircleModule:ApplySettings()
    end)

    yOffset = yOffset - 60

    local colorLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    colorLabel:SetText("Color")

    local colorButton = CreateFrame("Button", nil, configPanel, "BackdropTemplate")
    colorButton:SetSize(40, 24)
    colorButton:SetPoint("LEFT", colorLabel, "RIGHT", 20, 0)
    colorButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    colorButton:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local function UpdateButtonColor()
        local c = ACT.db.profile.circle.color
        if c then
            colorButton:SetBackdropColor(c[1], c[2], c[3], 1)
        end
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