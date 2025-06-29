local AceComm = LibStub:GetLibrary("AceComm-3.0")

local function AttachTooltip(frame)
    frame:SetScript("OnEnter", function(self)
        if self.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.tooltip)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

local iconExclamation = C_Texture.GetAtlasInfo("Islands-QuestBangDisable") or C_Texture.GetAtlasInfo("QuestTurnin")

local function SetIconTexture(icon, statusType, playerVersion, latestVersion)
    icon:Hide()
    icon.tooltip = nil

    if statusType == 0 then
        return
    elseif statusType == 1 then
        icon:SetTexture("Interface\\AddOns\\ACT\\media\\DiesalGUIcons16x256x128")
        icon:SetTexCoord(0.5, 0.5625, 0.5, 0.625)
        icon:SetVertexColor(0.8, 0, 0, 1)
        icon.tooltip = "Missing"
        icon:Show()
    elseif statusType == 2 then
        icon:SetTexture("Interface\\AddOns\\ACT\\media\\DiesalGUIcons16x256x128")
        icon:SetTexCoord(0.5625, 0.625, 0.5, 0.625)
        icon:SetVertexColor(0, 0.8, 0, 1)
        icon.tooltip = "Up-to-date: " .. (playerVersion or "")
        icon:Show()
    elseif statusType == 3 then
        if iconExclamation then
            icon:SetTexture(iconExclamation.file)
            icon:SetTexCoord(iconExclamation.leftTexCoord, iconExclamation.rightTexCoord, iconExclamation.topTexCoord,
                iconExclamation.bottomTexCoord)
            icon:SetVertexColor(1, 1, 1, 1)
        else
            icon:SetTexture("Interface\\AddOns\\ACT\\media\\DiesalGUIcons16x256x128")
            icon:SetTexCoord(0.3125, 0.375, 0.625, 0.75)
            icon:SetVertexColor(1, 1, 0, 1)
        end
        icon.tooltip = "Outdated: " .. (playerVersion or "") .. "\nLatest: " .. (latestVersion or "")
        icon:Show()
    end
end

local function CreateLegend(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(520, 20)

    local x = 0
    local function AddLegendIcon(statusType, text)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", frame, "LEFT", x, 0)
        SetIconTexture(icon, statusType)
        icon:Show()

        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        label:SetText(text)

        x = x + 16 + 5 + label:GetStringWidth() + 15
    end

    AddLegendIcon(1, "Missing Addon")
    AddLegendIcon(2, "Addon Present")
    AddLegendIcon(3, "Outdated Addon")

    return frame
end

local function GetRoster()
    local roster = {}
    local myShortName = Ambiguate(UnitName("player"), "short")
    table.insert(roster, myShortName)

    local group = IsInRaid() and "raid" or (IsInGroup() and "party" or nil)
    if group then
        for i = 1, GetNumGroupMembers() do
            local unit = group .. i
            if UnitExists(unit) then
                local name = UnitName(unit)
                if name then
                    local shortName = Ambiguate(name, "short")
                    local found = false
                    for _, existingName in ipairs(roster) do
                        if existingName == shortName then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(roster, shortName)
                    end
                end
            end
        end
    end

    return roster
end

local addonAbbreviations = {
    AuraUpdater = "AU",
    BigWigs = "BW",
    NorthernSkyRaidTools = "NSR",
    RCLootCouncil = "RCLC",
    SharedMedia_Causese = "SMC",
    TimelineReminders = "TR",
    WeakAuras = "WA"
}

local AddonCheckerModule = {}
AddonCheckerModule.title = "Addon Checker"
AddonCheckerModule.addonsToCheck = {"AuraUpdater", "BigWigs", "NorthernSkyRaidTools", "RCLootCouncil",
                                    "SharedMedia_Causese", "TimelineReminders", "WeakAuras"}
AddonCheckerModule.responses = {}
AddonCheckerModule.rowFramePool = {}
AddonCheckerModule.rowFrames = {}

function AddonCheckerModule:GetConfigSize()
    return 800, 600
end

function AddonCheckerModule:GetUnitClassColor(playerName)
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and Ambiguate(UnitName(unit), "short") == playerName then
                local _, class = UnitClass(unit)
                return RAID_CLASS_COLORS[class] or {
                    r = 1,
                    g = 1,
                    b = 1
                }
            end
        end
    elseif IsInGroup() then
        if Ambiguate(UnitName("player"), "short") == playerName then
            local _, class = UnitClass("player")
            return RAID_CLASS_COLORS[class] or {
                r = 1,
                g = 1,
                b = 1
            }
        end
        for i = 1, GetNumGroupMembers() do
            local unit = "party" .. i
            if UnitExists(unit) and Ambiguate(UnitName(unit), "short") == playerName then
                local _, class = UnitClass(unit)
                return RAID_CLASS_COLORS[class] or {
                    r = 1,
                    g = 1,
                    b = 1
                }
            end
        end
    else
        if Ambiguate(UnitName("player"), "short") == playerName then
            local _, class = UnitClass("player")
            return RAID_CLASS_COLORS[class] or {
                r = 1,
                g = 1,
                b = 1
            }
        end
    end
    return {
        r = 1,
        g = 1,
        b = 1
    }
end

function AddonCheckerModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        return self.configPanel
    end

    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    configPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local checkerLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    checkerLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    checkerLabel:SetText("Addon Checker")

    local legend = CreateLegend(configPanel)
    legend:SetPoint("TOPLEFT", checkerLabel, "BOTTOMLEFT", 0, -10)

    local nameColumnWidth = 150
    local addonColumnWidth = 40
    local numAddons = #self.addonsToCheck
    local gridWidth = nameColumnWidth + numAddons * addonColumnWidth

    local headerFrame = CreateFrame("Frame", nil, configPanel)
    headerFrame:SetPoint("TOPLEFT", legend, "BOTTOMLEFT", 0, -10)
    headerFrame:SetSize(gridWidth, 20)
    self.headerFrame = headerFrame

    local headerDividerLeft = headerFrame:CreateTexture(nil, "OVERLAY")
    headerDividerLeft:SetColorTexture(0.3, 0.3, 0.3, 1)
    headerDividerLeft:SetPoint("LEFT", headerFrame, "LEFT", nameColumnWidth, 0)
    headerDividerLeft:SetSize(1, 20)
    headerDividerLeft:Show()

    for i, addonName in ipairs(self.addonsToCheck) do
        local abbrev = addonAbbreviations[addonName] or addonName
        local fs = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fs:SetPoint("CENTER", headerFrame, "LEFT", nameColumnWidth + (i - 1) * addonColumnWidth + addonColumnWidth / 2,
            0)
        fs:SetText(abbrev)
        fs:Show()
        fs:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(addonName)
            GameTooltip:Show()
        end)
        fs:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        local divider = headerFrame:CreateTexture(nil, "OVERLAY")
        divider:SetColorTexture(0.3, 0.3, 0.3, 1)
        divider:SetPoint("LEFT", headerFrame, "LEFT", nameColumnWidth + i * addonColumnWidth, 0)
        divider:SetSize(1, 20)
        divider:Show()
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, configPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(gridWidth + 20, 405)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -10)
    self.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(gridWidth, 405)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild

    local updateButton = UI:CreateButton(configPanel, "Refresh", 120, 30)
    updateButton:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -10)
    updateButton:SetScript("OnClick", function()
        self:SendReq()
    end)

    self:UpdateGrid()

    self.configPanel = configPanel
    return configPanel
end

function AddonCheckerModule:BuildGrid()
    for _, row in ipairs(self.rowFrames) do
        row:Hide()
        table.insert(self.rowFramePool, row)
    end
    self.rowFrames = {}

    local roster = GetRoster()
    local nameColumnWidth = 150
    local addonColumnWidth = 40
    local numAddons = #self.addonsToCheck
    local gridWidth = nameColumnWidth + numAddons * addonColumnWidth
    local yOffset = -5

    for _, playerName in ipairs(roster) do
        local row = table.remove(self.rowFramePool)
        if not row then
            row = CreateFrame("Frame", nil, self.scrollChild, "BackdropTemplate")
            row:SetSize(gridWidth, 20)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1
            })
            row:SetBackdropColor(0.15, 0.15, 0.15, 1)
            row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

            row.label = UI:CreateLabel(row, "", 10, {1, 1, 1})
            row.label:SetPoint("LEFT", row, "LEFT", 5, 0)
            row.label:SetSize(nameColumnWidth, 20)
            row.label:SetJustifyH("LEFT")

            local rowDividerLeft = row:CreateTexture(nil, "OVERLAY")
            rowDividerLeft:SetColorTexture(0.3, 0.3, 0.3, 1)
            rowDividerLeft:SetPoint("LEFT", row, "LEFT", nameColumnWidth, 0)
            rowDividerLeft:SetSize(1, 20)

            row.icons = {}
            for i = 1, numAddons do
                local iconX = nameColumnWidth + (i - 1) * addonColumnWidth + (addonColumnWidth - 20) / 2
                local icon = row:CreateTexture(nil, "ARTWORK")
                icon:SetSize(20, 20)
                icon:SetPoint("LEFT", row, "LEFT", iconX, 0)
                AttachTooltip(icon)
                icon:Hide()
                row.icons[i] = icon

                local divider = row:CreateTexture(nil, "OVERLAY")
                divider:SetColorTexture(0.3, 0.3, 0.3, 1)
                divider:SetPoint("LEFT", row, "LEFT", nameColumnWidth + i * addonColumnWidth, 0)
                divider:SetSize(1, 20)
            end
        end

        row:SetParent(self.scrollChild)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, yOffset)

        local classColor = self:GetUnitClassColor(playerName)
        row.label:SetText(playerName)
        row.label:SetTextColor(classColor.r, classColor.g, classColor.b)

        row:Show()
        table.insert(self.rowFrames, row)
        yOffset = yOffset - 22
    end
    self.scrollChild:SetHeight(math.abs(yOffset) + 10)
end

function AddonCheckerModule:UpdateGrid()
    self:BuildGrid()

    local roster = GetRoster()
    local numAddons = #self.addonsToCheck

    for rowIndex, playerName in ipairs(roster) do
        local row = self.rowFrames[rowIndex]
        if row then
            for i = 1, numAddons do
                local icon = row.icons[i]
                local addonName = self.addonsToCheck[i]
                local data = self.responses[playerName]
                local addonData = data and data[addonName]
                if not addonData then
                    SetIconTexture(icon, 0)
                else
                    if addonData.loaded then
                        local latestVer = self:GetLatestAddonVersion(addonName)
                        if self:CompareVersions(addonData.version, latestVer) then
                            SetIconTexture(icon, 2, addonData.version)
                        else
                            SetIconTexture(icon, 3, addonData.version, latestVer)
                        end
                    else
                        SetIconTexture(icon, 1)
                    end
                end
            end
        end
    end

    if self.scrollChild:GetHeight() <= self.scrollFrame:GetHeight() then
        if self.scrollFrame.ScrollBar then
            self.scrollFrame.ScrollBar:Hide()
        end
    else
        if self.scrollFrame.ScrollBar then
            self.scrollFrame.ScrollBar:Show()
        end
    end
end

function AddonCheckerModule:NormalizeVersion(version)
    local normalized = version:gsub("[^0-9%.]", "")
    return normalized ~= "" and normalized or "0"
end

function AddonCheckerModule:CompareVersions(v1_str, v2_str)
    if not v1_str or not v2_str or v1_str == "" or v2_str == "" or v1_str == "-" or v2_str == "-" then
        return true
    end
    local v1_parts = {strsplit(".", self:NormalizeVersion(v1_str))}
    local v2_parts = {strsplit(".", self:NormalizeVersion(v2_str))}
    for i = 1, math.max(#v1_parts, #v2_parts) do
        local p1 = tonumber(v1_parts[i]) or 0
        local p2 = tonumber(v2_parts[i]) or 0
        if p1 < p2 then
            return false
        end
        if p1 > p2 then
            return true
        end
    end
    return true
end

function AddonCheckerModule:GetLatestAddonVersion(addonName)
    local latest = "0"
    for _, data in pairs(self.responses) do
        local info = data[addonName]
        if info and info.loaded and info.version and info.version ~= "-" then
            if not self:CompareVersions(latest, info.version) then
                latest = info.version
            end
        end
    end
    return latest
end

function AddonCheckerModule:CheckResponse()
    local response = {}
    for _, addonName in ipairs(self.addonsToCheck) do
        local name = C_AddOns.GetAddOnInfo(addonName)
        local loaded = (name and C_AddOns.IsAddOnLoaded(addonName))
        local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
        if not version or version == "" then
            version = "-"
        end
        response[addonName] = {
            loaded = loaded,
            version = version
        }
    end
    return response
end

function AddonCheckerModule:OnEnable()
    AceComm:RegisterComm("ART_AddonChecker", function(prefix, message, distribution, sender)
        if sender == UnitName("player") then
            return
        end

        if message == "CHECK_REQUEST" then
            local myResponse = self:CheckResponse()
            local responseTable = {}
            for addonName, data in pairs(myResponse) do
                if data.loaded then
                    table.insert(responseTable, addonName .. "=" .. data.version)
                end
            end
            local responseStr = #responseTable > 0 and table.concat(responseTable, ",") or "NONE"
            AceComm:SendCommMessage("ART_AddonChecker", "STATUS:" .. responseStr, "WHISPER", sender)

        elseif message:find("^STATUS:") then
            local statusStr = message:sub(8)
            local response = {}
            if statusStr ~= "NONE" then
                for chunk in string.gmatch(statusStr, "[^,]+") do
                    local addonName, version = strsplit("=", chunk)
                    if addonName and version then
                        response[addonName] = {
                            loaded = true,
                            version = version
                        }
                    end
                end
            end
            for _, addonName in ipairs(self.addonsToCheck) do
                if not response[addonName] then
                    response[addonName] = {
                        loaded = false,
                        version = nil
                    }
                end
            end
            self.responses[Ambiguate(sender, "short")] = response
            if self.UpdateGrid then
                self:UpdateGrid()
            end
        end
    end)
end

function AddonCheckerModule:SendReq()
    local me = Ambiguate(UnitName("player"), "short")
    local myInfo = self:CheckResponse()

    wipe(self.responses)
    self.responses[me] = myInfo

    if IsInRaid() or IsInGroup() then
        AceComm:SendCommMessage("ART_AddonChecker", "CHECK_REQUEST", IsInRaid() and "RAID" or "PARTY")
    end

    if self.UpdateGrid then
        self:UpdateGrid()
    end
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(AddonCheckerModule)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if addon == "ACT" then
        AddonCheckerModule:OnEnable()
    end
end)
