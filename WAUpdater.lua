local AceComm = LibStub("AceComm-3.0")
local LibDeflate = LibStub("LibDeflate")
local LibSerialize = LibStub("LibSerialize")

local WeakAuraUpdaterModule = {}
WeakAuraUpdaterModule.title = "WeakAura Updater"
WeakAuraUpdaterModule.importPopup = nil
WeakAuraUpdaterModule.chunkBuffers = {}
WeakAuraUpdaterModule.receiveStatus = {}

function WeakAuraUpdaterModule:GetConfigSize()
    return 800, 600
end

function WeakAuraUpdaterModule:EnsureDB()
    if not ACT or not ACT.db or not ACT.db.profile then
        return {}
    end
    ACT.db.profile.weakauraUpdater = ACT.db.profile.weakauraUpdater or {}
    return ACT.db.profile.weakauraUpdater
end

local COMM_PREFIX = "ACT_WA_UPDATER"
local WA_SYNC_EVENT = "ACT_DISTRIBUTE"
local del = ":"

function WeakAuraUpdaterModule:FormatMessage(event, ...)
    local argTable = {...}
    local message = event
    local unitID = UnitInRaid("player") and "raid" .. UnitInRaid("player") or UnitName("player")
    message = string.format("%s" .. del .. "%s(%s)", message, unitID, "string")

    for i = 1, #argTable do
        local funcArg = argTable[i]
        local argType = type(funcArg)
        if argType == "table" then
            funcArg = LibSerialize:Serialize(funcArg)
            funcArg = LibDeflate:CompressDeflate(funcArg)
            funcArg = LibDeflate:EncodeForWoWAddonChannel(funcArg)
        end
        message = string.format("%s" .. del .. "%s(%s)", message, tostring(funcArg), argType)
    end
    return message
end

function WeakAuraUpdaterModule:DistributeFormattedMessage(message)
    local compressed = LibDeflate:CompressDeflate(message, {
        level = 9
    })
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
    local fullMsg = "C" .. encoded .. "##F##"
    local chunkSize = 245
    local totalParts = math.ceil(#fullMsg / chunkSize)

    AceComm:SendCommMessage(COMM_PREFIX, "START:" .. totalParts, "RAID")

    local currentChunk = 1
    local function sendNextChunk()
        if currentChunk > totalParts then
            self:SetMessage("WeakAura sent to raid.", false)
            return
        end
        local chunk = fullMsg:sub((currentChunk - 1) * chunkSize + 1, currentChunk * chunkSize)
        AceComm:SendCommMessage(COMM_PREFIX, chunk, "RAID")
        self:SetMessage(string.format("Sending WeakAura... %d/%d", currentChunk, totalParts), true)
        currentChunk = currentChunk + 1
        C_Timer.After(0.05, sendNextChunk)
    end
    sendNextChunk()
end

function WeakAuraUpdaterModule:HandleIncomingChunks(prefix, msg, _, sender)
    if prefix ~= COMM_PREFIX then
        return
    end
    if sender == GetUnitName("player", true) then
        return
    end

    if msg:sub(1, 6) == "START:" then
        local total = tonumber(msg:sub(7))
        if total then
            self.receiveStatus[sender] = {
                expected = total,
                received = 0
            }
            self.chunkBuffers[sender] = ""
            self:ShowImportPopup(sender, nil, total, 0)
        end
        return
    end

    if not self.receiveStatus[sender] then
        return
    end

    self.chunkBuffers[sender] = (self.chunkBuffers[sender] or "") .. msg
    self.receiveStatus[sender].received = self.receiveStatus[sender].received + 1

    local status = self.receiveStatus[sender]
    self:ShowImportPopup(sender, nil, status.expected, status.received)

    if self.chunkBuffers[sender]:sub(-5) == "##F##" then
        local completeMsg = self.chunkBuffers[sender]:sub(2, -6)
        local decoded = LibDeflate:DecodeForWoWAddonChannel(completeMsg)
        local decompressed, _, err = LibDeflate:DecompressDeflate(decoded)

        if decompressed and not err then
            self:ReceiveComm(decompressed, sender)
        end

        self.chunkBuffers[sender] = nil
        self.receiveStatus[sender] = nil
    end
end

AceComm:RegisterComm(COMM_PREFIX, function(...)
    WeakAuraUpdaterModule:HandleIncomingChunks(...)
end)

function WeakAuraUpdaterModule:ReceiveComm(text, sender)
    local strsplit = function(delimiter, str)
        local list = {}
        if not str or str == "" then
            return list
        end
        local pos = 1
        while true do
            local first, last = string.find(str, delimiter, pos)
            if first then
                list[#list + 1] = str:sub(pos, first - 1);
                pos = last + 1
            else
                list[#list + 1] = str:sub(pos);
                break
            end
        end
        return list
    end

    local argTable = strsplit(del, text)
    local event = table.remove(argTable, 1)
    if not event then
        return
    end

    local formattedArgs = {}
    local tonext
    for _, funcArg in ipairs(argTable) do
        local val, argType = funcArg:match("(.*)%((%a+)%)")
        if tonext and val then
            val = tonext .. val
        end
        if val and argType then
            tonext = nil
            if argType == "table" then
                val = LibDeflate:DecodeForWoWAddonChannel(val)
                val = LibDeflate:DecompressDeflate(val)
                local success, tbl = LibSerialize:Deserialize(val)
                val = success and tbl or nil
            elseif argType == "number" then
                val = tonumber(val)
            elseif argType == "boolean" then
                val = val == "true"
            end
            table.insert(formattedArgs, val)
        else
            tonext = (tonext or "") .. funcArg .. del
        end
    end

    if #formattedArgs > 0 then
        self:EventHandler(event, sender, unpack(formattedArgs))
    end
end

function WeakAuraUpdaterModule:ShowImportPopup(senderFullName, waString, totalChunks, receivedChunks)
    local senderUnit
    for i = 1, GetNumGroupMembers() do
        if GetUnitName("raid" .. i, true) == senderFullName then
            senderUnit = "raid" .. i
            break
        end
    end

    local displayName
    if senderFullName and ACT and ACT.GetCharacterInGroup and ACT.GetNickname then
        local unit = ACT:GetCharacterInGroup(senderFullName)
        if unit then
            displayName = ACT:GetNickname(unit)
        end
    end

    if not displayName then
        displayName = senderFullName:match("([^-]+)") or senderFullName
    end

    local _, class = senderUnit and UnitClass(senderUnit) or nil
    local color = class and RAID_CLASS_COLORS[class] or {
        r = 1,
        g = 1,
        b = 1
    }
    local colorHex = string.format("%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    local coloredDisplayName = string.format("|cff%s%s|r", colorHex, displayName)

    if not self.importPopup or not self.importPopup:IsShown() then
        local onAccept = function(popup)
            if popup and popup.waString and WeakAuras and WeakAuras.Import then
                WeakAuras.Import(popup.waString)
            end
        end
        self.importPopup = UI:CreateTextPopup("WeakAura Import", "", "Accept", "Decline", function()
            onAccept(self.importPopup)
        end, nil, self.importPopup)
        self.importPopup:Show()
    end

    local message
    if waString then
        self.importPopup.waString = waString
        message = string.format("Import ready from %s.", coloredDisplayName)
        self.importPopup.acceptButton:Enable()
    else
        message = string.format("Receiving from %s... (%d/%d)", coloredDisplayName, receivedChunks or 0, totalChunks)
        self.importPopup.acceptButton:Disable()
    end

    self.importPopup.messageLabel:SetText(message)
    if self.importPopup.titleLabel and self.importPopup.messageLabel then
        C_Timer.After(0, function()
            if self.importPopup and self.importPopup:IsShown() then
                local newHeight = self.importPopup.titleLabel:GetStringHeight() + 10 +
                                      self.importPopup.messageLabel:GetStringHeight() + 10 + 35 + 20
                self.importPopup:SetHeight(newHeight)
            end
        end)
    end
end

function WeakAuraUpdaterModule:EventHandler(event, sender, ...)
    if event == WA_SYNC_EVENT then
        local _, waString = ...
        if not waString or not sender then
            return
        end

        if UnitAffectingCombat("player") or (WeakAuras and WeakAuras.CurrentEncounter) then
            self.pendingWeakAura = {
                sender = sender,
                data = waString
            }
            self:SetMessage("WA from " .. sender .. " received. Import will show after combat.")
        else
            self:ShowImportPopup(sender, waString)
        end
    end
end

local combatEventFrame = CreateFrame("Frame")
combatEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatEventFrame:RegisterEvent("ENCOUNTER_END")
combatEventFrame:SetScript("OnEvent", function()
    if WeakAuraUpdaterModule.pendingWeakAura then
        local weakaura = WeakAuraUpdaterModule.pendingWeakAura
        WeakAuraUpdaterModule.pendingWeakAura = nil
        C_Timer.After(1, function()
            WeakAuraUpdaterModule:ShowImportPopup(weakaura.sender, weakaura.data)
        end)
    end
end)

function WeakAuraUpdaterModule:CreateConfigPanel(parent)
    if self.configPanel then
        self.configPanel:SetParent(parent)
        self.configPanel:ClearAllPoints()
        self.configPanel:SetAllPoints(parent)
        self.configPanel:Show()
        return self.configPanel
    end

    local configPanel = CreateFrame("Frame", nil, parent)
    configPanel:SetAllPoints(parent)

    local importLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importLabel:SetPoint("TOPLEFT", 20, 16)
    importLabel:SetText("WeakAura Updater")

    local importBoxFrame, importBoxEdit = UI:CreateMultilineEditBox(configPanel, 520, 200, "")
    importBoxFrame:SetPoint("TOPLEFT", importLabel, "BOTTOMLEFT", 0, -10)
    self.importBoxEdit = importBoxEdit

    local sendButton = UI:CreateButton(configPanel, "Send", 120, 30)
    sendButton:SetPoint("TOPLEFT", importBoxFrame, "BOTTOMLEFT", 0, -10)
    sendButton:SetScript("OnClick", function()
        local text = self.importBoxEdit:GetText()
        local cleaned = text and text:match("^%s*(.-)%s*$")
        if not cleaned or cleaned == "" or string.sub(cleaned, 1, 1) ~= "!" then
            self:SetMessage("Please paste a valid WeakAura string.")
            return
        end
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            local message = self:FormatMessage(WA_SYNC_EVENT, cleaned)
            self:DistributeFormattedMessage(message)
            self.importBoxEdit:SetText("")
        else
            self:SetMessage("You must be raid leader or assist to send WeakAuras.")
        end
    end)

    local clearButton = UI:CreateButton(configPanel, "Clear", 120, 30)
    clearButton:SetPoint("LEFT", sendButton, "RIGHT", 10, 0)
    clearButton:SetScript("OnClick", function()
        self.importBoxEdit:SetText("")
        self.pendingWeakAura = nil
        self:SetMessage("")
    end)

    local messageLabel = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    messageLabel:SetPoint("TOPLEFT", sendButton, "BOTTOMLEFT", 0, -10)
    messageLabel:SetWidth(540)
    messageLabel:SetJustifyH("LEFT")
    self.messageLabel = messageLabel

    self.configPanel = configPanel
    return self.configPanel
end

function WeakAuraUpdaterModule:SetMessage(msg, sending)
    if self.messageLabel then
        self.messageLabel:SetText(msg or "")
        if self.messageClearTimer then
            self.messageClearTimer:Cancel()
            self.messageClearTimer = nil
        end
        if not sending then
            self.messageClearTimer = C_Timer.After(5, function()
                if self.messageLabel:GetText() == msg then
                    self.messageLabel:SetText("")
                end
            end)
        end
    end
end

if ACT and ACT.RegisterModule then
    ACT:RegisterModule(WeakAuraUpdaterModule)
end

return WeakAuraUpdaterModule
