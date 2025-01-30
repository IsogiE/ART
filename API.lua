local AddonName = ...

local AceComm = LibStub("AceComm-3.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local function GetNicknamesMap()
    if not VMRT or not VMRT.Nicknames then return {} end
    return VMRT.Nicknames
end

-- Nickname API
local NicknameAPI = {
    GetNicknameByCharacter = function(_, characterName)
        if not characterName or type(characterName) ~= "string" then return nil end

        characterName = characterName:lower()

        local nicknamesMap = GetNicknamesMap()

        for nickname, data in pairs(nicknamesMap) do
            if data.characters then
                for _, charData in ipairs(data.characters) do
                    local storedChar = charData.character:lower() 
                    if storedChar == characterName then
                        return nickname
                    end
                end
            end
        end
        return nil
    end,

    IsCharacterInNickname = function(_, characterName, nickname)
        if not characterName or not nickname or
            type(characterName) ~= "string" or type(nickname) ~= "string" then
            return false
        end

        characterName = characterName:lower()
        nickname = nickname:lower()

        local nicknamesMap = GetNicknamesMap()

        if nicknamesMap[nickname] and nicknamesMap[nickname].characters then
            for _, charData in ipairs(nicknamesMap[nickname].characters) do
                local storedChar = charData.character:lower()
                if storedChar == characterName then
                    return true
                end
            end
        end
        return false
    end,

    GetCharacterByNickname = function(_, nickname)
        if not nickname or type(nickname) ~= "string" then return nil end

        nickname = nickname:lower()
        local nicknamesMap = GetNicknamesMap()

        if nicknamesMap[nickname] and nicknamesMap[nickname].characters
            and #nicknamesMap[nickname].characters > 0 then
            return nicknamesMap[nickname].characters[1].character
        end
        return nil
    end,

    GetAllCharactersByNickname = function(_, nickname)
        if not nickname or type(nickname) ~= "string" then return {} end

        nickname = nickname:lower()
        local nicknamesMap = GetNicknamesMap()

        if nicknamesMap[nickname] and nicknamesMap[nickname].characters then
            local characters = {}
            for _, charData in ipairs(nicknamesMap[nickname].characters) do
                table.insert(characters, charData.character)
            end
            return characters
        end
        return {}
    end,

    GetAllNicknames = function(_)
        if not VMRT or not VMRT.Nicknames then return {} end
        return GetNicknamesMap()
    end
}

-- LiquidAPI (stolen from Ironi teehee)
local unitIDs = {
    player = true,
    target = true,
    focus = true,
    mouseover = true,
    npc = true,
    vehicle = true,
    pet = true,
}

for i = 1, 4 do
    unitIDs["party" .. i] = true
    unitIDs["party" .. i .. "target"] = true
end

for i = 1, 40 do
    unitIDs["raid" .. i] = true
    unitIDs["raid" .. i .. "target"] = true
end

for i = 1, 40 do
    unitIDs["nameplate" .. i] = true
    unitIDs["nameplate" .. i .. "target"] = true
end

for i = 1, 15 do
    unitIDs["boss" .. i .. "target"] = true
end

local LiquidAPI = {
    GetName = function(_, characterName, formatting, atlasSize)
        if not characterName then
            error("LiquidAPI:GetName(characterName[, formatting, atlasSize]), characterName is nil")
            return
        end

        local nickname
        characterName = characterName:lower()

        nickname = NicknameAPI:GetCharacterByNickname(characterName) and characterName

        if not nickname then
            if unitIDs[characterName] then
                if UnitExists(characterName) then
                    local n = UnitName(characterName)
                    if n then
                        n = n:match("^([^-]+)")
                        nickname = NicknameAPI:GetNicknameByCharacter(n) or n
                    end
                else
                    nickname = characterName
                end
            else
                nickname = NicknameAPI:GetNicknameByCharacter(characterName) or characterName
            end
        end


        if not formatting then
            return nickname
        end

        local guid = UnitGUID(characterName)
        if not guid then
            return nickname or characterName, "%s", ""
        end

        if not UnitExists(characterName) then
            return nickname, "%s", ""
        end

        local classFileName = UnitClassBase(characterName)
        local colorStr = classFileName and RAID_CLASS_COLORS[classFileName]
            and RAID_CLASS_COLORS[classFileName].colorStr or "ffffffff"
        local colorFormat = string.format("|c%s%%s|r", colorStr)

        local role = UnitGroupRolesAssigned(characterName)
        local roleAtlas = role == "TANK" and "Role-Tank-SM" or
            role == "HEALER" and "Role-Healer-SM" or
            role == "DAMAGER" and "Role-DPS-SM"
        local roleIcon = roleAtlas and CreateAtlasMarkup(roleAtlas, atlasSize or 12, atlasSize or 12) or ""

        return nickname, colorFormat, roleIcon,
            RAID_CLASS_COLORS[classFileName] or {}
    end,

    GetCharacterInGroup = function(_, nickname)
        if not nickname then return nil end
        nickname = nickname:lower()

        local nicknamesMap = NicknameAPI:GetAllNicknames()

        if nicknamesMap[nickname] and nicknamesMap[nickname].characters then
            for _, charData in ipairs(nicknamesMap[nickname].characters) do
                local charNameLower = charData.character:lower()
                if UnitExists(charNameLower) then
                    local guid = UnitGUID(charNameLower)
                    local classFileName = UnitClassBase(charNameLower)
                    return charData.character,
                        string.format("|c%s%%s|r", RAID_CLASS_COLORS[classFileName].colorStr),
                        guid
                end
            end
        end
        return nil
    end,

    GetCharacters = function(_, nickname)
        if not nickname then
            error("LiquidAPI:GetCharacters(nickname), nickname is nil")
            return
        end

        local nicknamesMap = NicknameAPI:GetAllNicknames()

        nickname = nickname:lower()
        if nicknamesMap[nickname] and nicknamesMap[nickname].characters then
            local chars = {}
            for _, charData in ipairs(nicknamesMap[nickname].characters) do
                chars[charData.character] = true
            end
            return chars
        end
        return nil
    end
}

_G.LiquidAPI = LiquidAPI

-- NSAPI (from NS Database WA)
local NSAPI = {}

NSAPI.specs = {}

_G.fullCharList = {}
_G.sortedCharList = {}

local function BuildSheet()
    local sheet = {}
    local nicknamesMap = NicknameAPI:GetAllNicknames()
    
    for nickname, data in pairs(nicknamesMap) do
        if data.characters then
            for _, charData in ipairs(data.characters) do
                table.insert(sheet, charData.character .. ":" .. nickname)
            end
        end
    end
    
    return table.concat(sheet, ";")
end

local function RebuildCharacterLists()
    wipe(_G.fullCharList)
    wipe(_G.sortedCharList)
    
    local sheet = BuildSheet()
    if sheet ~= "" then
        for _, str in pairs({strsplit(";", sheet)}) do
            local from, to = strsplit(":", str)
            from = strsplit("-", from) 
            if from and to then
                _G.fullCharList[from] = to
                if not _G.sortedCharList[to] then
                    _G.sortedCharList[to] = {}
                end
                _G.sortedCharList[to][from] = true
            end
        end
    end
end

function NSAPI:Version()
    return 9
end

function NSAPI:GetCharacters(str)
    if not str then
        error("NSAPI:GetCharacters(str), str is nil")
        return
    end
    
    return _G.sortedCharList[str] and CopyTable(_G.sortedCharList[str])
end

function NSAPI:GetAllCharacters()
    return CopyTable(_G.fullCharList)
end

function NSAPI:GetName(str)
    if not str then
        error("NSAPI:GetName(str), str is nil")
        return
    end
    
    if UnitExists(str) then
        local n = UnitName(str)
        return n and _G.fullCharList[n] or n
    else
        return _G.fullCharList[str] or str
    end
end

function NSAPI:GetChar(name, nick)
    if not name then return nil end
    
    name = nick and self:GetName(name) or name
    
    if UnitExists(name) and UnitIsConnected(name) then
        return name
    end
    
    local chars = self:GetCharacters(name)
    if chars then
        for charName, _ in pairs(chars) do
            local raidIndex = UnitInRaid(charName)
            if UnitIsVisible(charName) or (raidIndex and select(3, GetRaidRosterInfo(raidIndex)) <= 4) then
                return charName
            end
        end
    end
    
    return name
end

local function utf8sub(str, start, numChars)
    if not str then return "" end
    
    local currentIndex = 1
    local currentChar = 0
    local result = ""
    
    while currentChar < start + (numChars or 0) - 1 and currentIndex <= #str do
        local byte = string.byte(str, currentIndex)
        local width = byte >= 240 and 4 or byte >= 224 and 3 or byte >= 192 and 2 or 1
        
        currentChar = currentChar + 1
        if currentChar > start - 1 then
            result = result .. string.sub(str, currentIndex, currentIndex + width - 1)
        end
        
        currentIndex = currentIndex + width
    end
    
    return result
end

function NSAPI:Shorten(unit, num, role)
    if not unit then return nil end
    
    local classFilename = select(2, UnitClass(unit))
    local roleIcon
    
    if role then
        local unitRole = UnitGroupRolesAssigned(unit)
        if unitRole ~= "NONE" then
            roleIcon = CreateAtlasMarkup(GetIconForRole(unitRole), 0, 0)
        end
    end
    
    if classFilename then
        local name = UnitName(unit)
        local color = GetClassColorObj(classFilename)
        name = self:GetName(name)
        
        if num then
            name = utf8sub(name, 1, num)
        end
        
        if color then
            return color:WrapTextInColorCode(name), roleIcon
        else
            return name, roleIcon
        end
    end
    
    return unit, ""
end

function NSAPI:GetSpecs(unit)
    if unit and self.specs[unit] then
        return self.specs[unit]
    end
    return self.specs
end

-- WeakAuras (also stolen from Ironi teehee)
if WeakAuras then
    WeakAuras.GetName = function(n)
        if not n then return end
        return NicknameAPI:GetNicknameByCharacter(n) or n
    end

    WeakAuras.UnitName = function(unit)
        if not unit then return end
        local n, s = UnitName(unit)
        if not n then return end
        return NicknameAPI:GetNicknameByCharacter(n) or n, s
    end

    if WeakAuras.GetUnitName then
        WeakAuras.GetUnitName = function(unit, showServer)
            if not unit then return end
            local unitName = GetUnitName(unit, showServer)
            if not unitName then return end
            if not UnitIsPlayer(unit) then return unitName end
            
            local nickname = NicknameAPI:GetNicknameByCharacter(unitName)
            if not nickname then return unitName end

            if showServer then
                local n, s = strsplit("-", unitName)
                return s and string.format("%s-%s", nickname, s) or nickname
            end

            return nickname
        end
    end

    WeakAuras.UnitFullName = function(unit)
        if not unit then return end
        local n, s = UnitFullName(unit)
        if not n then return end
        if UnitIsPlayer(unit) then
            return NicknameAPI:GetNicknameByCharacter(n) or n, s
        end
        return n, s
    end
end

-- Cell
local function EnhancedUpdateCellNicknames()
    if not C_AddOns.IsAddOnLoaded("Cell") then return end
    
    CellDB.nicknames.list = CellDB.nicknames.list or {}
    CellDB.nicknames.custom = true
    
    local ourManagedCharacters = {}
    local entriesToRemove = {}
    
    local nicknameData = NicknameAPI:GetAllNicknames()
    for nickname, data in pairs(nicknameData) do
        if data.characters then
            for _, charData in ipairs(data.characters) do
                if charData.character then
                    ourManagedCharacters[charData.character] = true
                end
            end
        end
    end
    
    for i, entry in ipairs(CellDB.nicknames.list) do
        local character = strsplit(":", entry)
        if ourManagedCharacters[character] then
            table.insert(entriesToRemove, i)
        end
    end
    
    table.sort(entriesToRemove, function(a,b) return a > b end)
    for _, index in ipairs(entriesToRemove) do
        table.remove(CellDB.nicknames.list, index)
    end
    
    for nickname, data in pairs(nicknameData) do
        if data.characters then
            for _, charData in ipairs(data.characters) do
                if charData.character then
                    table.insert(CellDB.nicknames.list, charData.character .. ":" .. nickname)
                end
            end
        end
    end
    
    if Cell.funcs and Cell.funcs.UpdateNicknames then
        Cell.funcs.UpdateNicknames()
    end
end

-- ElvUI (thanks reloe)
if ElvUF and ElvUF.Tags then
	ElvUF.Tags.Events['nickname'] = 'UNIT_NAME_UPDATE'
	ElvUF.Tags.Events['nickname:Short'] = 'UNIT_NAME_UPDATE'
	ElvUF.Tags.Events['nickname:Medium'] = 'UNIT_NAME_UPDATE'
	ElvUF.Tags.Methods['nickname'] = function(unit)
		local name = UnitName(unit)
		return name and NicknameAPI and NicknameAPI:GetNicknameByCharacter(name) or name
	end

	ElvUF.Tags.Methods['nickname:veryshort'] = function(unit)
		local name = UnitName(unit)
		name = name and NicknameAPI and NicknameAPI:GetNicknameByCharacter(name) or name
		return string.sub(name, 1, 5)
	end

	ElvUF.Tags.Methods['nickname:short'] = function(unit)
		local name = UnitName(unit)
		name = name and NicknameAPI and NicknameAPI:GetNicknameByCharacter(name) or name
		return string.sub(name, 1, 8)
	end

	ElvUF.Tags.Methods['nickname:medium'] = function(unit)
		local name = UnitName(unit)
		name = name and NicknameAPI and NicknameAPI:GetNicknameByCharacter(name) or name
		return string.sub(name, 1, 10)
	end
end

-- Grid2 (thanks reloe)
local function InitializeGrid2()
    if not Grid2 then return end

    local Name = Grid2.statusPrototype:new("name")

    Name.IsActive = Grid2.statusLibrary.IsActive

    function Name:UNIT_NAME_UPDATE(_, unit)
        self:UpdateIndicators(unit)
    end

    function Name:OnEnable()
        self:RegisterEvent("UNIT_NAME_UPDATE")
    end

    function Name:OnDisable()
        self:UnregisterEvent("UNIT_NAME_UPDATE")
    end

    function Name:GetText(unit)
        local name = UnitName(unit)
        return name and NicknameAPI and NicknameAPI:GetNicknameByCharacter(name) or name
    end

    local function Create(baseKey, dbx)
        Grid2:RegisterStatus(Name, {"text"}, baseKey, dbx)
        return Name
    end

    Grid2.setupFunc["name"] = Create

    Grid2:DbSetStatusDefaultValue("name", { type = "name" })
end

if C_AddOns.IsAddOnLoaded("Grid2") then
    InitializeGrid2()
end

-- Default frames
local function UpdateDefaultFrames()
    local overlays = {}
    
    local function CreateOverlay(frame)
        if not frame or overlays[frame] then return end
        
        local overlay = frame:CreateFontString(nil, "OVERLAY")
        overlay:SetFontObject(frame.name:GetFontObject())
        overlay:SetPoint("LEFT", frame.name, "LEFT")
        overlay:SetJustifyH("LEFT")
        overlay:SetWidth(frame:GetWidth() - 8)
        overlay:SetWordWrap(false)
        
        overlays[frame] = overlay
        return overlay
    end
    
    local function UpdateFrameName(frame)
        if not frame or not frame.unit or not frame.name then return end
        if not UnitExists(frame.unit) or not UnitIsPlayer(frame.unit) then return end
        
        local name = UnitName(frame.unit)
        if not name then return end
        
        local nickname = NicknameAPI:GetNicknameByCharacter(name)
        if nickname then
            local overlay = overlays[frame] or CreateOverlay(frame)
            frame.name:SetAlpha(0)
            if overlay then
                overlay:SetWidth(frame:GetWidth() - 8) 
                overlay:SetText(nickname)
            end
        else
            frame.name:SetAlpha(1)
            if overlays[frame] then
                overlays[frame]:SetText("")
            end
        end
    end
    
    local function OnFrameResize(frame)
        if overlays[frame] then
            overlays[frame]:SetWidth(frame:GetWidth() - 8)
        end
    end
    
    local function UpdateAllFrames()
        for i = 1, 8 do
            local frame = _G["CompactPartyFrameMember"..i]
            if frame and frame:IsVisible() then
                UpdateFrameName(frame)
                if not frame.sizeHooked then
                    frame:HookScript("OnSizeChanged", OnFrameResize)
                    frame.sizeHooked = true
                end
            end
        end
        
        for i = 1, 40 do
            local frame = _G["CompactRaidFrame"..i]
            if frame and frame:IsVisible() then
                UpdateFrameName(frame)
                if not frame.sizeHooked then
                    frame:HookScript("OnSizeChanged", OnFrameResize)
                    frame.sizeHooked = true
                end
            end
            
            for j = 1, 5 do
                local groupFrame = _G["CompactRaidGroup"..i.."Member"..j]
                if groupFrame and groupFrame:IsVisible() then
                    UpdateFrameName(groupFrame)
                    if not groupFrame.sizeHooked then
                        groupFrame:HookScript("OnSizeChanged", OnFrameResize)
                        groupFrame.sizeHooked = true
                    end
                end
            end
        end
    end
    
    local defaultFrame = CreateFrame("Frame")
    defaultFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    defaultFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    
    defaultFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_NAME_UPDATE" then
            local unit = ...
            for i = 1, 40 do
                local frame = _G["CompactRaidFrame"..i]
                if frame and frame.unit == unit then
                    UpdateFrameName(frame)
                    break
                end
            end
        else
            C_Timer.After(0.1, UpdateAllFrames)
        end
    end)
    
    C_Timer.After(0.1, UpdateAllFrames)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("ADDON_LOADED")

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        EnhancedUpdateCellNicknames()
        UpdateDefaultFrames()
        RebuildCharacterLists()
    elseif event == "ADDON_LOADED" then
        if arg1 == "Cell" then
        EnhancedUpdateCellNicknames()
        end
    end
end)

RebuildCharacterLists()

function NSAPI:Broadcast(event, channel, ...)
    local message = event
    local argTable = {...}
    
    local unitID = UnitInRaid("player") and "raid"..UnitInRaid("player") or UnitName("player")   
    message = string.format("%s:%s(%s)", message, unitID, "string")
    
    for i = 1, #argTable do
        local functionArg = argTable[i]
        local argType = type(functionArg)
        
        if argType == "table" then
            functionArg = LibSerialize:Serialize(functionArg)    
            functionArg = LibDeflate:CompressDeflate(functionArg)            
            functionArg = LibDeflate:EncodeForWoWAddonChannel(functionArg)
            message = string.format("%s:%s(%s)", message, tostring(functionArg), argType)
        else
            if argType ~= "string" and argType ~= "number" and argType ~= "boolean" then
                functionArg = ""
                argType = "string"
            end
            message = string.format("%s:%s(%s)", message, tostring(functionArg), argType)
        end
    end
    
    if channel == "WHISPER" then
        AceComm:SendCommMessage("NSWA_MSG2", message, "RAID")
    else
        AceComm:SendCommMessage("NSWA_MSG", message, channel)
    end
end

function NSAPI:GetNote()
    if not C_AddOns.IsAddOnLoaded("MRT") then
        error("Addon MRT is disabled, can't read the note")
        return ""
    end
    
    if not VMRT or not VMRT.Note or not VMRT.Note.Text1 then
        error("No MRT Note found")
        return ""
    end
    
    local note = VMRT.Note.Text1
    local now = GetTime()
    
    if ((not self.lastnote) or now >= self.lastnote + 1) or 
       ((not self.RawNote) or self.RawNote ~= note) then
        self.lastnote = now
        self.RawNote = note
        
        local newnote = ""
        local list = false
        local namelist = {}
        
        for line in note:gmatch('[^\r\n]+') do
            if string.match(line, "ns.*start") or line == "intstart" then
                list = true
            elseif string.match(line, "ns.*end") or line == "intend" then
                list = false
                newnote = newnote..line.."\n"
            end
            if list then
                newnote = newnote..line.."\n"
            end
        end
        
        note = newnote
        note = strtrim(note)
        note = note:gsub("||r", "")
        note = note:gsub("||c%x%x%x%x%x%x%x%x", "")
        
        for name in note:gmatch("%S+") do
            local charname = (UnitIsVisible(name) and name) or self:GetChar(name, true)
            if name ~= charname and not namelist[name] then
                namelist[name] = charname
            end
        end
        
        for nickname, charname in pairs(namelist) do
            note = note:gsub("(%f[%w])"..nickname.."(%f[%W])", "%1"..charname.."%2")
        end
        
        self.Note = note
    end
    
    self.Note = self.Note or ""
    return self.Note
end

function NSAPI:GetHash(text)
    local counter = 1
    local len = string.len(text)
    for i = 1, len, 3 do 
        counter = math.fmod(counter*8161, 4294967279) + 
        (string.byte(text,i)*16776193) +
        ((string.byte(text,i+1) or (len-i+256))*8372226) +
        ((string.byte(text,i+2) or (len-i+256))*3932164)
    end
    return math.fmod(counter, 4294967291) 
end

local function ReceiveComm(text, sender, whisper)
    local argTable = {strsplit(":", text)}
    if UnitExists(sender) and (UnitInRaid(sender) or UnitInParty(sender)) then
        local formattedArgTable = {}
        local event = argTable[1]
        table.remove(argTable, 1)
        
        if whisper then
            local target, argType = argTable[2]:match("(.*)%((%a+)%)") 
            if not (UnitIsUnit("player", target)) then
                return 
            end
            table.remove(argTable, 2)
        end
        
        for _, functionArg in ipairs(argTable) do
            local argValue, argType = functionArg:match("(.*)%((%a+)%)")
            if argType == "number" then
                argValue = tonumber(argValue)
            elseif argType == "boolean" then
                argValue = argValue == "true"
            elseif argType == "table" then
                argValue = LibDeflate:DecodeForWoWAddonChannel(argValue)  
                argValue = LibDeflate:DecompressDeflate(argValue)     
                local success, table = LibSerialize:Deserialize(argValue)
                if success then
                    argValue = table
                else
                    argValue = ""
                end
            end
            
            if argValue == "" then
                table.insert(formattedArgTable, false)
            else
                table.insert(formattedArgTable, argValue)
            end
        end
        
        WeakAuras.ScanEvents(event, unpack(formattedArgTable))
    end
end

AceComm:RegisterComm("NSWA_MSG", function(_, text, _, sender) ReceiveComm(text, sender, false) end)
AceComm:RegisterComm("NSWA_MSG2", function(_, text, _, sender) ReceiveComm(text, sender, true) end)

_G.NSAPI = NSAPI

return NSAPI