local AddonName = ...

local function GetNicknamesMap()
    if not VMRT or not VMRT.Nicknames then return {} end
    return VMRT.Nicknames
end

local function FindNicknameKey(nicknamesMap, nickname)
    nickname = nickname:lower()
    for key in pairs(nicknamesMap) do
        if key:lower() == nickname then
            return key
        end
    end
    return nil
end

-- Nickname API
local NicknameAPI = {
    GetNicknameByCharacter = function(_, characterName)
        if not characterName or type(characterName) ~= "string" then return nil end
        
        characterName = (characterName:match("^([^-]+)") or characterName):lower()
        
        local nicknamesMap = GetNicknamesMap()
        
        for nickname, data in pairs(nicknamesMap) do
            if data.characters then
                for _, charData in ipairs(data.characters) do
                    local storedChar = (charData.character:match("^([^-]+)") or charData.character):lower()
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
        
        characterName = (characterName:match("^([^-]+)") or characterName):lower()
        nickname = nickname:lower()
        
        local nicknamesMap = GetNicknamesMap()
        
        if nicknamesMap[nickname] and nicknamesMap[nickname].characters then
            for _, charData in ipairs(nicknamesMap[nickname].characters) do
                local storedChar = (charData.character:match("^([^-]+)") or charData.character):lower()
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

-- Something Ill get rid off eventually 
local function GetCachedNickname(unit)
    if not unit or not UnitExists(unit) then return nil end
    
    local name = UnitName(unit)
    if not name then return nil end
    
    return NicknameAPI:GetNicknameByCharacter(name)
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

-- ElvUI
local function IsElvUIReady()
    return ElvUF and ElvUF.Tags and ElvUF.Tags.Methods and ElvUF.Tags.Events
end

local function EnhancedUpdateElvUFTags()
    if not IsElvUIReady() then return end
    
    local function NicknameTag(unit)
        if not unit then return "" end
        return GetCachedNickname(unit) or ""
    end
    
    local function NicknameShortTag(unit)
        if not unit then return "" end
        local nick = GetCachedNickname(unit)
        return nick and nick:sub(1, 8) or ""
    end
    
    local function NicknameVeryShortTag(unit)
        if not unit then return "" end
        local nick = GetCachedNickname(unit)
        return nick and nick:sub(1, 5) or ""
    end
    
    local function NicknameMediumTag(unit)
        if not unit then return "" end
        local nick = GetCachedNickname(unit)
        return nick and nick:sub(1, 10) or ""
    end
    
    ElvUF.Tags.Methods['nickname'] = NicknameTag
    ElvUF.Tags.Events['nickname'] = 'UNIT_NAME_UPDATE'
    
    ElvUF.Tags.Methods['nickname:short'] = NicknameShortTag
    ElvUF.Tags.Events['nickname:short'] = 'UNIT_NAME_UPDATE'
    
    ElvUF.Tags.Methods['nickname:veryshort'] = NicknameVeryShortTag
    ElvUF.Tags.Events['nickname:veryshort'] = 'UNIT_NAME_UPDATE'
    
    ElvUF.Tags.Methods['nickname:medium'] = NicknameMediumTag
    ElvUF.Tags.Events['nickname:medium'] = 'UNIT_NAME_UPDATE'

    if ElvUI and ElvUI and ElvUI.UpdateAllFrames then
        ElvUI:UpdateAllFrames()
    end
end

-- Grid2
local function EnhancedGrid2NameStatus()
    if not Grid2 then return end
    
    local NicknameStatus = Grid2.statusPrototype:new("name")
    
    NicknameStatus.IsActive = Grid2.statusLibrary.IsActive
    
    function NicknameStatus:UNIT_NAME_UPDATE(_, unit)
        self:UpdateIndicators(unit)
    end
    
    function NicknameStatus:GROUP_ROSTER_UPDATE()
        self:UpdateAllUnits()
    end
    
    function NicknameStatus:OnEnable()
        self:RegisterEvent("UNIT_NAME_UPDATE")
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
    end
    
    function NicknameStatus:OnDisable()
        self:UnregisterEvent("UNIT_NAME_UPDATE")
        self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    end
    
    function NicknameStatus:GetText(unit)
        return GetCachedNickname(unit)
    end
    
    function NicknameStatus:GetTooltip(unit)
        local nickname = GetCachedNickname(unit)
        local name = UnitName(unit)
        if nickname and nickname ~= name then
            return string.format("%s (%s)", nickname, name)
        end
        return name
    end
    
    local function RegisterNicknameStatus(baseKey, dbx)
        Grid2:RegisterStatus(NicknameStatus, {"text", "tooltip"}, baseKey, dbx)
        return NicknameStatus
    end
    
    Grid2.setupFunc["name"] = RegisterNicknameStatus
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
        
        local nickname = GetCachedNickname(frame.unit)
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

local LiquidAPI = {
    GetName = function(_, characterName, formatting, atlasSize)
        if not characterName then 
            error("LiquidAPI:GetName(characterName[, formatting, atlasSize]), characterName is nil") 
            return 
        end
        
        local nickname
        if unitIDs[characterName:lower()] then
            local n = UnitNameUnmodified(characterName)
            if n then
                n = n:match("^([^-]+)")
                nickname = NicknameAPI:GetNicknameByCharacter(n)
            end
        else
            characterName = characterName:match("^([^-]+)")
            nickname = NicknameAPI:GetNicknameByCharacter(characterName)
        end

        if not formatting then 
            return nickname or characterName
        end

        local guid = UnitGUID(characterName)
        if not guid then
            return nickname or characterName, "%s", ""
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

        return nickname or characterName, colorFormat, roleIcon, 
               RAID_CLASS_COLORS[classFileName] or {}
    end,

    GetCharacterInGroup = function(_, nickname)
        local nicknameData = NicknameAPI:GetAllNicknames()
        
        if not nickname then return nil end
        
        for nickKey, data in pairs(nicknameData) do
            if nickKey:lower() == nickname:lower() and data.characters then
                for _, charData in ipairs(data.characters) do
                    if UnitExists(charData.character) then
                        local guid = UnitGUID(charData.character)
                        local classFileName = UnitClassBase(charData.character)
                        return charData.character, 
                               string.format("|c%s%%s|r", RAID_CLASS_COLORS[classFileName].colorStr), 
                               guid
                    end
                end
            end
        end
    end,

    GetCharacters = function(_, nickname)
        if not nickname then 
            error("LiquidAPI:GetCharacters(nickname), nickname is nil") 
            return 
        end
        
        local nicknamesMap = NicknameAPI:GetAllNicknames()
        
        nickname = nickname:gsub("^%l", string.upper)
        for nickKey, data in pairs(nicknamesMap) do
            if nickKey:lower() == nickname:lower() and data.characters then
                local chars = {}
                for _, charData in ipairs(data.characters) do
                    chars[charData.character] = true
                end
                return chars
            end
        end
        return nil
    end
}

-- Lisa can you teach me Japanese
_G.LiquidAPI = LiquidAPI
_G.NSAPI = LiquidAPI

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

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("ADDON_LOADED")

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        EnhancedUpdateCellNicknames()
        EnhancedUpdateElvUFTags()
        EnhancedGrid2NameStatus()
        UpdateDefaultFrames()
    elseif event == "ADDON_LOADED" then
        if arg1 == "Cell" or arg1 == "Grid2" or arg1 == "ElvUI" then
            C_Timer.After(0.5, function()
                EnhancedUpdateCellNicknames()
                EnhancedUpdateElvUFTags()
                EnhancedGrid2NameStatus()
                UpdateDefaultFrames()
            end)
        end
    end
end)