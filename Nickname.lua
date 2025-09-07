local NicknameModule = {}

NicknameModule.title = "Nicknames"
NicknameModule.isInitialized = false
NicknameModule.lastUpdateMessageTime = 0
NicknameModule.waMessageAccumulator = {}
NicknameModule.waMessageTimer = {}
NicknameModule.rowPool = {}
NicknameModule.activePopup = nil
NicknameModule.authoritativeData = {}

if not NicknameAPI then NicknameAPI = {} end

NicknameModule.localWAVersion = "N/A"

function NicknameAPI.RegisterWAVersion(version)
    if type(version) == "number" then
        NicknameModule.localWAVersion = version
    end
end

local TOMBSTONE_LIFETIME_SECONDS = 7776000

local AceComm = LibStub("AceComm-3.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local COMM_PREFIX = "NICK_MSG_ADNC"
local COMM_PREFIX_WA = "WA_NICK_ADV"
local COMM_PREFIX_VER = "WA_VER_ADV"
local DELIMITER = "~"

local BTAG_REGEX = "^[^#:|;@]+#%d+$"

local privilegedList = {
    ["Isogi#21124"] = true,
    ["Jafar#21190"] = true,
    ["ViklunD#2904"] = true,
    ["Strike#2545"] = true
}

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
    if not ACT.db.profile.localHideList then
        ACT.db.profile.localHideList = {}
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
    if ACT.db.profile.guildOnlyMode == nil then
        ACT.db.profile.guildOnlyMode = true
    end
    if ACT.db.profile.strictMode == nil then
        ACT.db.profile.strictMode = true
    end
end
EnsureDB()

NicknameModule.playerBattleTag = nil

function NicknameModule:GenerateSimpleHash(str)
    local hash = 5381
    for i = 1, #str do
        hash = (hash * 33) + string.byte(str, i)
        hash = bit.band(hash, 0xFFFFFFFF)
    end
    return hash
end

function NicknameModule:GenerateDatabaseChecksum()
    EnsureDB()
    local players = ACT.db.profile.players
    if not players or not next(players) then
        return 0
    end

    local sortedBtags = {}
    for btag in pairs(players) do
        table.insert(sortedBtags, btag)
    end
    table.sort(sortedBtags)

    local dataString = ""
    for _, btag in ipairs(sortedBtags) do
        local pData = players[btag]
        dataString = dataString .. btag .. "|" .. (pData.nickname or "nil") .. "|"
        if pData.characters and next(pData.characters) then
            local sortedChars = {}
            for charName, charData in pairs(pData.characters) do
                if not charData.deleted then
                    table.insert(sortedChars, charName)
                end
            end
            table.sort(sortedChars)
            dataString = dataString .. table.concat(sortedChars, ",")
        end
        dataString = dataString .. ";"
    end
    return self:GenerateSimpleHash(dataString)
end

local function strtrim(s)
    return s and s:match("^%s*(.-)%s*$") or ""
end

local myRealmName
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
    local charName, charRealm = fullName:match("^(.*)-([^-]+)$")
    if charRealm and charRealm == GetMyRealm() then
        return charName
    else
        return fullName
    end
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

function IsPrivilegedUser()
    local btag = GetPlayerBattleTag()
    return btag and privilegedList[btag]
end

function NicknameModule:IsValidCharacterFormat(fullName)
    return type(fullName) == "string" and fullName:find("-")
end

local function GetGroupChannel()
    if UnitInRaid("player") then
        return "RAID"
    elseif UnitInParty("player") and GetNumGroupMembers() > 0 then
        return "PARTY"
    end
    return nil
end

function NicknameModule:Broadcast(event, channel, ...)
    if InCombatLockdown() then
        return
    end
    if not channel then
        return
    end
    EnsureDB()
    if ACT.db.profile.guildOnlyMode and channel ~= "GUILD" then
        return
    end

    local message = event .. DELIMITER ..
        LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(LibSerialize:Serialize({ ... })))
    AceComm:SendCommMessage(COMM_PREFIX, message, channel)
end

local function ReceiveComm(prefix, message, channel, sender)
    if InCombatLockdown() then
        return
    end
    if not NicknameModule.isInitialized or prefix ~= COMM_PREFIX then
        return
    end

    local event, payload = strsplit(DELIMITER, message, 2)
    if not event or not payload then
        return
    end

    EnsureDB()
    local canProcess = false
    if ACT.db.profile.guildOnlyMode then
        if channel == "GUILD" then
            canProcess = true
        end
    else
        if (UnitExists(sender) and (UnitInRaid(sender) or UnitInParty(sender))) or (channel == "GUILD") then
            canProcess = true
        end
    end

    if canProcess then
        local decompressed = LibDeflate:DecompressDeflate(LibDeflate:DecodeForWoWAddonChannel(payload))
        if not decompressed then
            return
        end
        local success, args = LibSerialize:Deserialize(decompressed)
        if success and type(args) == "table" then
            NicknameModule:EventHandler(event, sender, channel, unpack(args))
        end
    end
end
AceComm:RegisterComm(COMM_PREFIX, ReceiveComm)

local function ReceiveVersionComm(prefix, message, channel, sender)
    if InCombatLockdown() or prefix ~= COMM_PREFIX_VER then return end

    local event, payload = strsplit(DELIMITER, message, 2)
    if not event or not payload then return end

    local decompressed = LibDeflate:DecompressDeflate(LibDeflate:DecodeForWoWAddonChannel(payload))
    if not decompressed then return end

    local success, args = LibSerialize:Deserialize(decompressed)
    if not success or type(args) ~= "table" then return end

    if event == "VER_REQ" then
        local myVersion = NicknameModule.localWAVersion or "N/A"
        local myBtag = GetPlayerBattleTag()
        if not myBtag then return end

        local reply_message = "VER_RES" ..
            DELIMITER ..
            LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(LibSerialize:Serialize({ myVersion, myBtag })))
        AceComm:SendCommMessage(COMM_PREFIX_VER, reply_message, "WHISPER", sender)
    elseif event == "VER_RES" then
        local version, btag = unpack(args)
        if NicknameModule.waVersionData and type(version) ~= 'nil' and type(btag) == 'string' then
            NicknameModule.waVersionData[btag] = { version = version, sender = sender }
            if NicknameModule.activePopup and NicknameModule.activePopup.isVersionCheckPopup then
                NicknameModule:RefreshVersionCheckPopupContent()
            end
        end
    end
end

AceComm:RegisterComm(COMM_PREFIX_VER, ReceiveVersionComm)

function NicknameModule:BroadcastVersionCheck(event, channel, ...)
    if InCombatLockdown() or not channel then return end
    local message = event ..
        DELIMITER .. LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(LibSerialize:Serialize({ ... })))
    AceComm:SendCommMessage(COMM_PREFIX_VER, message, channel)
end

function NicknameModule:BroadcastFullDatabase(channel)
    EnsureDB()
    local dataToSend = ACT.db.profile.players
    if not dataToSend or not next(dataToSend) then
        return
    end

    local version = ACT.db.profile.dataVersion or 0
    local myBtag = GetPlayerBattleTag()
    if not myBtag then
        return
    end

    self:Broadcast("NICK_DATABASE_RESPONSE", channel, version, myBtag, dataToSend)
end

function NicknameModule:BroadcastSyncRequest()
    local groupChannel = GetGroupChannel()
    EnsureDB()
    local myVersion = ACT.db.profile.dataVersion or 0
    local myChecksum = self:GenerateDatabaseChecksum()

    if groupChannel then
        self:Broadcast("NICK_SYNC_REQUEST", groupChannel, myVersion, myChecksum)
    end
    self:Broadcast("NICK_SYNC_REQUEST", "GUILD", myVersion, myChecksum)
end

function NicknameModule:BroadcastSelfUpdate()
    local myBtag = GetPlayerBattleTag()
    if not myBtag or not ACT.db.profile.players[myBtag] then
        return
    end

    local groupChannel = GetGroupChannel()
    local payload = ACT.db.profile.players[myBtag]

    if groupChannel then
        self:Broadcast("NICK_PLAYER_UPDATE", groupChannel, myBtag, payload)
    end
    self:Broadcast("NICK_PLAYER_UPDATE", "GUILD", myBtag, payload)
end

function NicknameModule:EventHandler(event, sender, channel, ...)
    if event == "NICK_SYNC_REQUEST" then
        local incomingVersion, incomingChecksum = ...
        EnsureDB()
        local myVersion = ACT.db.profile.dataVersion or 0
        local myChecksum = self:GenerateDatabaseChecksum()

        if myVersion > incomingVersion or (myVersion == incomingVersion and myChecksum ~= incomingChecksum) then
            self:BroadcastFullDatabase(channel)
        end
    elseif event == "NICK_DATABASE_RESPONSE" then
        local incomingVersion, senderBtag, incomingPlayers = ...
        if type(incomingVersion) == 'number' and type(senderBtag) == 'string' and type(incomingPlayers) == 'table' then
            self:MergeData(incomingVersion, senderBtag, incomingPlayers)
        end
    elseif event == "NICK_PLAYER_UPDATE" then
        local btag, playerData = ...
        if type(btag) == 'string' and type(playerData) == 'table' then
            self:MergeData(99999999, sender, {
                [btag] = playerData
            })
        end
    elseif event == "NICK_REQUEST" then
        self:BroadcastFullDatabase(channel)
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
            if not UI then
                return
            end
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

function NicknameModule:OnPlayerLogin()
    self:CleanBrick()
    self:PruneOldData()
    GetMyRealm()
    local myBattleTag = GetPlayerBattleTag()
    local myCharName = UnitName("player")
    if not myCharName then
        return
    end
    local myFullName = myCharName .. "-" .. GetMyRealm()

    EnsureDB()

    if myBattleTag then
        local playerRecord = ACT.db.profile.players[myBattleTag]
        if not playerRecord then
            playerRecord = {
                nickname = "",
                characters = {}
            }
            ACT.db.profile.players[myBattleTag] = playerRecord
        end
        if not playerRecord.characters then
            playerRecord.characters = {}
        end

        playerRecord.characters[myFullName] = {
            deleted = false,
            timestamp = GetServerTime()
        }
    end

    self:BroadcastSyncRequest()
    self.isInitialized = true
end

function NicknameModule:MergeData(incomingVersion, senderBtag, incomingPlayers)
    local hasChanged = false
    EnsureDB()
    local myBattleTag = GetPlayerBattleTag()
    local localVersion = ACT.db.profile.dataVersion or 0

    if incomingVersion < localVersion then
        return
    end

    for btag, incomingData in pairs(incomingPlayers) do
        local localData = ACT.db.profile.players[btag]

        if not localData then
            if not ACT.db.profile.strictMode or (self.authoritativeData and self.authoritativeData[btag]) then
                ACT.db.profile.players[btag] = incomingData
                hasChanged = true
            end
        else
            local hasLocalChange = false
            if btag ~= myBattleTag and incomingData.nickname and incomingData.nickname ~= "" and localData.nickname ~=
                incomingData.nickname then
                localData.nickname = incomingData.nickname
                hasLocalChange = true
            end

            if incomingData.characters and type(incomingData.characters) == "table" then
                if not localData.characters then
                    localData.characters = {}
                end
                for charFullName, incomingCharData in pairs(incomingData.characters) do
                    if self:IsValidCharacterFormat(charFullName) then
                        local localCharData = localData.characters[charFullName]

                        if type(localCharData) == "boolean" then
                            localCharData = {
                                deleted = false,
                                timestamp = 0
                            }
                            localData.characters[charFullName] = localCharData
                        end
                        if type(incomingCharData) == "boolean" then
                            incomingCharData = {
                                deleted = false,
                                timestamp = 0
                            }
                        end

                        if type(incomingCharData) == "table" then
                            if not localCharData or
                                (type(localCharData) == "table" and incomingCharData.timestamp >
                                    (localCharData.timestamp or 0)) then
                                if incomingCharData.deleted and not privilegedList[senderBtag] then
                                else
                                    localData.characters[charFullName] = incomingCharData
                                    hasLocalChange = true
                                end
                            end
                        end
                    end
                end
            end
            if hasLocalChange then
                hasChanged = true
            end
        end
    end

    if hasChanged then
        if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
            C_Timer.After(0.1, NicknameAPI.RefreshAllIntegrations)
        end
        if self.configPanel and self.configPanel:IsShown() then
            self:RefreshContent()
        end
    end
end

function NicknameModule:PruneOldData()
    EnsureDB()
    local players = ACT.db.profile.players
    if not players then
        return
    end
    local hasChanged = false
    local currentTime = GetServerTime()
    local allKnownChars = {}

    for btag, data in pairs(players) do
        if data and data.characters and type(data.characters) == "table" then
            local charsToPrune = {}
            for charFullName, charData in pairs(data.characters) do
                if type(charData) == "boolean" or
                    (type(charData) == "table" and (not charData.timestamp or charData.timestamp == 0)) then
                    data.characters[charFullName] = {
                        deleted = (type(charData) == "table" and charData.deleted) or false,
                        timestamp = currentTime
                    }
                    charData = data.characters[charFullName]
                    hasChanged = true
                end

                if type(charData) == "table" and charData.deleted == true then
                    if (currentTime - charData.timestamp) > TOMBSTONE_LIFETIME_SECONDS then
                        table.insert(charsToPrune, charFullName)
                        hasChanged = true
                    else
                        allKnownChars[charFullName] = true
                    end
                else
                    allKnownChars[charFullName] = true
                end
            end
            for _, key in ipairs(charsToPrune) do
                data.characters[key] = nil
            end
        end
    end

    if ACT.db.profile.localHideList then
        local hideListToPrune = {}
        for charFullName, _ in pairs(ACT.db.profile.localHideList) do
            if not allKnownChars[charFullName] then
                table.insert(hideListToPrune, charFullName)
                hasChanged = true
            end
        end
        for _, key in ipairs(hideListToPrune) do
            ACT.db.profile.localHideList[key] = nil
        end
    end

    if hasChanged and self.configPanel and self.configPanel:IsShown() then
        self:RefreshContent()
    end
end

function NicknameModule:CleanBrick()
    EnsureDB()
    local players = ACT.db.profile.players
    if not players then
        return
    end
    local hasChanged = false
    for btag, data in pairs(players) do
        if type(btag) ~= "string" or not btag:match(BTAG_REGEX) then
            players[btag] = nil
            hasChanged = true
        elseif data and data.characters and type(data.characters) == "table" then
            local corruptedChars = {}
            for charFullName, charData in pairs(data.characters) do
                if not self:IsValidCharacterFormat(charFullName) or
                    (type(charData) ~= "table" and type(charData) ~= "boolean") then
                    table.insert(corruptedChars, charFullName)
                    hasChanged = true
                end
            end
            for _, key in ipairs(corruptedChars) do
                data.characters[key] = nil
            end
        end
    end
    if hasChanged and self.configPanel and self.configPanel:IsShown() then
        self:RefreshContent()
    end
end

function NicknameModule:OnSaveNickname()
    local myBattleTag = GetPlayerBattleTag()
    if not myBattleTag then
        return
    end

    if self.authoritativeData and self.authoritativeData[myBattleTag] then
        self.myNickBoxEdit:SetText(self.authoritativeData[myBattleTag])
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

    self:BroadcastSelfUpdate()

    if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
        NicknameAPI.RefreshAllIntegrations()
    end
    self:RefreshContent()
end

function NicknameModule:HandleHideCharacter(dropdown, data)
    if dropdown.selectedValue then
        EnsureDB()
        ACT.db.profile.localHideList[dropdown.selectedValue] = true
        self:RefreshContent()
    end
end

function NicknameModule:HandleAuthDelete(btag, charsToDelete)
    EnsureDB()
    local playerData = ACT.db.profile.players[btag]
    if not playerData or not playerData.characters then
        return
    end

    local hasDeleted = false
    local currentTime = GetServerTime()
    for _, charFullName in ipairs(charsToDelete) do
        if playerData.characters[charFullName] then
            playerData.characters[charFullName] = {
                deleted = true,
                timestamp = currentTime
            }
            hasDeleted = true
        end
    end

    if hasDeleted then
        self:BroadcastSelfUpdate()
        if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
            NicknameAPI.RefreshAllIntegrations()
        end
        self:RefreshContent()
    end
end

function NicknameModule:HandleDeletePlayer(btag, isStreamerMode, data)
    if not UI then
        return
    end
    if self.deleteConfirmationPopup and self.deleteConfirmationPopup:IsShown() then
        return
    end
    local displayName = isStreamerMode and (data.nickname or "this player") or btag
    local popup = UI:CreateTextPopup("Confirm Local Delete", "Locally delete all data for " .. displayName ..
        "? This will not affect other users.", "Delete Locally", "Cancel", function()
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

function NicknameModule:GetConfigSize()
    return 800, 600
end

function NicknameModule:CreateConfigPanel(parent)
    if not UI then
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

    local myNickBoxFrame, myNickBoxEdit = UI:CreateMultilineEditBox(configPanel, 250, 30, "")
    myNickBoxFrame:SetPoint("TOPLEFT", myNickLabel, "BOTTOMLEFT", 0, -5)
    self.myNickBoxEdit = myNickBoxEdit

    local saveNickButton = UI:CreateButton(configPanel, "Save", 100, 30, function()
        self:OnSaveNickname()
    end)
    saveNickButton:SetPoint("LEFT", myNickBoxFrame, "RIGHT", 10, 0)
    self.saveNickButton = saveNickButton

    local manageHiddenBtn = UI:CreateButton(configPanel, "Manage Hidden", 120, 30, function()
        self:CreateManageHiddenPopup()
    end)
    manageHiddenBtn:SetPoint("LEFT", saveNickButton, "RIGHT", 10, 0)

    local integrationCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    integrationCheckbox:SetPoint("TOPLEFT", myNickBoxFrame, "BOTTOMLEFT", 0, -15)
    integrationCheckbox:SetScript("OnClick", function(self)
        ACT.db.profile.useNicknameIntegration = self:GetChecked()
        NicknameModule:PromptReloadNormal()
    end)
    integrationCheckbox.Text:SetText("Show Nicknames on Raid Frames")

    local streamerCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    streamerCheckbox:SetPoint("TOP", integrationCheckbox, "BOTTOM", 0, -5)
    streamerCheckbox:SetScript("OnClick", function(self)
        ACT.db.profile.streamerMode = self:GetChecked()
        NicknameModule:RefreshContent()
    end)
    streamerCheckbox.Text:SetText("Streamer Mode")

    for _, cb in ipairs({ integrationCheckbox, streamerCheckbox }) do
        cb:SetSize(22, 22)
        cb.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        cb.Text:ClearAllPoints()
        cb.Text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    end
    integrationCheckbox:SetChecked(ACT.db.profile.useNicknameIntegration)
    streamerCheckbox:SetChecked(ACT.db.profile.streamerMode)

    local guildOnlyCheckbox = CreateFrame("CheckButton", nil, configPanel, "UICheckButtonTemplate")
    guildOnlyCheckbox:SetPoint("TOP", streamerCheckbox, "BOTTOM", 0, -5)
    guildOnlyCheckbox:SetScript("OnClick", function(self)
        ACT.db.profile.guildOnlyMode = self:GetChecked()
    end)
    guildOnlyCheckbox.Text:SetText("Only Sync Nicknames with Guild")
    guildOnlyCheckbox:SetSize(22, 22);
    guildOnlyCheckbox.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE");
    guildOnlyCheckbox.Text:ClearAllPoints();
    guildOnlyCheckbox.Text:SetPoint("LEFT", guildOnlyCheckbox, "RIGHT", 5, 0);
    guildOnlyCheckbox:SetChecked(ACT.db.profile.guildOnlyMode)

    local headerFrame = CreateFrame("Frame", nil, configPanel);
    headerFrame:SetSize(520, 20);
    headerFrame:SetPoint("TOPLEFT", guildOnlyCheckbox, "BOTTOMLEFT", 0, -15)
    local nicknameHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    nicknameHeader:SetPoint("LEFT", headerFrame, "LEFT", 25, -10);
    nicknameHeader:SetText("Nickname")
    local charHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    charHeader:SetPoint("LEFT", headerFrame, "LEFT", 180, -10);
    charHeader:SetText("Known Characters")
    local actionsHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    actionsHeader:SetPoint("LEFT", headerFrame, "LEFT", 380, -10);
    actionsHeader:SetText("Actions")

    local scrollFrame = CreateFrame("ScrollFrame", nil, configPanel, "UIPanelScrollFrameTemplate");
    scrollFrame:SetSize(520, 325);
    scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -10)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame);
    scrollChild:SetSize(500, 325);
    scrollFrame:SetScrollChild(scrollChild);
    self.scrollChild = scrollChild

    if IsPrivilegedUser() then
        local debugFrame = CreateFrame("Frame", "DebugToolsFrame", configPanel, "BackdropTemplate");
        debugFrame:SetSize(165, 170);
        debugFrame:SetPoint("TOPLEFT", configPanel, "TOPRIGHT", -213, 40)
        debugFrame.bg = debugFrame:CreateTexture(nil, "BACKGROUND");
        debugFrame.bg:SetAllPoints();
        debugFrame.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
        debugFrame.border = CreateFrame("Frame", nil, debugFrame, "BackdropTemplate");
        debugFrame.border:SetAllPoints();
        debugFrame.border:SetBackdrop({
            edgeFile = "Interface\\AddOns\\ACT\\media\\border",
            edgeSize = 8
        })
        local title = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
        title:SetPoint("TOP", 0, -10);
        title:SetText("DEBUG TOOLS")
        local authDeleteBtn = UI:CreateButton(debugFrame, "Auth Delete", 135, 30, function()
            self:CreateAuthDeletePopup()
        end)
        authDeleteBtn:SetPoint("TOP", title, "BOTTOM", 0, -5)
        local nukeLocalBtn = UI:CreateButton(debugFrame, "Nuke Local", 135, 30, function()
            SlashCmdList["WIPENICKNAMES"]("")
        end)
        nukeLocalBtn:SetPoint("TOP", authDeleteBtn, "BOTTOM", 0, -5)
        local nukeAllBtn = UI:CreateButton(debugFrame, "Nuke ALL", 135, 30, function()
            SlashCmdList["ACTKILLSWITCH"]("")
        end)
        nukeAllBtn:SetPoint("TOP", nukeLocalBtn, "BOTTOM", 0, -5)
        local versionCheckBtn = UI:CreateButton(debugFrame, "Check Versions", 135, 30, function()
            self:CreateVersionCheckPopup()
        end)
        versionCheckBtn:SetPoint("TOP", nukeAllBtn, "BOTTOM", 0, -5)
    end

    self:RefreshContent()
    return configPanel
end

function NicknameModule:RefreshContent()
    if not self.scrollChild or not UI then
        return
    end

    for _, child in ipairs({ self.scrollChild:GetChildren() }) do
        child:Hide()
        table.insert(self.rowPool, child)
    end
    self.scrollChild:SetHeight(0)

    local myBattleTag = GetPlayerBattleTag()
    if myBattleTag and self.myNickBoxEdit and self.saveNickButton then
        if ACT.db.profile.players[myBattleTag] then
            self.myNickBoxEdit:SetText(ACT.db.profile.players[myBattleTag].nickname or "")
        else
            self.myNickBoxEdit:SetText("")
        end

        if self.authoritativeData and self.authoritativeData[myBattleTag] then
            self.myNickBoxEdit:SetEnabled(false)
            self.myNickBoxEdit:SetTextColor(0.5, 0.5, 0.5)
            self.saveNickButton:Disable()
        else
            self.myNickBoxEdit:SetEnabled(true)
            self.myNickBoxEdit:SetTextColor(1, 1, 1)
            self.saveNickButton:Enable()
        end
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
            row = CreateFrame("Frame", nil, self.scrollChild, "BackdropTemplate");
            row:SetSize(470, 30);
            row:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1
            });
            row:SetBackdropColor(0.15, 0.15, 0.15, 1);
            row:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            row.deletePlayerBtn = UI:CreateButton(row, "X", 20, 20)
            row.nickLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal");
            row.nickLabel:SetPoint("LEFT", 5, 8);
            row.nickLabel:SetSize(200, 15);
            row.nickLabel:SetJustifyH("LEFT")
            row.btagLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
            row.btagLabel:SetPoint("TOPLEFT", row.nickLabel, "BOTTOMLEFT", 0, -2);
            row.btagLabel:SetSize(200, 10);
            row.btagLabel:SetJustifyH("LEFT")
            row.dropdown = UI:CreateDropdown(row, 200, 30);
            row.dropdown:SetPoint("LEFT", row.nickLabel, "RIGHT", -50, -8)
            row.hideCharBtn = UI:CreateButton(row, "Hide Character", 100, 20);
            row.hideCharBtn:SetPoint("LEFT", row.dropdown, "RIGHT", 5, 0)
        end
        row:SetParent(self.scrollChild);
        row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 25, yOffset);
        row:Show()
        row.deletePlayerBtn:ClearAllPoints();
        row.deletePlayerBtn:SetPoint("LEFT", row, "LEFT", -25, 0)
        row.deletePlayerBtn:SetScript("OnClick", function()
            self:HandleDeletePlayer(btag, isStreamerMode, data)
        end)

        if isStreamerMode then
            row.nickLabel:SetText(data.nickname or "Hidden");
            row.btagLabel:SetText("Hidden")
        else
            row.nickLabel:SetText(data.nickname or btag);
            row.btagLabel:SetText(btag)
        end

        local options = {};
        if data.characters and type(data.characters) == "table" then
            for fullName, charData in pairs(data.characters) do
                local isHidden = ACT.db.profile.localHideList[fullName]
                local isDeleted = type(charData) == "table" and charData.deleted == true
                if not isHidden and not isDeleted then
                    table.insert(options, {
                        text = self:GetFormattedCharacterName(fullName),
                        value = fullName
                    })
                end
            end
        end
        UI:SetDropdownOptions(row.dropdown, options);
        row.dropdown.button.text:SetText("Select Character")
        row.hideCharBtn:SetScript("OnClick", function()
            self:HandleHideCharacter(row.dropdown, data)
        end)
        yOffset = yOffset - 40
    end
    self.scrollChild:SetHeight(math.abs(yOffset) + 10)
end

function NicknameModule:CreateManageHiddenPopup()
    if self.activePopup and self.activePopup:IsShown() then
        return
    end
    if not UI then
        return
    end

    local function closePopup()
        if NicknameModule.activePopup then
            NicknameModule.activePopup:Hide()
        end
        NicknameModule.activePopup = nil
    end

    local popup = UI:CreateTextPopup("Manage Hidden Characters", "", "Close", "", closePopup, closePopup)
    self.activePopup = popup
    function popup:Close()
        closePopup()
    end

    popup:SetFrameLevel(500)
    popup:SetSize(400, 450)
    popup:SetScript("OnShow", nil)
    popup:ClearAllPoints()
    popup:SetPoint("CENTER")

    popup.messageLabel:Hide()
    popup.cancelButton:Hide()
    popup.acceptButton:ClearAllPoints()
    popup.acceptButton:SetPoint("BOTTOM", 0, 20)

    local scrollFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(350, 350)
    scrollFrame:SetPoint("TOP", popup.titleLabel, "BOTTOM", 0, -10)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(330, 350)
    scrollFrame:SetScrollChild(scrollChild)

    local function refreshHiddenList()
        scrollChild:SetHeight(0)
        for _, child in ipairs({ scrollChild:GetChildren() }) do
            child:Hide()
        end
        local y = -10
        for charFullName, _ in pairs(ACT.db.profile.localHideList) do
            local line = CreateFrame("Frame", nil, scrollChild)
            line:SetSize(320, 25)
            line:SetPoint("TOPLEFT", 5, y)
            local label = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            label:SetPoint("LEFT", 10, 0)
            label:SetText(charFullName)
            local unhideBtn = UI:CreateButton(line, "Unhide", 80, 20, function()
                ACT.db.profile.localHideList[charFullName] = nil
                refreshHiddenList()
                self:RefreshContent()
            end)
            unhideBtn:SetPoint("RIGHT", -10, 0)
            y = y - 30
        end
        scrollChild:SetHeight(math.abs(y) + 10)
    end
    refreshHiddenList()
    popup:Show()
end

function NicknameModule:CreateAuthDeletePopup()
    if self.activePopup and self.activePopup:IsShown() then
        return
    end
    if not UI then
        return
    end

    local selectedChars = {}
    local selectedBtag = nil

    local function closePopup()
        if NicknameModule.activePopup then
            NicknameModule.activePopup:Hide()
        end
        NicknameModule.activePopup = nil
    end

    local function acceptAction()
        local toDelete = {}
        for char, shouldDelete in pairs(selectedChars) do
            if shouldDelete then
                table.insert(toDelete, char)
            end
        end
        if #toDelete > 0 and selectedBtag then
            self:HandleAuthDelete(selectedBtag, toDelete)
        end
        closePopup()
    end

    local popup = UI:CreateTextPopup("Authoritative Delete", "", "Delete Selected", "Cancel", acceptAction, closePopup)
    self.activePopup = popup
    function popup:Close()
        closePopup()
    end

    popup:SetFrameLevel(500)
    popup:SetSize(500, 500)
    popup:SetScript("OnShow", nil)
    popup:ClearAllPoints()
    popup:SetPoint("CENTER")
    popup.messageLabel:Hide()

    local btagDropdown = UI:CreateDropdown(popup, 300, 30)
    btagDropdown:SetPoint("TOP", popup.titleLabel, "BOTTOM", 0, -10)
    btagDropdown.list:SetFrameLevel(popup:GetFrameLevel() + 5)

    local scrollFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(450, 350)
    scrollFrame:SetPoint("TOP", btagDropdown, "BOTTOM", 0, -10)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(430, 350)
    scrollFrame:SetScrollChild(scrollChild)

    local function refreshCharList()
        selectedBtag = btagDropdown.selectedValue
        selectedChars = {}
        scrollChild:SetHeight(0)
        for _, child in ipairs({ scrollChild:GetChildren() }) do
            child:Hide()
        end
        if not selectedBtag then
            return
        end

        local playerData = ACT.db.profile.players[selectedBtag]
        if not playerData or not playerData.characters then
            return
        end

        local y = -10
        local charList = {}
        for charFullName, charData in pairs(playerData.characters) do
            if type(charData) ~= "table" or charData.deleted ~= true then
                table.insert(charList, charFullName)
            end
        end
        table.sort(charList)

        for _, charFullName in ipairs(charList) do
            local cb = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 10, y)
            cb:SetScript("OnClick", function(self)
                selectedChars[charFullName] = self:GetChecked()
            end)
            cb.Text:SetText(charFullName)
            cb:SetSize(22, 22)
            cb.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            cb.Text:ClearAllPoints()
            cb.Text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
            y = y - 25
        end
        scrollChild:SetHeight(math.abs(y) + 10)
    end

    local btagOptions = {}
    for btag, data in pairs(ACT.db.profile.players) do
        table.insert(btagOptions, {
            text = data.nickname or btag,
            value = btag,
            onClick = function()
                refreshCharList()
            end
        })
    end
    table.sort(btagOptions, function(a, b)
        return a.text:lower() < b.text:lower()
    end)
    UI:SetDropdownOptions(btagDropdown, btagOptions)

    popup:Show()
end

function NicknameModule:RefreshVersionCheckPopupContent()
    local popup = self.activePopup
    if not popup or not popup.isVersionCheckPopup or not popup:IsShown() or not popup.scrollChild then
        return
    end

    local scrollChild = popup.scrollChild
    if not scrollChild.lines then scrollChild.lines = {} end

    for _, line in ipairs(scrollChild.lines) do
        line:Hide()
    end

    local sortedResults = {}
    for btag, data in pairs(self.waVersionData or {}) do
        local nick = (ACT.db.profile.players[btag] and ACT.db.profile.players[btag].nickname) or btag
        table.insert(sortedResults, { btag = btag, nick = nick, version = data.version, sender = data.sender })
    end
    table.sort(sortedResults, function(a, b) return a.nick:lower() < b.nick:lower() end)

    local y = -10
    local lineIndex = 0
    local myVersion = ACT.db.profile.dataVersion or 0

    local function getLine()
        lineIndex = lineIndex + 1
        local line = scrollChild.lines[lineIndex]
        if not line then
            line = CreateFrame("Frame", nil, scrollChild)
            line:SetSize(320, 25)
            line.label = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            line.label:SetPoint("LEFT", 10, 0)
            line.versionLabel = line:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            line.versionLabel:SetPoint("RIGHT", -10, 0)
            table.insert(scrollChild.lines, line)
        end
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", 5, y)
        line:Show()
        y = y - 30
        return line
    end

    for _, data in ipairs(sortedResults) do
        local remoteLine = getLine()
        local myBtag = GetPlayerBattleTag()
        local displayText = data.nick .. " (" .. data.sender .. ")"

        if data.btag == myBtag then
            displayText = displayText .. " |cffFFFF00(You)|r"
        end

        remoteLine.label:SetText(displayText)
        remoteLine.versionLabel:SetText("v" .. data.version)

        if type(data.version) ~= "number" or data.version < myVersion then
            remoteLine.versionLabel:SetTextColor(1, 0.5, 0.5)
        else
            remoteLine.versionLabel:SetTextColor(0.5, 1, 0.5)
        end
    end

    scrollChild:SetHeight(math.abs(y) + 10)
    popup.messageLabel:SetText("Received " .. #sortedResults .. " responses.")
end

function NicknameModule:CreateVersionCheckPopup()
    if self.activePopup and self.activePopup:IsShown() then
        return
    end
    if not UI then
        return
    end

    self.waVersionData = {}
    if self.versionCheckTimer then
        C_Timer.Cancel(self.versionCheckTimer)
    end
    self.versionCheckTimer = C_Timer.After(30, function()
        self.waVersionData = nil
        self.versionCheckTimer = nil
        if self.activePopup and self.activePopup.isVersionCheckPopup then
            self.activePopup.messageLabel:SetText("Request timed out. Please close and reopen.")
        end
    end)

    local function closePopup()
        if NicknameModule.activePopup then
            NicknameModule.activePopup:Hide()
        end
        NicknameModule.activePopup = nil
        if NicknameModule.versionCheckTimer then
            C_Timer.Cancel(NicknameModule.versionCheckTimer)
            NicknameModule.versionCheckTimer = nil
        end
        NicknameModule.waVersionData = nil
    end

    local popup = UI:CreateTextPopup("WeakAura Version Check", "Requesting versions...", "Close", "", closePopup, nil)
    popup.isVersionCheckPopup = true
    self.activePopup = popup
    popup:SetScript("OnHide", closePopup)

    popup:SetFrameLevel(500)
    popup:SetSize(400, 450)
    popup:SetScript("OnShow", nil)
    popup:ClearAllPoints()
    popup:SetPoint("CENTER")

    popup.cancelButton:Hide()
    popup.acceptButton:ClearAllPoints()
    popup.acceptButton:SetPoint("BOTTOM", 0, 20)
    popup.messageLabel:ClearAllPoints()
    popup.messageLabel:SetPoint("TOP", popup.titleLabel, "BOTTOM", 0, -15)

    local scrollFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(350, 320)
    scrollFrame:SetPoint("TOP", popup.messageLabel, "BOTTOM", 0, -10)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(330, 10)
    scrollFrame:SetScrollChild(scrollChild)
    popup.scrollChild = scrollChild

    popup:Show()
    self:RefreshVersionCheckPopupContent()

    local groupChannel = GetGroupChannel()
    if groupChannel then
        self:BroadcastVersionCheck("VER_REQ", groupChannel)
    end
    self:BroadcastVersionCheck("VER_REQ", "GUILD")
end

SLASH_WIPENICKNAMES1 = "/actwipe"
SlashCmdList["WIPENICKNAMES"] = function()
    if not IsPrivilegedUser() or not UI then
        return
    end
    if not NicknameModule.wipePopup then
        NicknameModule.wipePopup = UI:CreateTextPopup("Confirm Wipe",
            "Are you sure you want to wipe all your local nicknames? This cannot be undone.", "Yes, Wipe", "Cancel",
            function()
                EnsureDB();
                ACT.db.profile.players = {};
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
    if not IsPrivilegedUser() or not UI then
        return
    end
    if not NicknameModule.killConfirmPopup then
        NicknameModule.killConfirmPopup = UI:CreateTextPopup("Confirm Killswitch",
            "Are you sure you want to trigger the killswitch? This will wipe ALL nicknames for everyone in your group/guild.",
            "Yes, Killswitch", "Cancel", function()
                local groupChannel = GetGroupChannel()
                if groupChannel then
                    NicknameModule:Broadcast("NICK_KILLSWITCH", groupChannel)
                end
                NicknameModule:Broadcast("NICK_KILLSWITCH", "GUILD")
                NicknameModule:EventHandler("NICK_KILLSWITCH", GetPlayerBattleTag(), "SELF")
            end)
        NicknameModule.killConfirmPopup:SetScript("OnHide", function()
            NicknameModule.killConfirmPopup = nil
        end)
    end
    NicknameModule.killConfirmPopup:Show()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        NicknameModule:OnPlayerLogin()
    end
end)

local function ReceiveWAComm(prefix, message, channel, sender)
    if InCombatLockdown() then
        return
    end
    if prefix ~= COMM_PREFIX_WA or type(message) ~= "string" then
        return
    end
    EnsureDB()
    if ACT.db.profile.guildOnlyMode and channel ~= "GUILD" then
        return
    end

    if NicknameModule.waMessageTimer[sender] then
        C_Timer.Cancel(NicknameModule.waMessageTimer[sender])
    end
    NicknameModule.waMessageTimer[sender] = C_Timer.After(5, function()
        NicknameModule.waMessageAccumulator[sender] = nil
        NicknameModule.waMessageTimer[sender] = nil
    end)

    if message:find("^START:") then
        local _, versionStr = strsplit(":", message, 2)
        local incomingVersion = tonumber(versionStr) or 0
        NicknameModule.waMessageAccumulator[sender] = {
            data = {},
            version = incomingVersion
        }
    elseif message == "START" then
        NicknameModule.waMessageAccumulator[sender] = {
            data = {},
            version = 0
        }
    elseif message == "END" then
        local accumulation = NicknameModule.waMessageAccumulator[sender]
        if accumulation and accumulation.data and #accumulation.data > 0 then
            local completeData = table.concat(accumulation.data)

            local defaults = {}
            local count = 0
            for entry in string.gmatch(completeData, "([^;]+)") do
                local btag, nick = strsplit(":", entry, 2)
                if btag and nick and btag:match(BTAG_REGEX) then
                    defaults[strtrim(btag)] = strtrim(nick)
                    count = count + 1
                end
            end

            if next(defaults) then
                NicknameModule:MergeAuthoritativeData(accumulation.version, defaults)
            else
            end
        end
        NicknameModule.waMessageAccumulator[sender] = nil
        if NicknameModule.waMessageTimer[sender] then
            C_Timer.Cancel(NicknameModule.waMessageTimer[sender])
            NicknameModule.waMessageTimer[sender] = nil
        end
    elseif message:find("^DATA:") then
        local accumulation = NicknameModule.waMessageAccumulator[sender]
        if accumulation then
            table.insert(accumulation.data, message:sub(6))
        end
    end
end
local waEventFrame = CreateFrame("Frame")
waEventFrame:RegisterEvent("CHAT_MSG_ADDON")
waEventFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    ReceiveWAComm(prefix, message, channel, sender)
end)

function NicknameModule:MergeAuthoritativeData(version, defaults)
    EnsureDB()

    if version < (ACT.db.profile.dataVersion or 0) then
        return
    end

    self.authoritativeData = defaults or {}

    ACT.db.profile.dataVersion = version

    local hasChanged = false
    local playersDB = ACT.db.profile.players
    local myBattleTag = GetPlayerBattleTag()

    if ACT.db.profile.strictMode then
        local keysToDelete = {}
        for btag, _ in pairs(playersDB) do
            if btag ~= myBattleTag and not defaults[btag] then
                table.insert(keysToDelete, btag)
            end
        end
        if #keysToDelete > 0 then
            for _, btagToDelete in ipairs(keysToDelete) do
                playersDB[btagToDelete] = nil
            end
            hasChanged = true
        end
    end

    for btag, defaultNick in pairs(defaults) do
        if not playersDB[btag] then
            playersDB[btag] = {
                nickname = defaultNick,
                characters = {}
            }
            hasChanged = true
        elseif playersDB[btag].nickname ~= defaultNick then
            playersDB[btag].nickname = defaultNick
            hasChanged = true
        end
    end

    if hasChanged then
        self:BroadcastSyncRequest()
        if NicknameAPI and NicknameAPI.RefreshAllIntegrations then
            C_Timer.After(0.1, NicknameAPI.RefreshAllIntegrations)
        end
    end

    if self.configPanel and self.configPanel:IsShown() then
        self:RefreshContent()
    end
end

function NicknameModule:PromptReloadNormal()
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

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(NicknameModule)
end

return NicknameModule
