local NicknameModule = {}
NicknameModule.title = "Nicknames"
NicknameModule.lastUpdateMessageTime = 0

local AceComm = LibStub("AceComm-3.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local COMM_PREFIX = "NICK_MSG_V7"
local DELIMITER = "~"
local myRealmName

local function EnsureDB()
    if not ACT then
        ACT = {}
    end
    if not ACT.db then
        ACT.db = {}
    end
    if not ACT.db.profile then
        ACT.db.profile = {}
    end
    if not ACT.db.profile.players then
        ACT.db.profile.players = {}
    end
    if ACT.db.profile.nicknames or ACT.db.profile.defaultNicknames then
        ACT.db.profile.nicknames = nil
        ACT.db.profile.defaultNicknames = nil
    end
    if ACT.db.profile.streamerMode == nil then
        ACT.db.profile.streamerMode = false
    end
end
EnsureDB()

NicknameModule.playerBattleTag = nil

local function strtrim(s)
    return s and s:match("^%s*(.-)%s*$") or ""
end

local function GetMyRealm()
    if not myRealmName then
        myRealmName = GetRealmName()
    end
    return myRealmName
end

function NicknameModule:GetFormattedCharacterName(fullName)
    if not fullName or type(fullName) ~= "string" or fullName == "" then
        return ""
    end
    local charName, charRealm = strsplit("-", fullName)
    if charRealm and charRealm == GetMyRealm() then
        return charName
    else
        return fullName
    end
end

local function GetBroadcastCharacterName(charName)
    if not charName or type(charName) ~= "string" or charName == "" then
        return nil
    end
    if not string.find(charName, "-") then
        return charName .. "-" .. GetMyRealm()
    end
    return charName
end

local function GetPlayerBattleTag()
    if NicknameModule.playerBattleTag then
        return NicknameModule.playerBattleTag
    end
    if C_BattleNet and C_BattleNet.GetAccountInfoByGUID then
        local guid = UnitGUID("player")
        if guid then
            local info = C_BattleNet.GetAccountInfoByGUID(guid)
            if info and info.battleTag then
                NicknameModule.playerBattleTag = info.battleTag
                return info.battleTag
            end
        end
    end
    return nil
end

local function SerializeDataForBroadcast(data)
    local serialized = {}
    for btag, pData in pairs(data) do
        if pData and pData.nickname then
            local charsToSend = {}
            if pData.characters then
                for char, _ in pairs(pData.characters) do
                    local broadcastName = GetBroadcastCharacterName(char)
                    if broadcastName then
                        table.insert(charsToSend, broadcastName)
                    end
                end
            end
            table.insert(serialized, table.concat({btag, pData.nickname or "", table.concat(charsToSend, ",")}, "|"))
        end
    end
    if #serialized == 0 then
        return nil
    end
    local str = table.concat(serialized, ";")
    local compressed = LibDeflate:CompressDeflate(str)
    return LibDeflate:EncodeForWoWAddonChannel(compressed)
end

function NicknameModule:Broadcast(event, channel, data)
    local message
    if data then
        local serializedData = SerializeDataForBroadcast(data)
        if not serializedData then
            return
        end
        message = event .. DELIMITER .. serializedData
    else
        message = event
    end
    AceComm:SendCommMessage(COMM_PREFIX, message, channel)
end

local function ReceiveComm(prefix, message, channel, sender)
    if not message or message == "" then
        return
    end
    local event, data = strsplit(DELIMITER, message, 2)
    NicknameModule:EventHandler(event, sender, channel, data)
end
AceComm:RegisterComm(COMM_PREFIX, ReceiveComm)

function NicknameModule:BroadcastMyDatabase(channel)
    EnsureDB()
    local dataToSend = ACT.db.profile.players
    if not dataToSend or not next(dataToSend) then
        return
    end
    if channel then
        self:Broadcast("NICK_UPDATE", channel, dataToSend)
    end
end

function NicknameModule:BroadcastMyDatabaseToAll()
    if IsInRaid() then
        self:BroadcastMyDatabase("RAID")
    elseif IsInGroup() then
        self:BroadcastMyDatabase("PARTY")
    end
    if IsInGuild() then
        self:BroadcastMyDatabase("GUILD")
    end
end

function NicknameModule:EventHandler(event, sender, channel, data)
    if event == "NICK_UPDATE" then
        if type(data) ~= "string" then
            return
        end
        local decompressed = LibDeflate:DecompressDeflate(LibDeflate:DecodeForWoWAddonChannel(data))
        if not decompressed then
            return
        end
        local playersData = {}
        for pStr in string.gmatch(decompressed, "[^;]+") do
            local parts = {}
            for part in string.gmatch(pStr, "[^|]+") do
                table.insert(parts, part)
            end
            if #parts >= 2 then
                local btag, nickname, charStr = parts[1], parts[2], parts[3]
                if type(btag) == "string" and string.find(btag, "#") and type(nickname) == "string" then
                    playersData[btag] = {
                        nickname = nickname,
                        characters = {}
                    }
                    if charStr and charStr ~= "" then
                        for char in string.gmatch(charStr, "[^,]+") do
                            playersData[btag].characters[char] = true
                        end
                    end
                end
            end
        end
        if next(playersData) then
            self:MergeData(playersData)
        end
    elseif event == "NICK_REQUEST" then
        self:BroadcastMyDatabase(channel)
    elseif event == "NICK_KILLSWITCH" then
        EnsureDB()
        ACT.db.profile.players = {}
        if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
            NicknameAPI.RefreshAllIntegrations()
        end
        if self.configPanel and self.configPanel:IsShown() then
            self:RefreshContent()
        end
        if not self.killswitchPopup then
            self.killswitchPopup = UI:CreateTextPopup("Killswitch Activated", sender ..
                " has triggered a killswitch! All nicknames have been wiped.", "Reload Now", "Later", function()
                ReloadUI()
            end, function()
            end)
            self.killswitchPopup:SetScript("OnHide", function()
                self.killswitchPopup = nil
            end)
        end
        self.killswitchPopup:Show()
    end
end

function NicknameModule:MergeData(incomingPlayers)
    local hasChanged = false
    EnsureDB()
    local myBattleTag = GetPlayerBattleTag()
    for btag, incomingData in pairs(incomingPlayers) do
        if not ACT.db.profile.players[btag] then
            ACT.db.profile.players[btag] = {
                nickname = incomingData.nickname or "",
                characters = {}
            }
            hasChanged = true
        end
        local localData = ACT.db.profile.players[btag]
        if incomingData.nickname and incomingData.nickname ~= "" and localData.nickname ~= incomingData.nickname then
            if btag ~= myBattleTag then
                localData.nickname = incomingData.nickname
                hasChanged = true
            end
        end
        if incomingData.characters then
            for charFullName, _ in pairs(incomingData.characters) do
                if not localData.characters[charFullName] then
                    localData.characters[charFullName] = true
                    hasChanged = true
                end
            end
        end
    end
    if hasChanged then
        local currentTime = GetTime()
        if currentTime - (self.lastUpdateMessageTime or 0) > 10 then
            print("|cff00aaff[ACT]|r Nicknames updated. Consider reloading in the future if needed.")
            self.lastUpdateMessageTime = currentTime
        end

        if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
            C_Timer.After(0.1, NicknameAPI.RefreshAllIntegrations)
        end
        if self.configPanel and self.configPanel:IsShown() then
            self:RefreshContent()
        end
    end
end

function NicknameModule:OnPlayerLogin()
    C_Timer.After(2, function()
        GetMyRealm()
        local myBattleTag = GetPlayerBattleTag()
        if not myBattleTag then
            C_Timer.After(10, function()
                self:OnPlayerLogin()
            end)
            return
        end

        local myCharName = UnitName("player")
        if not myCharName then
            return
        end
        local myFullName = myCharName .. "-" .. GetMyRealm()

        EnsureDB()
        local playerRecord = ACT.db.profile.players[myBattleTag]
        local needsUpdate = false
        if not playerRecord then
            ACT.db.profile.players[myBattleTag] = {
                nickname = "",
                characters = {
                    [myFullName] = true
                }
            }
            needsUpdate = true
        elseif not playerRecord.characters[myFullName] then
            playerRecord.characters[myFullName] = true
            needsUpdate = true
        end

        if needsUpdate then
            self:BroadcastMyDatabaseToAll()
        end

        C_Timer.After(5, function()
            if IsInGuild() then
                self:Broadcast("NICK_REQUEST", "GUILD")
            end
            if IsInGroup() then
                local distribution = IsInRaid() and "RAID" or "PARTY"
                self:Broadcast("NICK_REQUEST", distribution)
            end
        end)
    end)
end

function NicknameModule:OnGroupUpdate()
    C_Timer.After(2, function()
        self:BroadcastMyDatabaseToAll()
        if IsInGroup() then
            local distribution = IsInRaid() and "RAID" or "PARTY"
            self:Broadcast("NICK_REQUEST", distribution)
        end
        if IsInGuild() then
            self:Broadcast("NICK_REQUEST", "GUILD")
        end
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        NicknameModule:OnPlayerLogin()
    elseif event == "GROUP_ROSTER_UPDATE" then
        NicknameModule:OnGroupUpdate()
    end
end)

function NicknameModule:GetConfigSize()
    return 800, 600
end

function NicknameModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        self:RefreshContent()
        return self.configPanel
    end

    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    configPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    self.configPanel = configPanel

    local titleLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 20, 16)
    titleLabel:SetText("Nicknames")

    local myNickLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    myNickLabel:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -8)
    myNickLabel:SetText("My Nickname")

    local myNickBoxFrame, myNickBoxEdit = UI:CreateMultilineEditBox(configPanel, 250, 30, "")
    myNickBoxFrame:SetPoint("TOPLEFT", myNickLabel, "BOTTOMLEFT", 0, -5)
    self.myNickBoxEdit = myNickBoxEdit

    local saveNickButton = UI:CreateButton(configPanel, "Save", 100, 30, function()
        local myBattleTag = GetPlayerBattleTag()
        if not myBattleTag then
            return
        end
        local newNick = self.myNickBoxEdit:GetText()
        EnsureDB()
        if not ACT.db.profile.players[myBattleTag] then
            ACT.db.profile.players[myBattleTag] = {
                nickname = newNick,
                characters = {}
            }
        else
            ACT.db.profile.players[myBattleTag].nickname = newNick
        end
        self:BroadcastMyDatabaseToAll()
        if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
            NicknameAPI.RefreshAllIntegrations()
        end
        self:RefreshContent()
    end)

    saveNickButton:SetPoint("LEFT", myNickBoxFrame, "RIGHT", 10, 0)
    local importLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importLabel:SetPoint("TOPLEFT", myNickBoxFrame, "BOTTOMLEFT", 0, -8)
    importLabel:SetText("Import Nicknames")
    local importBoxFrame, importBoxEdit = UI:CreateMultilineEditBox(configPanel, 520, 40, nil)
    importBoxFrame:SetPoint("TOPLEFT", importLabel, "BOTTOMLEFT", 0, -5)
    self.importBoxEdit = importBoxEdit
    local importButton = UI:CreateButton(configPanel, "Import", 120, 30, function()
        local text = self.importBoxEdit:GetText()
        if text and text ~= "" then
            self:ProcessImportString(text)
            self.importBoxEdit:SetText("")
        end
    end)

    importButton:SetPoint("TOPLEFT", importBoxFrame, "BOTTOMLEFT", 0, -5)
    local exportButton = UI:CreateButton(configPanel, "Export Nicknames", 120, 30, function()
        self:ShowExportPopup()
    end)

    exportButton:SetPoint("LEFT", importButton, "RIGHT", 10, 0)
    local headerFrame = CreateFrame("Frame", nil, configPanel)
    headerFrame:SetSize(520, 20)
    headerFrame:SetPoint("TOPLEFT", importButton, "BOTTOMLEFT", 0, -15)

    local nicknameHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nicknameHeader:SetPoint("LEFT", headerFrame, "LEFT", 25, -10)
    nicknameHeader:SetText("Nickname")

    local charHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    charHeader:SetPoint("LEFT", headerFrame, "LEFT", 180, -10)
    charHeader:SetText("Known Characters")

    local actionsHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    actionsHeader:SetPoint("LEFT", headerFrame, "LEFT", 380, -10)
    actionsHeader:SetText("Actions")

    local scrollFrame = CreateFrame("ScrollFrame", nil, configPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(520, 340)
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(500, 340)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild

    if IsPrivilegedUser() then
        local debugFrame = CreateFrame("Frame", "DebugToolsFrame", configPanel, "BackdropTemplate")
        debugFrame:SetSize(165, 100)
        debugFrame:SetPoint("TOPLEFT", configPanel, "TOPRIGHT", -213, 40)
        debugFrame.bg = debugFrame:CreateTexture(nil, "BACKGROUND")
        debugFrame.bg:SetAllPoints()
        debugFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
        debugFrame.border = CreateFrame("Frame", nil, debugFrame, "BackdropTemplate")
        debugFrame.border:SetAllPoints()
        debugFrame.border:SetBackdrop({
            edgeFile = "Interface\\AddOns\\ACT\\media\\border",
            edgeSize = 8
        })

        local title = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -10)
        title:SetText("DEBUG TOOLS")
        local nukeLocalBtn = UI:CreateButton(debugFrame, "Nuke Local", 135, 30, function()
            SlashCmdList["WIPENICKNAMES"]("")
        end)

        nukeLocalBtn:SetPoint("TOP", title, "BOTTOM", 0, -5)
        local nukeAllBtn = UI:CreateButton(debugFrame, "Nuke ALL", 135, 30, function()
            SlashCmdList["ACTKILLSWITCH"]("")
        end)

        nukeAllBtn:SetPoint("TOP", nukeLocalBtn, "BOTTOM", 0, -5)
    end

    local integrationCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    integrationCheckbox:SetPoint("LEFT", importButton, "RIGHT", 150, 0)
    integrationCheckbox:SetSize(22, 22)
    integrationCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    integrationCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    integrationCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    integrationCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    integrationCheckbox.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    integrationCheckbox.Text:SetText("Show Nicknames on Raid Frames")
    integrationCheckbox.Text:ClearAllPoints()
    integrationCheckbox.Text:SetPoint("LEFT", integrationCheckbox, "RIGHT", 5, 0)
    integrationCheckbox:SetChecked(ACT.db.profile.useNicknameIntegration)
    integrationCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        ACT.db.profile.useNicknameIntegration = checked
        NicknameModule:RefreshContent()
        NicknameModule:PromptReloadNormal()
    end)

    local streamerCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    streamerCheckbox:SetPoint("TOP", integrationCheckbox, "BOTTOM", 0, -5)
    streamerCheckbox:SetSize(22, 22)
    streamerCheckbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    streamerCheckbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    streamerCheckbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    streamerCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    streamerCheckbox.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    streamerCheckbox.Text:SetText("Streamer Mode")
    streamerCheckbox.Text:ClearAllPoints()
    streamerCheckbox.Text:SetPoint("LEFT", streamerCheckbox, "RIGHT", 5, 0)
    streamerCheckbox:SetChecked(ACT.db.profile.streamerMode)
    streamerCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        ACT.db.profile.streamerMode = checked
        NicknameModule:RefreshContent()
    end)

    self:RefreshContent()
    return configPanel
end

function NicknameModule:PromptReloadNormal()
    if not self.reloadPopupNormal then
        self.reloadPopupNormal = UI:CreateTextPopup("Reload UI", "Please reload your UI to apply the changes.",
            "Reload Now", "Later", function()
                ReloadUI()
            end, function()
            end)
        self.reloadPopupNormal:SetScript("OnHide", function()
            self.reloadPopupNormal = nil
        end)
    end
    self.reloadPopupNormal:Show()
end

function NicknameModule:RefreshContent()
    if not self.scrollChild then
        return
    end
    EnsureDB()
    for _, child in ipairs({self.scrollChild:GetChildren()}) do
        child:Hide();
        child:SetParent(nil)
    end
    local myBattleTag = GetPlayerBattleTag()
    if myBattleTag and ACT.db.profile.players[myBattleTag] and self.myNickBoxEdit then
        self.myNickBoxEdit:SetText(ACT.db.profile.players[myBattleTag].nickname or "")
    elseif self.myNickBoxEdit then
        self.myNickBoxEdit:SetText("")
    end
    local sortedPlayers = {}
    for btag, data in pairs(ACT.db.profile.players) do
        if data then
            table.insert(sortedPlayers, {
                btag = btag,
                nick = data.nickname or btag
            })
        end
    end
    table.sort(sortedPlayers, function(a, b)
        return a.nick:lower() < b.nick:lower()
    end)
    local yOffset = -10
    local isStreamerMode = ACT.db.profile.streamerMode
    for _, playerData in ipairs(sortedPlayers) do
        local btag = playerData.btag
        local data = ACT.db.profile.players[btag]
        local row = CreateFrame("Frame", nil, self.scrollChild, "BackdropTemplate")
        row:SetSize(470, 30)
        row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 25, yOffset)
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1
        })
        row:SetBackdropColor(0.15, 0.15, 0.15, 1)
        row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        local deletePlayerBtn = UI:CreateButton(self.scrollChild, "X", 20, 20, function()
            if NicknameModule.deleteConfirmationPopup and NicknameModule.deleteConfirmationPopup:IsShown() then
                return
            end
            local displayName = isStreamerMode and (data.nickname or "this player") or btag
            local popup = UI:CreateTextPopup("Confirm Delete", "Delete all data for " .. displayName .. "?", "Delete",
                "Cancel", function()
                    ACT.db.profile.players[btag] = nil
                    if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
                        NicknameAPI.RefreshAllIntegrations()
                    end
                    self:RefreshContent()
                    NicknameModule.deleteConfirmationPopup = nil
                end, function()
                    NicknameModule.deleteConfirmationPopup = nil
                end)
            popup:SetScript("OnHide", function()
                NicknameModule.deleteConfirmationPopup = nil
            end)
            NicknameModule.deleteConfirmationPopup = popup
            popup:Show()
        end)
        deletePlayerBtn:SetPoint("RIGHT", row, "LEFT", -5, 0)
        local nickLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nickLabel:SetPoint("LEFT", 5, 8)
        nickLabel:SetSize(200, 15)
        nickLabel:SetJustifyH("LEFT")

        local btagLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btagLabel:SetPoint("TOPLEFT", nickLabel, "BOTTOMLEFT", 0, -2)
        btagLabel:SetSize(200, 10)
        btagLabel:SetJustifyH("LEFT")

        if isStreamerMode then
            nickLabel:SetText(data.nickname or "Please Subscribe!")
            btagLabel:SetText("Please Subscribe!")
        else
            nickLabel:SetText(data.nickname or btag)
            btagLabel:SetText(btag)
        end

        local dropdown = UI:CreateDropdown(row, 200, 30)
        dropdown:SetPoint("LEFT", nickLabel, "RIGHT", -50, -8)
        local options = {}
        if data.characters then
            for fullName, _ in pairs(data.characters) do
                table.insert(options, {
                    text = self:GetFormattedCharacterName(fullName),
                    value = fullName
                })
            end
        end
        UI:SetDropdownOptions(dropdown, options)
        dropdown.button.text:SetText("Select Character")
        local deleteCharBtn = UI:CreateButton(row, "Delete Character", 100, 20, function()
            if dropdown.selectedValue and data.characters[dropdown.selectedValue] then
                data.characters[dropdown.selectedValue] = nil
                if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
                    NicknameAPI.RefreshAllIntegrations()
                end
                self:RefreshContent()
                self:BroadcastMyDatabaseToAll()
            end
        end)
        deleteCharBtn:SetPoint("LEFT", dropdown, "RIGHT", 5, 0)
        yOffset = yOffset - 40
    end
    self.scrollChild:SetHeight(math.abs(yOffset) + 10)
end

function NicknameModule:ProcessImportString(importString)
    EnsureDB()
    local importedPlayers = {}
    for entry in string.gmatch(importString, "[^;]+") do
        entry = strtrim(entry)
        if entry ~= "" then
            local btag, nick, charsStr = strsplit(":", entry)
            if type(btag) == "string" and string.find(btag, "#") and type(nick) == "string" then
                btag = strtrim(btag)
                nick = strtrim(nick)
                charsStr = charsStr or ""
                if not ACT.db.profile.players[btag] then
                    ACT.db.profile.players[btag] = {
                        nickname = nick,
                        characters = {}
                    }
                else
                    ACT.db.profile.players[btag].nickname = nick
                end
                for charName in string.gmatch(charsStr, "[^,]+") do
                    charName = strtrim(charName)
                    if charName ~= "" then
                        if not string.find(charName, "-") then
                            charName = charName .. "-" .. GetMyRealm()
                        end
                        ACT.db.profile.players[btag].characters[charName] = true
                    end
                end
                importedPlayers[btag] = ACT.db.profile.players[btag]
            end
        end
    end
    if next(importedPlayers) then
        self:BroadcastMyDatabaseToAll()
        if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
            NicknameAPI.RefreshAllIntegrations()
        end
        self:RefreshContent()
    end
end

function NicknameModule:GetFullNicknameString()
    EnsureDB()
    local parts = {}
    local sortedBt_tags = {}
    for btag in pairs(ACT.db.profile.players) do
        table.insert(sortedBt_tags, btag)
    end
    table.sort(sortedBt_tags)
    for _, btag in ipairs(sortedBt_tags) do
        local data = ACT.db.profile.players[btag]
        if data and data.nickname and data.nickname ~= "" then
            local charList = {}
            if data.characters and next(data.characters) then
                for char, _ in pairs(data.characters) do
                    table.insert(charList, char)
                end
                table.sort(charList)
            end
            table.insert(parts, btag .. ":" .. data.nickname .. ":" .. table.concat(charList, ","))
        end
    end
    return table.concat(parts, ";\n")
end

function NicknameModule:ShowExportPopup()
    local exportString = self:GetFullNicknameString()
    if not self.exportPopup then
        local popup, editBox = UI:CreatePopupWithEditBox("Export Nickname String", 400, 300, exportString, function()
            self.exportPopup:Hide()
        end, function()
            self.exportPopup:Hide()
        end)
        popup:SetScript("OnHide", function()
            self.exportPopup = nil
        end)
        if popup.buttonContainer and popup.buttonContainer.cancelButton then
            popup.buttonContainer.cancelButton:Hide()
            popup.buttonContainer.acceptButton:ClearAllPoints()
            popup.buttonContainer.acceptButton:SetPoint("CENTER", popup.buttonContainer, "CENTER")
            popup.buttonContainer.acceptButton.text:SetText("Close")
        end
        editBox:HighlightText()
        self.exportPopup = popup
    end
    self.exportPopup:Show()
end

function IsPrivilegedUser()
    local btag = GetPlayerBattleTag()
    if not btag then
        return false
    end
    local privilegedList = {
        ["Isogi#21124"] = true,
        ["Jafar#21190"] = true,
        ["ViklunD#2904"] = true,
        ["Strike#2545"] = true
    }
    return privilegedList[btag]
end

SLASH_WIPENICKNAMES1 = "/actwipe"
SlashCmdList["WIPENICKNAMES"] = function()
    if not IsPrivilegedUser() then
        return
    end
    if not NicknameModule.wipePopup then
        NicknameModule.wipePopup = UI:CreateTextPopup("Confirm Wipe",
            "Are you sure you want to wipe all your local nicknames? This cannot be undone.", "Yes, Wipe", "Cancel",
            function()
                EnsureDB()
                ACT.db.profile.players = {}
                if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
                    NicknameAPI.RefreshAllIntegrations()
                end
                NicknameModule:RefreshContent()
            end)
        NicknameModule.wipePopup:SetScript("OnHide", function()
            NicknameModule.wipePopup = nil
        end)
    end
    NicknameModule.wipePopup:Show()
end

SLASH_ACTKILLSWITCH1 = "/actkillswitch"
SlashCmdList["ACTKILLSWITCH"] = function()
    if not IsPrivilegedUser() then
        return
    end
    if not NicknameModule.killConfirmPopup then
        NicknameModule.killConfirmPopup = UI:CreateTextPopup("Confirm Killswitch",
            "Are you sure you want to trigger the killswitch? This will wipe ALL nicknames for everyone in your group/guild.",
            "Yes, Killswitch", "Cancel", function()
                local dist = IsInRaid() and "RAID" or (IsInGuild() and "GUILD" or (IsInGroup() and "PARTY"))
                if dist then
                    NicknameModule:Broadcast("NICK_KILLSWITCH", dist)
                end
            end)
        NicknameModule.killConfirmPopup:SetScript("OnHide", function()
            NicknameModule.killConfirmPopup = nil
        end)
    end
    NicknameModule.killConfirmPopup:Show()
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(NicknameModule)
end

return NicknameModule
