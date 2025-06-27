local NicknameModule = {}
NicknameModule.title = "Nicknames"
NicknameModule.lastUpdateMessageTime = 0
NicknameModule.defaultNicknames = {}
NicknameModule.hasReceivedWAData = false
NicknameModule.waMessageAccumulator = {}
NicknameModule.waMessageTimer = {}

NicknameModule.rowPool = {}

local AceComm = LibStub("AceComm-3.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")
local COMM_PREFIX = "NICK_MSG_ADV"
local COMM_PREFIX_WA = "WA_NICK_ADV"
local DELIMITER = "~"
local myRealmName

local BTAG_REGEX = "^[^#:|;@]+#%d+$"

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
    if ACT.db.profile.streamerMode == nil then
        ACT.db.profile.streamerMode = false
    end
    if ACT.db.profile.useNicknameIntegration == nil then
        ACT.db.profile.useNicknameIntegration = true
    end
    if ACT.db.profile.dataVersion == nil then
        ACT.db.profile.dataVersion = 0
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

function NicknameModule:SetDefaultNicknames(newDefaults)
    newDefaults = newDefaults or {}
    EnsureDB()
    local hasChanged = false
    local playersDB = ACT.db.profile.players
    local keysToDelete = {}

    for btag, _ in pairs(playersDB) do
        if not newDefaults[btag] then
            table.insert(keysToDelete, btag)
        end
    end

    if #keysToDelete > 0 then
        for _, btag in ipairs(keysToDelete) do
            playersDB[btag] = nil
        end
        hasChanged = true
    end

    for btag, defaultNick in pairs(newDefaults) do
        if not playersDB[btag] then
            playersDB[btag] = {
                nickname = defaultNick,
                characters = {}
            }
            hasChanged = true
        else
            if playersDB[btag].nickname ~= defaultNick then
                playersDB[btag].nickname = defaultNick
                hasChanged = true
            end
        end
    end

    self.defaultNicknames = newDefaults

    if hasChanged then
        self:BroadcastMyDatabaseToAll()
        if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
            C_Timer.After(0.1, NicknameAPI.RefreshAllIntegrations)
        end
        if self.configPanel and self.configPanel:IsShown() then
            self:RefreshContent()
        end
    end
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

        if event == "NICK_UPDATE" then
            local currentVersion = ACT.db.profile.dataVersion or 0
            message = event .. DELIMITER .. tostring(currentVersion) .. DELIMITER .. serializedData
        else
            message = event .. DELIMITER .. serializedData
        end
    else
        message = event
    end
    AceComm:SendCommMessage(COMM_PREFIX, message, channel)
end

local function ReceiveRegularComm(prefix, message, channel, sender)
    if prefix == COMM_PREFIX then
        local event, data = strsplit(DELIMITER, message, 2)
        NicknameModule:EventHandler(event, sender, channel, data)
    end
end

local function ReceiveWAComm(prefix, message, channel, sender)
    if prefix ~= COMM_PREFIX_WA or type(message) ~= "string" then
        return
    end

    if NicknameModule.waMessageTimer[sender] then
        C_Timer.Cancel(NicknameModule.waMessageTimer[sender])
    end
    NicknameModule.waMessageTimer[sender] = C_Timer.After(5, function()
        NicknameModule.waMessageAccumulator[sender] = nil
        NicknameModule.waMessageTimer[sender] = nil
    end)

    if string.sub(message, 1, 6) == "START:" then
        local _, versionStr = strsplit(":", message, 2)
        local incomingVersion = tonumber(versionStr) or 0
        NicknameModule.waMessageAccumulator[sender] = {
            data = "",
            version = incomingVersion
        }

    elseif message == "START" then
        NicknameModule.waMessageAccumulator[sender] = {
            data = "",
            version = 0
        }

    elseif message == "END" then
        local accumulation = NicknameModule.waMessageAccumulator[sender]

        if accumulation and accumulation.data and accumulation.data ~= "" then
            local defaults = {}
            for entry in string.gmatch(accumulation.data, "([^;]+)") do
                local btag, nick = strsplit(":", entry, 2)
                if btag and nick and btag ~= "" and nick ~= "" then
                    local cleanBtag = strtrim(btag)
                    if cleanBtag:match(BTAG_REGEX) then
                        defaults[cleanBtag] = strtrim(nick)
                    end
                end
            end
            if next(defaults) then
                NicknameModule:SetDefaultNicknames(defaults)

                EnsureDB()
                local localVersion = ACT.db.profile.dataVersion or 0
                if accumulation.version > localVersion then
                    ACT.db.profile.dataVersion = accumulation.version
                end

                NicknameModule.hasReceivedWAData = true
            end
        end
        NicknameModule.waMessageAccumulator[sender] = nil
        if NicknameModule.waMessageTimer[sender] then
            C_Timer.Cancel(NicknameModule.waMessageTimer[sender])
            NicknameModule.waMessageTimer[sender] = nil
        end
    elseif string.sub(message, 1, 5) == "DATA:" then
        local accumulation = NicknameModule.waMessageAccumulator[sender]
        if accumulation then
            local chunk = string.sub(message, 6)
            accumulation.data = accumulation.data .. chunk
        end
    end
end

AceComm:RegisterComm(COMM_PREFIX, ReceiveRegularComm)
local waEventFrame = CreateFrame("Frame")
waEventFrame:RegisterEvent("CHAT_MSG_ADDON")
waEventFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    ReceiveWAComm(prefix, message, channel, sender)
end)

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

        local incomingVersion = 0
        local payload = data
        local versionStr, payloadStr = strsplit(DELIMITER, data, 2)
        if tonumber(versionStr) and payloadStr then
            incomingVersion = tonumber(versionStr)
            payload = payloadStr
        else
            payload = data
        end

        local decompressed = LibDeflate:DecompressDeflate(LibDeflate:DecodeForWoWAddonChannel(payload))
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
                local btag, nickname = parts[1], parts[2]
                if type(btag) == "string" and btag:match(BTAG_REGEX) and type(nickname) == "string" then
                    playersData[btag] = {
                        nickname = nickname,
                        characters = {}
                    }
                    local charStr = parts[3]
                    if charStr and charStr ~= "" then
                        for char in string.gmatch(charStr, "[^,]+") do
                            playersData[btag].characters[char] = true
                        end
                    end
                end
            end
        end
        if next(playersData) then
            self:MergeData(playersData, incomingVersion)
        end
    elseif event == "NICK_REQUEST" then
        self:BroadcastMyDatabase(channel)
    elseif event == "NICK_KILLSWITCH" then
        EnsureDB()
        ACT.db.profile.players = {}
        ACT.db.profile.dataVersion = 0
        if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
            NicknameAPI.RefreshAllIntegrations()
        end
        if self.configPanel and self.configPanel:IsShown() then
            self:RefreshContent()
        end
        if not self.killswitchPopup then
            if not _G.UI then
                return
            end
            self.killswitchPopup = _G.UI:CreateTextPopup("Killswitch Activated", sender ..
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

function NicknameModule:MergeData(incomingPlayers, incomingVersion)
    local hasChanged = false
    EnsureDB()
    local myBattleTag = GetPlayerBattleTag()
    local localVersion = ACT.db.profile.dataVersion or 0

    for btag, incomingData in pairs(incomingPlayers) do
        local localData = ACT.db.profile.players[btag]

        if not localData then
            if incomingVersion >= localVersion and (not self.hasReceivedWAData or self.defaultNicknames[btag]) then
                ACT.db.profile.players[btag] = incomingData
                hasChanged = true
            end
        else
            local defaultNick = self.defaultNicknames[btag]
            local hasLocalChange = false

            if defaultNick then
                if localData.nickname ~= defaultNick then
                    localData.nickname = defaultNick
                    hasLocalChange = true
                end
            elseif incomingVersion >= localVersion and btag ~= myBattleTag and incomingData.nickname and
                incomingData.nickname ~= "" and localData.nickname ~= incomingData.nickname then
                localData.nickname = incomingData.nickname
                hasLocalChange = true
            end

            if incomingData.characters then
                if not localData.characters then
                    localData.characters = {}
                end
                for charFullName, _ in pairs(incomingData.characters) do
                    if not localData.characters[charFullName] then
                        localData.characters[charFullName] = true
                        hasLocalChange = true
                    end
                end
            end

            if hasLocalChange then
                hasChanged = true
            end
        end
    end

    if hasChanged then
        if incomingVersion > localVersion then
            ACT.db.profile.dataVersion = incomingVersion
        end
        if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
            C_Timer.After(0.1, NicknameAPI.RefreshAllIntegrations)
        end
        if self.configPanel and self.configPanel:IsShown() then
            self:RefreshContent()
        end
    end
end

function NicknameModule:CompareCharacterTables(t1, t2)
    if #t1 ~= #t2 then
        return false
    end
    for k, v in pairs(t1) do
        if not t2[k] then
            return false
        end
    end
    return true
end

function NicknameModule:CleanBrick()
    EnsureDB()
    local players = ACT.db.profile.players
    if not players then
        return
    end

    local corruptedKeys = {}

    for btag, _ in pairs(players) do
        if type(btag) ~= "string" or not btag:match(BTAG_REGEX) then
            table.insert(corruptedKeys, btag)
        end
    end

    if #corruptedKeys > 0 then
        for _, key in ipairs(corruptedKeys) do
            players[key] = nil
        end

        if self.configPanel and self.configPanel:IsShown() then
            self:RefreshContent()
        end
    end
end

function NicknameModule:OnPlayerLogin()
    C_Timer.After(2, function()
        self:CleanBrick()
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
        if not playerRecord then
            ACT.db.profile.players[myBattleTag] = {
                nickname = "",
                characters = {
                    [myFullName] = true
                }
            }
        elseif not playerRecord.characters or not playerRecord.characters[myFullName] then
            if not playerRecord.characters then
                playerRecord.characters = {}
            end
            playerRecord.characters[myFullName] = true
        end

        self:BroadcastMyDatabaseToAll()

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

function NicknameModule:OnSaveNickname()
    local myBattleTag = GetPlayerBattleTag()
    if not myBattleTag then
        return
    end

    if self.defaultNicknames[myBattleTag] then
        print("|cffFF0000[ACT]|r Your nickname is managed by the default list and cannot be changed here.")
        self.myNickBoxEdit:SetText(self.defaultNicknames[myBattleTag])
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
    ACT.db.profile.dataVersion = (ACT.db.profile.dataVersion or 0) + 1
    self:BroadcastMyDatabaseToAll()
    if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
        NicknameAPI.RefreshAllIntegrations()
    end
    self:RefreshContent()
end

function NicknameModule:OnIntegrationCheckboxClick(checkbox)
    ACT.db.profile.useNicknameIntegration = checkbox:GetChecked()
    self:PromptReloadNormal()
end

function NicknameModule:OnStreamerCheckboxClick(checkbox)
    ACT.db.profile.streamerMode = checkbox:GetChecked()
    self:RefreshContent()
end

function NicknameModule:CreateConfigPanel(parent)
    if not _G.UI then
        return
    end

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
    myNickLabel:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -20)
    myNickLabel:SetText("My Nickname")

    local myNickBoxFrame, myNickBoxEdit = _G.UI:CreateMultilineEditBox(configPanel, 250, 30, "")
    myNickBoxFrame:SetPoint("TOPLEFT", myNickLabel, "BOTTOMLEFT", 0, -5)
    self.myNickBoxEdit = myNickBoxEdit

    local saveNickButton = _G.UI:CreateButton(configPanel, "Save", 100, 30, function()
        self:OnSaveNickname()
    end)
    saveNickButton:SetPoint("LEFT", myNickBoxFrame, "RIGHT", 10, 0)

    local integrationCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    integrationCheckbox:SetPoint("TOPLEFT", myNickBoxFrame, "BOTTOMLEFT", 0, -15)
    integrationCheckbox:SetScript("OnClick", function(self)
        NicknameModule:OnIntegrationCheckboxClick(self)
    end)
    integrationCheckbox.Text:SetText("Show Nicknames on Raid Frames")

    local streamerCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    streamerCheckbox:SetPoint("TOP", integrationCheckbox, "BOTTOM", 0, -5)
    streamerCheckbox:SetScript("OnClick", function(self)
        NicknameModule:OnStreamerCheckboxClick(self)
    end)
    streamerCheckbox.Text:SetText("Streamer Mode")

    integrationCheckbox:SetSize(22, 22)
    integrationCheckbox.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    integrationCheckbox.Text:ClearAllPoints()
    integrationCheckbox.Text:SetPoint("LEFT", integrationCheckbox, "RIGHT", 5, 0)
    integrationCheckbox:SetChecked(ACT.db.profile.useNicknameIntegration)

    streamerCheckbox:SetSize(22, 22)
    streamerCheckbox.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    streamerCheckbox.Text:ClearAllPoints()
    streamerCheckbox.Text:SetPoint("LEFT", streamerCheckbox, "RIGHT", 5, 0)
    streamerCheckbox:SetChecked(ACT.db.profile.streamerMode)

    local headerFrame = CreateFrame("Frame", nil, configPanel)
    headerFrame:SetSize(520, 20)
    headerFrame:SetPoint("TOPLEFT", streamerCheckbox, "BOTTOMLEFT", 0, -15)

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
        local nukeLocalBtn = _G.UI:CreateButton(debugFrame, "Nuke Local", 135, 30, function()
            SlashCmdList["WIPENICKNAMES"]("")
        end)

        nukeLocalBtn:SetPoint("TOP", title, "BOTTOM", 0, -5)
        local nukeAllBtn = _G.UI:CreateButton(debugFrame, "Nuke ALL", 135, 30, function()
            SlashCmdList["ACTKILLSWITCH"]("")
        end)

        nukeAllBtn:SetPoint("TOP", nukeLocalBtn, "BOTTOM", 0, -5)
    end

    self:RefreshContent()
    return configPanel
end

function NicknameModule:PromptReloadNormal()
    local UI = _G.UI
    if not UI then
        return
    end
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

    local UI = _G.UI
    if not UI then
        return
    end

    for _, child in ipairs({self.scrollChild:GetChildren()}) do
        child:Hide()
        table.insert(self.rowPool, child)
    end
    self.scrollChild:SetHeight(0)

    local myBattleTag = GetPlayerBattleTag()
    if myBattleTag and ACT.db.profile.players[myBattleTag] and self.myNickBoxEdit then
        self.myNickBoxEdit:SetText(ACT.db.profile.players[myBattleTag].nickname or "")
        if self.defaultNicknames[myBattleTag] then
            self.myNickBoxEdit:EnableMouse(false)
            self.myNickBoxEdit:SetTextColor(0.5, 0.5, 0.5)
        else
            self.myNickBoxEdit:EnableMouse(true)
            self.myNickBoxEdit:SetTextColor(1, 1, 1)
        end
    elseif self.myNickBoxEdit then
        self.myNickBoxEdit:SetText("")
    end

    local sortedPlayers = {}
    if ACT.db.profile.players then
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
    end

    local yOffset = -10
    local isStreamerMode = ACT.db.profile.streamerMode
    for _, playerData in ipairs(sortedPlayers) do
        local btag = playerData.btag
        local data = ACT.db.profile.players[btag]

        local row = table.remove(self.rowPool)
        if not row then
            row = CreateFrame("Frame", nil, self.scrollChild, "BackdropTemplate")
            row:SetSize(470, 30)
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1
            })
            row:SetBackdropColor(0.15, 0.15, 0.15, 1)
            row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

            row.deletePlayerBtn = UI:CreateButton(row, "X", 20, 20)

            row.nickLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nickLabel:SetPoint("LEFT", 5, 8)
            row.nickLabel:SetSize(200, 15)
            row.nickLabel:SetJustifyH("LEFT")

            row.btagLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.btagLabel:SetPoint("TOPLEFT", row.nickLabel, "BOTTOMLEFT", 0, -2)
            row.btagLabel:SetSize(200, 10)
            row.btagLabel:SetJustifyH("LEFT")

            row.dropdown = UI:CreateDropdown(row, 200, 30)
            row.dropdown:SetPoint("LEFT", row.nickLabel, "RIGHT", -50, -8)

            row.deleteCharBtn = UI:CreateButton(row, "Delete Character", 100, 20)
            row.deleteCharBtn:SetPoint("LEFT", row.dropdown, "RIGHT", 5, 0)
        end

        row:SetParent(self.scrollChild)
        row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 25, yOffset)
        row:Show()

        row.deletePlayerBtn:ClearAllPoints()
        row.deletePlayerBtn:SetPoint("LEFT", row, "LEFT", -25, 0)

        row.deletePlayerBtn:SetScript("OnClick", function()
            self:HandleDeletePlayer(btag, isStreamerMode, data)
        end)

        if self.defaultNicknames[btag] then
            row.nickLabel:SetTextColor(0.8, 0.6, 0.1)
        else
            row.nickLabel:SetTextColor(1, 1, 1)
        end

        if isStreamerMode then
            row.nickLabel:SetText(data.nickname or "Please Subscribe!")
            row.btagLabel:SetText("Please Subscribe!")
        else
            row.nickLabel:SetText(data.nickname or btag)
            row.btagLabel:SetText(btag)
        end

        local options = {}
        if data.characters then
            for fullName, _ in pairs(data.characters) do
                table.insert(options, {
                    text = self:GetFormattedCharacterName(fullName),
                    value = fullName
                })
            end
        end
        UI:SetDropdownOptions(row.dropdown, options)
        row.dropdown.button.text:SetText("Select Character")

        row.deleteCharBtn:SetScript("OnClick", function()
            self:HandleDeleteCharacter(row.dropdown, data)
        end)

        yOffset = yOffset - 40
    end
    self.scrollChild:SetHeight(math.abs(yOffset) + 10)
end

function NicknameModule:HandleDeletePlayer(btag, isStreamerMode, data)
    local UI = _G.UI
    if not UI then
        return
    end
    if self.deleteConfirmationPopup and self.deleteConfirmationPopup:IsShown() then
        return
    end

    local displayName = isStreamerMode and (data.nickname or "this player") or btag
    local popup = UI:CreateTextPopup("Confirm Delete", "Delete all data for " .. displayName .. "?", "Delete", "Cancel",
        function()
            ACT.db.profile.players[btag] = nil
            if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
                NicknameAPI.RefreshAllIntegrations()
            end
            self:RefreshContent()
            self.deleteConfirmationPopup = nil
        end, function()
            self.deleteConfirmationPopup = nil
        end)
    popup:SetScript("OnHide", function()
        self.deleteConfirmationPopup = nil
    end)
    self.deleteConfirmationPopup = popup
    popup:Show()
end

function NicknameModule:HandleDeleteCharacter(dropdown, data)
    if dropdown.selectedValue and data.characters and data.characters[dropdown.selectedValue] then
        data.characters[dropdown.selectedValue] = nil
        if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
            NicknameAPI.RefreshAllIntegrations()
        end
        self:RefreshContent()
        self:BroadcastMyDatabaseToAll()
    end
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
    local UI = _G.UI
    if not UI then
        return
    end
    if not NicknameModule.wipePopup then
        NicknameModule.wipePopup = UI:CreateTextPopup("Confirm Wipe",
            "Are you sure you want to wipe all your local nicknames? This cannot be undone.", "Yes, Wipe", "Cancel",
            function()
                EnsureDB()
                ACT.db.profile.players = {}
                ACT.db.profile.dataVersion = 0
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
    local UI = _G.UI
    if not UI then
        return
    end
    if not NicknameModule.killConfirmPopup then
        NicknameModule.killConfirmPopup = UI:CreateTextPopup("Confirm Killswitch",
            "Are you sure you want to trigger the killswitch? This will wipe ALL nicknames for everyone in your group/guild.",
            "Yes, Killswitch", "Cancel", function()
                local dist = IsInRaid() and "RAID" or (IsInGuild() and "GUILD" or (IsInGroup() and "PARTY"))
                if dist then
                    NicknameModule:Broadcast("NICK_KILLSWITCH", dist)
                    NicknameModule:EventHandler("NICK_KILLSWITCH", GetPlayerBattleTag(), "SELF")
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
