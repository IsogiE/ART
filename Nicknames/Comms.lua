local addonName = ...
local NicknameModule = ACT and ACT.Nicknames
if not NicknameModule then
    return
end

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")
local AceComm = LibStub("AceComm-3.0")

-- Throttling & Combat lockdown
local BROADCAST_DELAY = 2
local BROADCAST_INTERVAL = 3
local broadcastQueued = false
local lastBroadcastTime = 0
local broadcastPending = false
local receiveQueue = {}

-- Cache
local guidToNicknameData = {}
local guidToUnitName = {}
local playerRealmName = nil

-- Check if we already have nickname data for other members in our current group
local function IsCachePopulatedForGroup()
    if not IsInGroup() then
        return false
    end

    local playerGUID = UnitGUID("player")
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        -- If unit exists, is not our character, and we have data for them, populate cache
        if UnitExists(unit) then
            local guid = UnitGUID(unit)
            if guid and guid ~= playerGUID and guidToNicknameData[guid] then
                return true
            end
        end
    end
    return false
end

local function GetRealmIncludedName(unit)
    local name, realm = UnitNameUnmodified(unit)
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    if not realm or not name then
        return nil
    end
    return string.format("%s-%s", name, realm)
end

-- Check if nickname data has changed
local function IsNicknameDataChanged(GUID, newData)
    local oldData = guidToNicknameData[GUID]
    if not oldData then
        return true
    end

    -- Check if version is higher or nickname changed
    if newData.version > oldData.version then
        return true
    end

    if newData.version == oldData.version and oldData.nickname ~= newData.nickname then
        return true
    end

    return false
end

-- Clean up GUIDs that are no longer in group
local function DeleteNicknameDataForInvalidGUIDs()
    for GUID, unit in pairs(guidToUnitName) do
        if not UnitExists(unit) then
            guidToNicknameData[GUID] = nil
            guidToUnitName[GUID] = nil
        end
    end
end

local function ValidateNicknameDatabase()
    if not ACT_CharacterDB or not ACT_CharacterDB.nicknames then
        return
    end

    local activeGroupMembers = {}
    -- Add self to the list of members to keep
    local selfRealmName = GetRealmIncludedName("player")
    if selfRealmName then
        activeGroupMembers[selfRealmName] = true
    end

    -- If in a group, build a list of all current characters
    if IsInGroup() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) then
                local memberRealmName = GetRealmIncludedName(unit)
                if memberRealmName then
                    activeGroupMembers[memberRealmName] = true
                end
            end
        end
    end

    -- Iterate through the saved nicknames and remove anyone not in the current group
    for characterRealm, _ in pairs(ACT_CharacterDB.nicknames) do
        if not activeGroupMembers[characterRealm] then
            ACT_CharacterDB.nicknames[characterRealm] = nil
        end
    end
end

-- Get current player's nickname data
local function GetPlayerNicknameData()
    if not NicknameModule.isInitialized or not ACT_CharacterDB or not ACT_CharacterDB.nicknames then
        return nil
    end

    if not playerRealmName then
        playerRealmName = GetRealmIncludedName("player")
    end

    local nickname = ACT_CharacterDB.nicknames[playerRealmName]
    local version = 1

    -- Get version from cache if it exists
    local playerGUID = UnitGUID("player")
    if playerGUID and guidToNicknameData[playerGUID] then
        version = guidToNicknameData[playerGUID].version
    end

    return {
        nickname = nickname,
        version = version,
        characterRealm = playerRealmName
    }
end

-- Get player nickname data
local function GetSerializedPlayerNicknameData()
    local data = GetPlayerNicknameData()
    if not data then
        return nil
    end

    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)

    return encoded
end

-- Update nickname data for a unit
local function UpdateNicknameDataForUnit(unit, nicknameData, isFromComms)
    if not UnitExists(unit) then
        return
    end

    local GUID = UnitGUID(unit)
    if not GUID then
        return
    end

    -- Check if data has changed
    if not IsNicknameDataChanged(GUID, nicknameData) then
        return
    end

    -- Update cache
    guidToNicknameData[GUID] = CopyTable(nicknameData)
    guidToUnitName[GUID] = GetUnitName(unit, true)

    -- Get old nickname from database
    local realmIncludedName = GetRealmIncludedName(unit)
    if not realmIncludedName then
        return
    end

    local oldNickname = nil
    if ACT_CharacterDB and ACT_CharacterDB.nicknames then
        oldNickname = ACT_CharacterDB.nicknames[realmIncludedName]
    end

    local newNickname = nicknameData.nickname

    -- Only update if nickname actually changed
    if oldNickname ~= newNickname then
        if ACT_CharacterDB and ACT_CharacterDB.nicknames then
            ACT_CharacterDB.nicknames[realmIncludedName] = newNickname

            -- Update cache in NicknameModule
            if NicknameModule.nicknameToCharacterCache then
                if oldNickname then
                    NicknameModule.nicknameToCharacterCache[oldNickname] = nil
                end
                if newNickname then
                    NicknameModule.nicknameToCharacterCache[newNickname] = unit
                end
            end

            -- Trigger addon integration updates
            for _, functions in pairs(NicknameModule.nicknameFunctions) do
                if functions.Update then
                    functions.Update(unit, realmIncludedName, oldNickname, newNickname)
                end
            end
        end
    end
end

local function ProcessReceivedNicknameData(payload, sender)
    -- Check if sender is valid and still exists
    if not sender or UnitIsUnit(sender, "player") or not UnitExists(sender) then
        return
    end

    local decoded = LibDeflate:DecodeForWoWAddonChannel(payload)
    if not decoded then
        return
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return
    end

    local success, nicknameData = LibSerialize:Deserialize(decompressed)
    if not success or not nicknameData then
        return
    end

    -- Validate data structure
    if not nicknameData.version or not nicknameData.characterRealm then
        return
    end

    UpdateNicknameDataForUnit(sender, nicknameData, true)
end

local function ReceiveNicknameData(_, payload, _, sender)
    if UnitIsUnit(sender, "player") then
        return
    end

    if UnitAffectingCombat("player") then
        -- Queue if in combat
        table.insert(receiveQueue, {
            payload = payload,
            sender = sender
        })
    else
        -- Not in combat, so we process 
        ProcessReceivedNicknameData(payload, sender)
    end
end

-- Request nickname data from group
local function RequestNicknameData(chatType)
    AceComm:SendCommMessage("ACT_NickRequest", " ", chatType)
end

-- Receive request for nickname data
local function ReceiveRequest(_, _, _, sender)
    if UnitIsUnit(sender, "player") then
        return
    end

    BroadcastNicknameData()
end

-- Broadcast nickname data to group
function BroadcastNicknameData()
    -- If in combat, set a flag to broadcast after combat and exit
    if UnitAffectingCombat("player") then
        broadcastPending = true
        return
    end

    -- Always update our own data directly
    local playerData = GetPlayerNicknameData()
    if playerData then
        UpdateNicknameDataForUnit("player", playerData, false)
    end

    -- If broadcast is already queued, don't queue another
    if broadcastQueued then
        return
    end

    -- Calculate time to next broadcast
    local timeToNextBroadcast = BROADCAST_DELAY
    local timeSinceLastBroadcast = GetTime() - lastBroadcastTime

    if timeSinceLastBroadcast < BROADCAST_INTERVAL then
        timeToNextBroadcast = math.max(BROADCAST_DELAY, BROADCAST_INTERVAL - timeSinceLastBroadcast)
    end

    C_Timer.After(timeToNextBroadcast, function()
        -- Also check for combat when timer fires, just in case
        if UnitAffectingCombat("player") then
            broadcastQueued = false
            broadcastPending = true -- Re-queue if we entered combat
            return
        end

        local serializedData = GetSerializedPlayerNicknameData()

        if serializedData and IsInGroup() then
            local chatType = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or IsInRaid() and "RAID" or
                                 "PARTY"
            AceComm:SendCommMessage("ACT_NickData", serializedData, chatType)
        end

        broadcastQueued = false
        lastBroadcastTime = GetTime()
    end)

    broadcastQueued = true
end

-- Broadcast any changes
local originalUpdateNickname = NicknameModule.UpdateNicknameForUnit
function NicknameModule:UpdateNicknameForUnit(unit, nickname)
    originalUpdateNickname(self, unit, nickname)

    -- If it's our char, increment version and broadcast
    if unit == "player" then
        local playerGUID = UnitGUID("player")
        if playerGUID then
            if not guidToNicknameData[playerGUID] then
                guidToNicknameData[playerGUID] = {
                    version = 1
                }
            end
            guidToNicknameData[playerGUID].version = (guidToNicknameData[playerGUID].version or 0) + 1
            guidToNicknameData[playerGUID].nickname = nickname

            BroadcastNicknameData()
        end
    end
end

local function InitializeComms()
    AceComm:RegisterComm("ACT_NickRequest", ReceiveRequest)
    AceComm:RegisterComm("ACT_NickData", ReceiveNicknameData)

    playerRealmName = GetRealmIncludedName("player")
end

local function OnEvent(self, event, ...)
    if event == "GROUP_JOINED" or event == "GROUP_FORMED" then
        local chatType = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or IsInRaid() and "RAID" or "PARTY"

        BroadcastNicknameData()
        RequestNicknameData(chatType)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Validate the database to remove stale entries from previous sessions
        ValidateNicknameDatabase()

        if IsInGroup() then
            BroadcastNicknameData()

            if not IsCachePopulatedForGroup() then
                local chatType = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or IsInRaid() and "RAID" or
                                     "PARTY"
                RequestNicknameData(chatType)
            end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        DeleteNicknameDataForInvalidGUIDs()
    elseif event == "GROUP_LEFT" then
        local playerGUID = UnitGUID("player")
        local tempCache = {}
        local tempNames = {}

        if playerGUID and guidToNicknameData[playerGUID] then
            tempCache[playerGUID] = guidToNicknameData[playerGUID]
            tempNames[playerGUID] = guidToUnitName[playerGUID]
        end

        guidToNicknameData = tempCache
        guidToUnitName = tempNames

        if ACT_CharacterDB and ACT_CharacterDB.nicknames and playerRealmName then
            local currentPlayerNickname = ACT_CharacterDB.nicknames[playerRealmName]

            -- Wipe the table
            for characterRealm in pairs(ACT_CharacterDB.nicknames) do
                ACT_CharacterDB.nicknames[characterRealm] = nil
            end

            if currentPlayerNickname then
                ACT_CharacterDB.nicknames[playerRealmName] = currentPlayerNickname
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- When combat ends, send any pending broadcasts
        if broadcastPending then
            broadcastPending = false
            BroadcastNicknameData()
        end

        -- Process any queued received data
        if #receiveQueue > 0 then
            for _, data in ipairs(receiveQueue) do
                ProcessReceivedNicknameData(data.payload, data.sender)
            end
            wipe(receiveQueue)
        end
    end
end

-- Create event frame
local commsFrame = CreateFrame("Frame")
commsFrame:RegisterEvent("GROUP_JOINED")
commsFrame:RegisterEvent("GROUP_FORMED")
commsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
commsFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
commsFrame:RegisterEvent("GROUP_LEFT")
commsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
commsFrame:SetScript("OnEvent", OnEvent)

InitializeComms()

-- Register with nickname module
NicknameModule.nicknameFunctions["Comms"] = {
    Init = InitializeComms,
    Broadcast = BroadcastNicknameData
}

return true
