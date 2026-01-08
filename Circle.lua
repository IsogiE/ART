local CircleModule = {}
CircleModule.title = "Character Marker"

local defaults = {
    enabled = false,
    size = 60,
    alpha = 0.5,
    color = {1, 0, 0, 1},
}

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
        self.circleFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
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

    local sizeLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    sizeLabel:SetText("Size: " .. (ACT.db.profile.circle and ACT.db.profile.circle.size or defaults.size))

    local sizeSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -10)
    sizeSlider:SetMinMaxValues(10, 300)
    sizeSlider:SetValue(ACT.db.profile.circle and ACT.db.profile.circle.size or defaults.size)
    sizeSlider:SetValueStep(1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetWidth(200)
    
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        ACT.db.profile.circle.size = val
        sizeLabel:SetText("Size: " .. val)
        CircleModule:ApplySettings()
    end)

    yOffset = yOffset - 60

    local alphaLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alphaLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, yOffset)
    alphaLabel:SetText("Opacity: " .. (ACT.db.profile.circle and math.ceil(ACT.db.profile.circle.alpha * 100) or 100) .. "%")

    local alphaSlider = CreateFrame("Slider", nil, configPanel, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", alphaLabel, "BOTTOMLEFT", 0, -10)
    alphaSlider:SetMinMaxValues(0.1, 1.0)
    alphaSlider:SetValue(ACT.db.profile.circle and ACT.db.profile.circle.alpha or defaults.alpha)
    alphaSlider:SetValueStep(0.05)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetWidth(200)

    alphaSlider:SetScript("OnValueChanged", function(self, value)
        ACT.db.profile.circle.alpha = value
        alphaLabel:SetText("Opacity: " .. math.ceil(value * 100) .. "%")
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