local HomeModule = {}

HomeModule.title = "Home"

function HomeModule:GetConfigSize()
    return 800, 600
end

function HomeModule:CreateConfigPanel(parent)
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
    title:SetText("Home")

    local logo = configPanel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(256, 256)
    logo:SetPoint("TOP", configPanel, "TOP", -120, -50)
    logo:SetTexture("Interface\\AddOns\\ACT\\media\\logo.tga")
    logo:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    local info = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetPoint("TOP", logo, "BOTTOM", 0, -10)
    info:SetText("|cff00ccffAdvance Custom Tools|r\n\n|cffffcc00The #1 way to upset your raiders|r")
    info:SetJustifyH("CENTER")

    local hatewatch = configPanel:CreateTexture(nil, "ARTWORK")
    hatewatch:SetSize(600, 500)
    hatewatch:SetPoint("CENTER", configPanel, "CENTER", -120, 50)
    hatewatch:SetTexture("Interface\\AddOns\\ACT\\media\\hatewatch.tga")

    local brickleft = configPanel:CreateTexture(nil, "ARTWORK")
    brickleft:SetSize(32, 32)
    brickleft:SetPoint("TOP", configPanel, "CENTER", -260, -170)
    brickleft:SetTexture("Interface\\AddOns\\ACT\\media\\roiben.tga")

    local brickright = configPanel:CreateTexture(nil, "ARTWORK")
    brickright:SetSize(32, 32)
    brickright:SetPoint("TOP", configPanel, "CENTER", 20, -170)
    brickright:SetTexture("Interface\\AddOns\\ACT\\media\\roiben.tga")

    self.configPanel = configPanel
    return configPanel
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(HomeModule)
end
